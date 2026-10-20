#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MobileLibraryViewController {
    func shortGamesPage(subtitle: String) -> GameFrontEnd.Page {
        ShortGamesArt.page(classicAvailable: shortGamesEntries != nil, loading: shortGamesPreparing, subtitle: subtitle)
    }

    func openShortGames() {
        shortGamesEntries = nil; shortGamesSelection = "classic"
        guard let catalogue, let sequence = ShortPlayCatalogue.sequence(id: "classic") else { return }
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders, journey = bundledJourney
        let owner = profiles.activeID, scope = hotSeat?.scope
        shortGamesPreparing = true
        navigate(.shortGames)
        learningTask?.cancel()
        learningTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) {
                try MobileShortPlayCatalogue.entries(sequence: sequence, journey: journey,
                    catalogue: MobileCatalogue(portsRoot: ports, fanFolders: folders))
            }
            let result = await worker.result
            guard let self, !Task.isCancelled, profiles.activeID == owner, hotSeat?.scope == scope else { return }
            shortGamesPreparing = false
            switch result {
            case .success(let entries): shortGamesEntries = entries
            case .failure: notice = L10n.text("Matching Classic game data unavailable")
            }
            if route == .shortGames { rebuild() }
        }
    }

    func playShortGame() {
        guard shortGamesSelection == "classic", !shortGamesPreparing,
              let entries = shortGamesEntries,
              let sequence = ShortPlayCatalogue.sequence(id: shortGamesSelection),
              let id = playlists.create(name: sequence.title, entries: entries),
              let run = playlists.startRun(id, shuffle: false) else { return }
        savePlaylists()
        openList(run.entries, name: run.name, back: .shortGames, run: run)
    }
}
#endif
