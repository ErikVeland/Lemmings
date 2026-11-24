import Foundation
import NxlvKit

/// Downloads the game asset pack and passes its verified resource folder to the normal importer.
public actor GameAssetPack {
    public static let shared = GameAssetPack()
    private static let primary = URL(string: "https://archive.org/download/ultimate-lemmix-restoration-extra-soundtracks/Ultimate-Lemmix-Restoration-Game-Assets.zip")!
    private static let fallback = URL(string: "https://github.com/ErikVeland/Lemmings/releases/download/ultimate-lemmix-game-assets-1/Ultimate-Lemmix-Restoration-Game-Assets.zip")!
    static let bytes: Int64 = 252_732_885
    private static let digest = "142b37b8b7ff42e818b46d7f72f676706e4c86c90e379fc819e36f91c7a55ca1"
    private var busy = false

    public static var actionTitle: String { L10n.text("Download game assets") + " (253 MB)" }

    public enum Licence {
        public static var title: String { L10n.text("Confirm your game licence") }
        public static var detail: String {
            L10n.text("To download these assets, you must hold a valid licence for the original game “Lemmings” on at least one platform. By selecting “\(accept)”, you confirm that you hold that licence.")
        }
        public static var accept: String { L10n.text("Agree and download") }
    }

    public enum Progress: Sendable, Equatable {
        case connecting, stalledPrimary, alternateMirror
        case downloading(Int)
        case installing

        public var canCancel: Bool { self != .installing }

        static func transfer(_ received: Int64) -> Self {
            guard received > 0 else { return .connecting }
            return .downloading(max(1, min(99, Int(100 * min(received, GameAssetPack.bytes) / GameAssetPack.bytes))))
        }

        public var title: String {
            switch self {
            case .connecting: L10n.text("Waiting for download to start")
            case .stalledPrimary: L10n.text("Download hasn’t started")
            case .alternateMirror: L10n.text("Trying another download server")
            case .downloading(let percent): L10n.text("Downloading") + " \(percent)%"
            case .installing: L10n.text("Importing resources")
            }
        }
    }

    enum Failure: LocalizedError {
        case busy, unavailable, invalid, offline, interrupted, timedOut, storage, prohibited, resumeUnavailable, alternateRequested
        var errorDescription: String? {
            switch self {
            case .busy: L10n.text("Game assets are already downloading.")
            case .unavailable: L10n.text("Game assets are unavailable. Try again later.")
            case .offline: L10n.text("No internet connection. Reconnect and try again.")
            case .interrupted: L10n.text("The connection dropped. Try the download again.")
            case .alternateRequested: L10n.text("Trying another download server")
            case .resumeUnavailable: L10n.text("The background download stopped. Try the download again.")
            case .timedOut: L10n.text("The download timed out. Check your connection and try again.")
            case .storage: L10n.text("Not enough free storage for game assets. Free up space and try again.")
            case .prohibited: L10n.text("Mobile data is unavailable. Check cellular access for this app or try Wi-Fi.")
            case .invalid: L10n.text("Game assets failed verification. Download them again.")
            }
        }
    }

    static func configuration(backgroundIdentifier: String? = nil) -> URLSessionConfiguration {
        let configuration = backgroundIdentifier.map { URLSessionConfiguration.background(withIdentifier: $0) } ?? .ephemeral
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.isDiscretionary = false
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 30 * 60
        if backgroundIdentifier != nil { configuration.sessionSendsLaunchEvents = true }
        return configuration
    }

    static func validateResponse(_ response: URLResponse?) throws {
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200, response.url?.scheme == "https" else { throw Failure.unavailable }
        guard response.expectedContentLength <= bytes else { throw Failure.invalid }
    }

    static func explained(_ error: any Error) -> any Error {
        if error is CancellationError || error is Failure { return error }
        switch (error as NSError).domain {
        case NSURLErrorDomain:
            switch URLError.Code(rawValue: (error as NSError).code) {
            case .notConnectedToInternet: return Failure.offline
            case .networkConnectionLost: return Failure.interrupted
            case .timedOut: return Failure.timedOut
            case .dataNotAllowed, .internationalRoamingOff: return Failure.prohibited
            default: return Failure.unavailable
            }
        case NSCocoaErrorDomain where (error as NSError).code == CocoaError.fileWriteOutOfSpace.rawValue:
            return Failure.storage
        default: return error
        }
    }

    struct StallOffer {
        static let threshold: TimeInterval = 20
        private var started: TimeInterval?
        private var receivedData = false
        private var offered = false
        private(set) var alternateRequested = false

        mutating func observe(now: TimeInterval, online: Bool, foreground: Bool, bytes: Int64) -> Bool {
            receivedData = receivedData || bytes > 0
            guard foreground, online, !receivedData, !alternateRequested else {
                started = nil
                offered = false
                return false
            }
            if started == nil { started = now }
            offered = now - (started ?? now) >= Self.threshold
            return offered
        }

        mutating func requestSwitch(online: Bool, foreground: Bool, bytes: Int64) -> Bool {
            guard !alternateRequested, offered, !receivedData, online, foreground, bytes <= 0 else { return false }
            alternateRequested = true
            return true
        }

        func mayStartAlternate(primaryCompleted: Bool) -> Bool {
            alternateRequested && primaryCompleted
        }
    }

    #if os(iOS)
    @MainActor public static func handleBackgroundEvents(identifier: String, completion: @escaping @MainActor () -> Void) {
        guard identifier == GameAssetBackgroundTransfer.identifier else { completion(); return }
        GameAssetBackgroundTransfer.shared.restoreEvents(completion)
    }

    @MainActor public static func tryAlternateServer() {
        GameAssetBackgroundTransfer.shared.tryAlternateServer()
    }

    @MainActor public static var hasPendingDownload: Bool {
        GameAssetBackgroundTransfer.shared.pendingSource != nil
    }
    #endif

    public func downloadAndInstall<Result: Sendable>(
        isForeground: @escaping @MainActor @Sendable () -> Bool = { false },
        progress: @escaping @MainActor @Sendable (Progress) -> Void,
        install: @Sendable (URL) throws -> Result
    ) async throws -> Result {
        guard !busy else { throw Failure.busy }
        busy = true
        defer { busy = false }
        #if os(iOS)
        let recoveredSource = await GameAssetBackgroundTransfer.shared.pendingSource
        #else
        let session = URLSession(configuration: Self.configuration())
        defer { session.invalidateAndCancel() }
        let recoveredSource: URL? = nil
        #endif
        await progress(.connecting)
        let file: URL
        do {
            file = try await Self.withDownloadFallback(startingAt: recoveredSource, fallbackProgress: {
                await progress(.alternateMirror)
            }) { source in
                try Task.checkCancellation()
                #if os(iOS)
                let transfer = await GameAssetBackgroundTransfer.shared
                let file = try await transfer.transfer(from: source, offerAlternate: source == Self.primary, isForeground: isForeground) { phase in
                    progress(phase == .connecting && source == Self.fallback ? .alternateMirror : phase)
                }
                #else
                let monitor = TransferProgress(update: progress)
                let (file, response) = try await session.download(from: source, delegate: monitor)
                #endif
                do {
                    #if !os(iOS)
                    try Self.validateResponse(response)
                    #endif
                    try Task.checkCancellation()
                    try Self.verifyArchive(file)
                    return file
                } catch {
                    try? FileManager.default.removeItem(at: file)
                    throw error
                }
            }
        } catch {
            throw Self.explained(error)
        }
        defer { try? FileManager.default.removeItem(at: file) }
        try Task.checkCancellation()
        await progress(.installing)
        do { return try Self.installVerifiedArchive(file, install: install) }
        catch { throw Self.explained(error) }
    }

    static func withDownloadFallback(
        startingAt recoveredSource: URL? = nil,
        fallbackProgress: () async -> Void = {},
        _ download: (URL) async throws -> URL) async throws -> URL {
        do {
            return try await download(recoveredSource ?? primary)
        } catch {
            try Task.checkCancellation()
            let failure = explained(error) as? Failure
            if recoveredSource == fallback || failure == .storage || failure == .resumeUnavailable { throw error }
            await fallbackProgress()
            return try await download(fallback)
        }
    }

    static func verifyArchive(_ file: URL) throws {
        guard try file.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(bytes),
              try MusicLibraryStore.hash(file) == digest else { throw Failure.invalid }
    }

    private static func installVerifiedArchive<Result>(_ file: URL, install: (URL) throws -> Result) throws -> Result {
        let archive = try ZipArchive(contentsOf: file)
        let prefix = "Ultimate-Lemmix-Restoration-Game-Assets/Resources/"
        let manager = FileManager.default
        let staging = manager.temporaryDirectory.appendingPathComponent("GameAssets-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        var count = 0
        for member in archive.members where member.name.hasPrefix(prefix) {
            try Task.checkCancellation()
            let path = String(member.name.dropFirst(prefix.count))
            if path == ".owned-resource-export.json" { continue }
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !member.isSymbolicLink, !path.contains("\\"), !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
                throw Failure.invalid
            }
            let target = staging.appendingPathComponent(path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard manager.createFile(atPath: target.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let handle = try FileHandle(forWritingTo: target)
            defer { try? handle.close() }
            try archive.extract(member, to: handle)
            count += 1
        }
        guard count == 23_001 else { throw Failure.invalid }
        try Task.checkCancellation()
        return try install(staging)
    }
}

private final class TransferProgress: NSObject, URLSessionDownloadDelegate {
    let update: @MainActor @Sendable (GameAssetPack.Progress) -> Void
    init(update: @escaping @MainActor @Sendable (GameAssetPack.Progress) -> Void) { self.update = update }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesWritten <= GameAssetPack.bytes else { downloadTask.cancel(); return }
        let phase = GameAssetPack.Progress.transfer(totalBytesWritten)
        let previous = GameAssetPack.Progress.transfer(totalBytesWritten - bytesWritten)
        if phase != previous {
            Task { @MainActor in update(phase) }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
