import Foundation
import LemmingsAppCore

@MainActor public final class GameLoadingIntroMusic {
    private static let maxModuleBytes = 128 * 1024
    private var player: ModuleMusicPlayer?

    public init() {}

    @discardableResult public func play(volume: Double) -> Bool {
        guard volume > 0, ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted" else {
            stop()
            return false
        }
        let gain = min(1, volume) * 0.55
        if let player, player.isRunning {
            player.setVolume(gain)
            return true
        }

        let modules = Self.modules(in: AppStorage.current())
        guard !modules.isEmpty else { return false }
        let next = ModuleMusicPlayer()
        next.setVolume(gain)
        for url in modules {
            guard next.play(url: url) != nil else { continue }
            do {
                try next.start()
                player = next
                return true
            } catch {
                next.stop()
                return false
            }
        }
        return false
    }

    private static func modules(in storage: AppStorage) -> [URL] {
        let properties: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        var seen = Set<URL>()
        return [storage.applicationSupport, storage.resources].flatMap { root in
            let folder = root.appendingPathComponent("LoadingIntros", isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: Array(properties), options: [.skipsHiddenFiles])) ?? []
            return files.compactMap { candidate -> URL? in
                guard candidate.pathExtension.lowercased() == "mod" else { return nil }
                let file = candidate.resolvingSymlinksInPath().standardizedFileURL
                guard let info = try? file.resourceValues(forKeys: properties),
                    info.isRegularFile == true, let size = info.fileSize,
                    (1...maxModuleBytes).contains(size), seen.insert(file).inserted else { return nil }
                return file
            }.shuffled()
        }
    }

    public func stop() {
        player?.setMuted(true)
        player?.stop()
        player = nil
    }
}
