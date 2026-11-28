#if os(iOS)
import Foundation
import Network

/// One licensed transfer per app. The system owns the socket; its temporary file
/// must be moved before returning from the download delegate, even on relaunch.
final class GameAssetBackgroundTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    @MainActor static let shared = GameAssetBackgroundTransfer()
    static let identifier = (Bundle.main.bundleIdentifier ?? "academy.glasscode.ultimatelemmix") + ".game-assets.v1"

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let key = "gameAssetBackgroundTransfer"
    private var outcome: (String, Result<URL, any Error>)?
    @MainActor private var switchPrimary: (() -> Void)?
    private var finishEvents: (@MainActor () -> Void)?

    @MainActor private lazy var session = URLSession(
        configuration: GameAssetPack.configuration(backgroundIdentifier: Self.identifier),
        delegate: self,
        delegateQueue: nil
    )

    @MainActor func restoreEvents(_ completion: @escaping @MainActor () -> Void) {
        lock.withLock { finishEvents = completion }
        _ = session
    }

    @MainActor var pendingSource: URL? {
        lock.withLock {
            guard let record = defaults.stringArray(forKey: key), record.count == 2 else { return nil }
            return URL(string: record[1])
        }
    }

    private static func archive(_ token: String) throws -> URL {
        let manager = FileManager.default
        let root = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var folder = root.appendingPathComponent("PendingGameAssetTransfer", isDirectory: true)
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return folder.appendingPathComponent(token + ".zip")
    }

    @MainActor func tryAlternateServer() { switchPrimary?() }

    @MainActor func cancelPendingDownload() {
        let token: String? = lock.withLock {
            guard let record = defaults.stringArray(forKey: key), record.count == 2 else { return nil }
            defaults.removeObject(forKey: key)
            outcome = nil
            if let file = try? Self.archive(record[0]) {
                try? FileManager.default.removeItem(at: file)
            }
            return record[0]
        }
        guard let token else { return }
        let session = self.session
        Task {
            let tasks = await session.allTasks
            for task in tasks where task.taskDescription == token { task.cancel() }
        }
    }

    @MainActor func transfer(
        from source: URL,
        offerAlternate: Bool,
        isForeground: @escaping @MainActor @Sendable () -> Bool,
        progress: @escaping @MainActor @Sendable (GameAssetPack.Progress) -> Void
    ) async throws -> URL {
        let tasks = await session.allTasks
        let (token, reattaching): (String, Bool) = lock.withLock {
            if let previous = defaults.stringArray(forKey: key), previous.count == 2,
               previous[1] == source.absoluteString { return (previous[0], true) }
            let token = UUID().uuidString
            defaults.set([token, source.absoluteString], forKey: key)
            outcome = nil
            return (token, false)
        }
        defer {
            lock.withLock {
                if defaults.stringArray(forKey: key)?.first == token {
                    defaults.removeObject(forKey: key)
                    outcome = nil
                }
            }
        }
        let file: URL
        do { file = try Self.archive(token) }
        catch {
            tasks.first(where: { $0.taskDescription == token })?.cancel()
            throw error
        }
        // Reattach by the persisted token, not merely by URL or session task count.
        if FileManager.default.fileExists(atPath: file.path) { return file }
        if let finished = result(token) { return try finished.get() }
        let task: URLSessionDownloadTask
        if let existing = tasks.compactMap({ $0 as? URLSessionDownloadTask }).first(where: { $0.taskDescription == token }) {
            task = existing
        } else if reattaching {
            // A daemon finishing just as the player returns may have queued its
            // delegate callback even though it no longer enumerates the task.
            for _ in 0..<8 {
                try await Task.sleep(for: .milliseconds(250))
                if let finished = result(token) { return try finished.get() }
                if FileManager.default.fileExists(atPath: file.path) { return file }
            }
            // Force-quit or an expired OS task must not start another 253 MB
            // transfer merely because the player opened Game Data.
            throw GameAssetPack.Failure.resumeUnavailable
        } else {
            try Task.checkCancellation()
            task = session.downloadTask(with: source)
            task.taskDescription = token
            task.resume()
        }
        let path = offerAlternate ? NWPathMonitor() : nil
        path?.start(queue: DispatchQueue(label: "GameAssetDownloadPath"))
        var stall = GameAssetPack.StallOffer()
        var lastSample: TimeInterval?
        let uptime = { ProcessInfo.processInfo.systemUptime }
        if offerAlternate {
            switchPrimary = {
                guard self.result(token) == nil, task.state == .running,
                      let lastSample, uptime() - lastSample <= 1.5,
                      stall.requestSwitch(online: path?.currentPath.status == .satisfied,
                                      foreground: isForeground(), bytes: task.countOfBytesReceived) else { return }
                task.cancel()
            }
        }
        defer {
            switchPrimary = nil
            path?.cancel()
        }
        var last: GameAssetPack.Progress?
        defer {
            if Task.isCancelled {
                task.cancel()
                lock.withLock {
                    if defaults.stringArray(forKey: key)?.first == token {
                        defaults.removeObject(forKey: key)
                    }
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
        while true {
            try Task.checkCancellation()
            if let finished = result(token) {
                if !stall.alternateRequested { return try finished.get() }
                // A task that completed at the same time as the tap wins;
                // keep its archive and let the normal verifier check it.
                if case let .success(file) = finished { return file }
                // Do not launch a replacement until the primary is terminal.
                if stall.mayStartAlternate(primaryCompleted: task.state == .completed) {
                    throw GameAssetPack.Failure.alternateRequested
                }
            }
            let bytes = task.countOfBytesReceived
            let now = uptime()
            if let lastSample, now - lastSample > 1.5 {
                _ = stall.observe(now: now, online: false, foreground: false, bytes: bytes)
            }
            lastSample = now
            let stalled = offerAlternate && stall.observe(now: now, online: path?.currentPath.status == .satisfied,
                                                           foreground: isForeground(), bytes: bytes)
            let phase: GameAssetPack.Progress = stall.alternateRequested ? .alternateMirror
                : (stalled ? .stalledPrimary : .transfer(bytes))
            if phase != last { progress(phase); last = phase }
            try await Task.sleep(for: .milliseconds(350))
        }
    }

    private func result(_ token: String) -> Result<URL, any Error>? {
        lock.withLock { outcome?.0 == token ? outcome?.1 : nil }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > GameAssetPack.bytes || totalBytesExpectedToWrite > GameAssetPack.bytes {
            complete(downloadTask, .failure(GameAssetPack.Failure.invalid))
            downloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let token = downloadTask.taskDescription else { return }
        lock.withLock {
            guard defaults.stringArray(forKey: key)?.first == token, outcome?.0 != token else { return }
            outcome = (token, Result {
                try GameAssetPack.validateResponse(downloadTask.response)
                let file = try Self.archive(token)
                try FileManager.default.moveItem(at: location, to: file)
                return file
            })
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        complete(task, .failure(error ?? GameAssetPack.Failure.unavailable))
    }

    private func complete(_ task: URLSessionTask, _ result: Result<URL, any Error>) {
        guard let token = task.taskDescription else { return }
        lock.withLock {
            guard defaults.stringArray(forKey: key)?.first == token, outcome?.0 != token else { return }
            outcome = (token, result)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = lock.withLock {
            let handler = finishEvents
            finishEvents = nil
            return handler
        }
        if let completion { Task { @MainActor in completion() } }
    }
}
#endif
