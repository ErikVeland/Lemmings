#if os(iOS)
import Foundation
import LemmingsAppCore
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
    private var allRequestedPacks: Set<String>?

    var catalogue: MusicLibraryCatalogue? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Music/libraries.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? MusicLibraryCatalogue(data: data)
    }

    var isDownloading: Bool { !tasks.isEmpty }

    func isInstalled(_ pack: MusicLibraryCatalogue.Pack) -> Bool {
        MusicLibraryStore.isInstalled(pack, in: Self.directory)
    }

    func isBundled(_ pack: MusicLibraryCatalogue.Pack) -> Bool {
        guard let root = Bundle.main.resourceURL else { return false }
        return pack.files.filter { !$0.path.hasSuffix(".json") }.allSatisfy {
            FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0.path).path)
        }
    }

    private var downloadable: [MusicLibraryCatalogue.Pack] {
        (catalogue?.packs ?? []).filter { !isBundled($0) && !isInstalled($0) }
    }

    func download(_ pack: MusicLibraryCatalogue.Pack) {
        guard tasks[pack.id] == nil, !isBundled(pack), !isInstalled(pack) else { return }
        let missing = Set(downloadable.map(\.id))
        let queued = Set(tasks.filter { !$0.value.isCancelled }.map(\.key)).union([pack.id])
        if !missing.isEmpty && missing.isSubset(of: queued) {
            allRequestedPacks = missing
            AnonymousTelemetry.shared.soundtrackAllSelected()
        }
        failure = nil
        progress[pack.id] = 0
        tasks[pack.id] = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.installer.download(pack, to: Self.directory) { [weak self] value in
                    Task { @MainActor in self?.progress[pack.id] = value; self?.onChange?() }
                }
                try Task.checkCancellation()
                if self.allRequestedPacks?.remove(pack.id) != nil,
                   self.allRequestedPacks?.isEmpty == true {
                    if self.downloadable.isEmpty {
                        AnonymousTelemetry.shared.soundtrackAllDownloaded()
                    }
                    self.allRequestedPacks = nil
                }
            } catch is CancellationError {
                self.allRequestedPacks = nil
            } catch {
                self.allRequestedPacks = nil
                self.failure = (error as? LocalizedError)?.errorDescription ?? "The download did not finish."
            }
            self.progress[pack.id] = nil
            self.tasks[pack.id] = nil
            self.onChange?()
        }
        onChange?()
    }

    func cancel(_ pack: MusicLibraryCatalogue.Pack) {
        if allRequestedPacks?.contains(pack.id) == true { allRequestedPacks = nil }
        tasks[pack.id]?.cancel()
    }

    func remove(_ pack: MusicLibraryCatalogue.Pack) {
        allRequestedPacks = nil
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
