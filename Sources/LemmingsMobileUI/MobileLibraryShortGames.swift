#if os(iOS) || os(tvOS)
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MobileLibraryViewController {
    func openTribesShortRun(_ run: MobilePlaylistRun, back: Route, position: Int,
                           checkpoint: MobileCheckpointEnvelope?, startImmediately: Bool) {
        guard let directory = store?.resolvedDataDirectory(for: .lemmings2) else { return }
        let progress = MobileStorage(directory: learningStorage.directory
            .appendingPathComponent("short-runs/" + run.id.uuidString))
        do {
            if let data = collectionsBridge?.store.resumableRun(id: run.id)?.l2Progress?[Lemmings2ShortPlayMobileLibrary.progressKey] {
                try progress.save(JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: data), name: "lemmings2-campaign")
            }
        } catch { notice = error.localizedDescription; rebuild(); return }
        let make: @Sendable () throws -> any MobileGameLibrary = {
            try Lemmings2ShortPlayMobileLibrary(directory: directory, storage: progress, entries: run.entries, name: run.name)
        }
        openLibrary({ try make() }) { [self] opened in
            guard let opened else { return }
            library = opened; activeRun = run; currentPack = nil
            previewLoader = MobileMenuPreviewLoader { try make() }
            selectedIndex = min(max(0, position), opened.levels.count - 1)
            selectedPreview = nil; browserShown = false; levelsBackRoute = back
            navigate(.levels)
            if startImmediately {
                let matching = checkpoint.flatMap { saved in
                    checkpointMatchesSession(saved) && saved.matchesJourney(runID: run.id, position: position,
                        levelIdentifier: try? opened.checkpointLevelIdentifier(at: position)) ? saved : nil
                }
                startLevel(selectedIndex, checkpoint: matching)
            } else { selectLevel(selectedIndex) }
        }
    }
    func shortGamesPage(subtitle: String) -> GameFrontEnd.Page {
        ShortGamesArt.page(available: Set(shortGamesEntries.keys).union(EasyPuzzleCatalogue.puzzles.isEmpty ? [] : ["easy-puzzles"]), selected: shortGamesSelection,
                           loading: shortGamesPreparing, subtitle: subtitle)
    }

    func openShortGames() {
        guard let catalogue else { return }
        shortGamesEntries = [:]; shortGamesSelection = EasyPuzzleCatalogue.puzzles.isEmpty ? "classic" : "easy-puzzles"
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders, journey = bundledJourney
        let tribesRoot = store?.resolvedDataDirectory(for: .lemmings2)
        let owner = profiles.activeID, scope = hotSeat?.scope
        shortGamesPreparing = true
        navigate(.shortGames)
        learningTask?.cancel()
        learningTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) {
                let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: folders)
                var entries: [String: [MobileFavourites.Entry]] = [:]
                for sequence in ShortPlayCatalogue.sequences where sequence.engine == .classic {
                    entries[sequence.id] = try? MobileShortPlayCatalogue.entries(sequence: sequence,
                        journey: journey, catalogue: catalogue)
                }
                entries["lemmings2"] = tribesRoot.flatMap { try? Lemmings2ShortPlayMobileLibrary.entries(directory: $0) }
                return entries
            }
            let entries = await worker.value
            guard let self, !Task.isCancelled, profiles.activeID == owner, hotSeat?.scope == scope else { return }
            shortGamesPreparing = false
            shortGamesEntries = entries
            if route == .shortGames { rebuild() }
        }
    }

    func playShortGame() {
        guard !shortGamesPreparing else { return }
        if shortGamesSelection == "easy-puzzles" { startEasyPuzzles(); return }
        guard let entries = shortGamesEntries[shortGamesSelection],
              let sequence = ShortPlayCatalogue.sequence(id: shortGamesSelection),
              let id = playlists.create(name: sequence.title, entries: entries),
              let run = playlists.startRun(id, shuffle: false) else { return }
        savePlaylists()
        guard playlists.run?.id == run.id else { rebuild(); return }
        openList(run.entries, name: run.name, back: .shortGames, run: run)
    }
}
#endif
