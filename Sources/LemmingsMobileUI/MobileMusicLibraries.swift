#if os(iOS)
import Foundation
import NxlvKit

/// The optional soundtrack libraries: what exists, what is installed, and what is downloading.
@MainActor final class MobileMusicLibraries {
    static let shared = MobileMusicLibraries()

    /// Same place the Mac keeps them, so one set of paths describes both apps.
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/MusicLibraries", isDirectory: true)
    }

    private(set) var progress: [String: Double] = [:]
    private(set) var failure: String?
    var onChange: (() -> Void)?
    private let installer = MusicLibraryInstaller()
    private var tasks: [String: Task<Void, Never>] = [:]

    var catalogue: MusicLibraryCatalogue? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Music/libraries.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? MusicLibraryCatalogue(data: data)
    }

    var isDownloading: Bool { !tasks.isEmpty }

    func isInstalled(_ pack: MusicLibraryCatalogue.Pack) -> Bool {
        MusicLibraryStore.isInstalled(pack, in: Self.directory)
    }

    func download(_ pack: MusicLibraryCatalogue.Pack) {
        guard tasks[pack.id] == nil, !isInstalled(pack) else { return }
        failure = nil
        progress[pack.id] = 0
        tasks[pack.id] = Task { [weak self] in
            do {
                try await self?.installer.download(pack, to: Self.directory) { value in
                    Task { @MainActor in self?.progress[pack.id] = value; self?.onChange?() }
                }
            } catch is CancellationError {
            } catch {
                self?.failure = (error as? LocalizedError)?.errorDescription ?? "The download did not finish."
            }
            self?.progress[pack.id] = nil
            self?.tasks[pack.id] = nil
            self?.onChange?()
        }
        onChange?()
    }

    func cancel(_ pack: MusicLibraryCatalogue.Pack) {
        tasks[pack.id]?.cancel()
    }

    func remove(_ pack: MusicLibraryCatalogue.Pack) {
        try? MusicLibraryStore.remove(pack, in: Self.directory)
        onChange?()
    }

    /// "73 MB" or "1.2 GB", the way the download is described to a player.
    static func size(_ bytes: Int64) -> String {
        bytes >= 1_000_000_000 ? String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
                               : "\(max(1, Int((Double(bytes) / 1_000_000).rounded()))) MB"
    }
}
#endif
