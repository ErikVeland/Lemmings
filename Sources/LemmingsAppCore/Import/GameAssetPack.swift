import Foundation
import NxlvKit

/// Downloads the fixed GitHub release and passes its verified resource folder to the normal importer.
public actor GameAssetPack {
    public static let shared = GameAssetPack()
    private static let source = URL(string: "https://github.com/ErikVeland/Lemmings/releases/download/ultimate-lemmix-game-assets-1/Ultimate-Lemmix-Restoration-Game-Assets.zip")!
    fileprivate static let bytes: Int64 = 252_732_885
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

    public enum Progress: Sendable {
        case downloading(Int)
        case installing

        public var title: String {
            switch self {
            case .downloading(let percent): L10n.text("Downloading") + " \(percent)%"
            case .installing: L10n.text("Importing resources")
            }
        }
    }

    enum Failure: LocalizedError {
        case busy, unavailable, invalid
        var errorDescription: String? {
            switch self {
            case .busy: L10n.text("Game assets are already downloading.")
            case .unavailable: L10n.text("Game assets are unavailable. Try again later.")
            case .invalid: L10n.text("Game assets failed verification. Download them again.")
            }
        }
    }

    public func downloadAndInstall<Result: Sendable>(
        progress: @escaping @MainActor @Sendable (Progress) -> Void,
        install: @Sendable (URL) throws -> Result
    ) async throws -> Result {
        guard !busy else { throw Failure.busy }
        busy = true
        defer { busy = false }
        await progress(.downloading(0))
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let monitor = TransferProgress(update: progress)
        let (file, response) = try await session.download(from: Self.source, delegate: monitor)
        defer { try? FileManager.default.removeItem(at: file) }
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https" else {
            throw Failure.unavailable
        }
        try Task.checkCancellation()
        await progress(.installing)
        return try Self.installArchive(file, install: install)
    }

    static func installArchive<Result>(_ file: URL, install: (URL) throws -> Result) throws -> Result {
        guard try file.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(bytes),
              try MusicLibraryStore.hash(file) == digest else { throw Failure.invalid }
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
        let percent = Int(100 * totalBytesWritten / GameAssetPack.bytes)
        let previous = Int(100 * (totalBytesWritten - bytesWritten) / GameAssetPack.bytes)
        if percent != previous {
            Task { @MainActor in update(.downloading(percent)) }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
