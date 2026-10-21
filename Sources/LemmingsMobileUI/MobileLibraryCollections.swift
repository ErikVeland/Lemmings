#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Collections, playlists and playlist runs, as the Mac library offers them.
extension MobileLibraryViewController {
    // MARK: - Pages

    func collectionsPage(subtitle: String) -> GameFrontEnd.Page {
        let rows: [GameFrontEnd.Action] = [
            .init("favourites", L10n.text("Favourites  \(favourites.entries.count)"), enabled: !favourites.entries.isEmpty),
            .init("recents", L10n.text("Recently played  \(recents.entries.count)"), enabled: !recents.entries.isEmpty),
            .init("playlists", L10n.text("Playlists  \(playlists.playlists.count)")),
            .init("shortGames", L10n.text("Short games")),
            .init("progression", L10n.text("Progression playlists")),
            .init("shuffleAll", L10n.text("Shuffle all"), enabled: catalogue?.packs(in: .fan).isEmpty == false),
        ]
        var footer = [GameFrontEnd.Action("home", L10n.text("Back"))]
        if let run = playlists.run {
            footer.append(.init("runResume", L10n.text("Resume \(run.name)  \(run.position + 1)/\(run.entries.count)"), primary: true))
        }
        return .init(title: L10n.text("Collections"), subtitle: subtitle, rows: rows, footer: footer)
    }

    func playlistsPage(subtitle: String) -> GameFrontEnd.Page {
        var rows = playlists.playlists.map { list in
            GameFrontEnd.Action("list." + list.id.uuidString, list.name + "  \(list.entries.count)")
        }
        rows.append(.init("listNew", L10n.text("New playlist")))
        return .init(title: L10n.text("Playlists"), subtitle: subtitle, rows: rows, footer: [.init("collections", L10n.text("Back"))])
    }

    func playlistPage(_ id: UUID, subtitle: String) -> GameFrontEnd.Page {
        guard let list = playlists.playlist(id) else { return playlistsPage(subtitle: subtitle) }
        if let draft = nameDraft {
            return .init(title: L10n.text("Rename"), subtitle: subtitle,
                         rows: [.init("nameField", L10n.text("Name: \(draft.uppercased())_"), selected: true)],
                         footer: [.init("nameCancel", L10n.text("Cancel")), .init("nameDone", L10n.text("Done"), primary: true)])
        }
        let shown = MobileListLibrary(entries: list.entries, name: list.name, catalogue: catalogue!)
        // Entries whose pack or level is gone stay listed, so the player can remove them.
        var titles = [Int: String]()
        for (offset, entryIndex) in shown.entryIndices.enumerated() { titles[entryIndex] = shown.levels[offset].title }
        let rows = list.entries.enumerated().map { index, entry -> GameFrontEnd.Action in
            let title = titles[index].map { "\(index + 1)  " + $0 } ?? L10n.text("\(index + 1)  Unavailable")
            return .init("entry.\(index)", title, enabled: true, selected: playlistSelection == index)
        }
        let selected = playlistSelection
        let hasSelection = selected.map { list.entries.indices.contains($0) } ?? false
        let playable = !shown.levels.isEmpty && shown.levels.count == list.entries.count
        return .init(
            title: list.name, subtitle: subtitle.isEmpty ? L10n.plural("count.levels", count: list.entries.count, one: "%ld level", other: "%ld levels") : subtitle, rows: rows,
            footer: [
                .init("listPlay", L10n.text("Play"), enabled: playable, primary: true),
                .init("listShuffle", L10n.text("Shuffle"), enabled: playable && list.entries.count > 1),
                .init("entryUp", "Up", enabled: hasSelection && (selected ?? 0) > 0),
                .init("entryDown", L10n.text("Down"), enabled: hasSelection && (selected ?? 0) + 1 < list.entries.count),
                .init("entryRemove", L10n.text("Remove"), enabled: hasSelection),
                .init("listRename", L10n.text("Rename")),
                .init("listDelete", confirmingDelete ? L10n.text("Confirm delete") : L10n.text("Delete"), selected: confirmingDelete),
                .init("playlists", L10n.text("Back")),
            ])
    }

    func addToPlaylistPage(subtitle: String) -> GameFrontEnd.Page {
        var rows = playlists.playlists.map { GameFrontEnd.Action("add." + $0.id.uuidString, $0.name + "  \($0.entries.count)") }
        rows.append(.init("addNew", L10n.text("New playlist")))
        return .init(title: L10n.text("Add to playlist"), subtitle: subtitle, rows: rows, footer: [.init("back", L10n.text("Back"))])
    }

    // MARK: - Actions

    /// Handles the collection and playlist actions. Returns false for any other action.
    func handleCollections(_ id: String) -> Bool {
        switch id {
        case "collections": navigate(.collections)
        case "shortGames": openShortGames()
        case "shortPlay": playShortGame()
        case "players": navigate(.players)
        case "fanBack": navigate(.family(.fan))
        case "shuffleAll": shuffleBackID = route == .collections ? "collections" : "fanBack"; beginShuffleAll()
        case "shuffleStart": startShuffleAll()
        case "playerNew": newPlayer()
        case "playerRename": beginRenamingPlayer()
        case "playerDelete": deleteActivePlayer()
        case "playerDeleteCancel": confirmingDelete = false; rebuild()
        case "playerPortrait": cyclePlayerPortrait()
        case "favourites": openList(favourites.entries, name: "Favourites", back: .collections)
        case "recents": openList(recents.entries, name: "Recently played", back: .collections)
        case "playlists": navigate(.playlists)
        case "listNew": if let created = playlists.create(name: L10n.text("Playlist \(playlists.playlists.count + 1)")) { savePlaylists(); openPlaylist(created) }
        case "addPlaylist": navigate(.addToPlaylist)
        case "addNew": addCurrentLevel(to: playlists.create(name: L10n.text("Playlist \(playlists.playlists.count + 1)")))
        case "random": makeRandomPlaylist()
        case "runResume": resumeRun()
        case "listPlay": playPlaylist(shuffle: false)
        case "listShuffle": playPlaylist(shuffle: true)
        case "entryUp", "entryDown": moveSelectedEntry(id == "entryUp" ? -1 : 1)
        case "entryRemove": removeSelectedEntry()
        case "listRename": beginNaming()
        case "nameField": if nameDraft != nil { searchField.becomeFirstResponder() }
        case "nameCancel": endNaming(commit: false)
        case "nameDone": endNaming(commit: true)
        case "listDelete": deleteSelectedPlaylist()
        default:
            if id == "shortSelect.classic" { shortGamesSelection = "classic"; rebuild() }
            else if id.hasPrefix("player."), case let key = String(id.dropFirst(7)), profiles.players.contains(where: { $0.id == key }) { switchPlayer(key) }
            else if id.hasPrefix("list."), let uuid = UUID(uuidString: String(id.dropFirst(5))) { openPlaylist(uuid) }
            else if id.hasPrefix("add."), let uuid = UUID(uuidString: String(id.dropFirst(4))) { addCurrentLevel(to: uuid) }
            else if id.hasPrefix("entry."), let index = Int(id.dropFirst(6)) {
                playlistSelection = playlistSelection == index ? nil : index
                rebuild()
            } else { return false }
        }
        return true
    }

    func savePlaylists() { saveSharedCollections() }

    private func openPlaylist(_ id: UUID) {
        playlistSelection = nil
        confirmingDelete = false
        navigate(.playlist(id))
    }

    private var openPlaylistID: UUID? {
        if case let .playlist(id) = route { return id }
        return nil
    }

    private func moveSelectedEntry(_ offset: Int) {
        guard let id = openPlaylistID, let selected = playlistSelection else { return }
        playlists.move(at: selected, by: offset, in: id)
        playlistSelection = selected + offset
        savePlaylists()
        rebuild()
    }

    private func removeSelectedEntry() {
        guard let id = openPlaylistID, let selected = playlistSelection else { return }
        playlists.remove(at: selected, from: id)
        playlistSelection = nil
        savePlaylists()
        rebuild()
    }

    /// The first tap asks for confirmation. A second tap deletes the playlist and its saved run.
    private func deleteSelectedPlaylist() {
        guard let id = openPlaylistID else { return }
        if !confirmingDelete { confirmingDelete = true; rebuild(); return }
        playlists.delete(id)
        savePlaylists()
        confirmingDelete = false
        navigate(.playlists)
    }

    private func beginNaming() {
        guard let id = openPlaylistID, let list = playlists.playlist(id) else { return }
        nameDraft = list.name
        searchField.text = list.name
        searchField.becomeFirstResponder()
        rebuild()
    }

    private func endNaming(commit: Bool) {
        searchField.resignFirstResponder()
        if renamingPlayer {
            finishProfileNaming(commit: commit)
            return
        }
        if commit, let id = openPlaylistID, let draft = nameDraft { playlists.rename(id, to: draft); savePlaylists() }
        nameDraft = nil
        searchField.text = searchQuery
        rebuild()
    }

    // MARK: - Adding levels

    private func addCurrentLevel(to id: UUID?) {
        guard let id, let identity = favouriteIdentity(selectedIndex) else { return }
        let entry = MobileFavourites.Entry(pack: identity.pack, level: identity.level, title: library?.levels[selectedIndex].title)
        let added = playlists.add(entry, to: id)
        savePlaylists()
        notice = added ? L10n.text("ADDED") : L10n.text("ALREADY IN PLAYLIST")
        navigate(.levels)
        notice = ""
        rebuild()
    }

    /// Ten distinct levels from the open pack, in a random order.
    private func makeRandomPlaylist() {
        guard let library, currentPack != nil, library.levels.count > 1 else { return }
        let pool = library.levels.indices.compactMap { index in
            favouriteIdentity(index).map { MobileFavourites.Entry(pack: $0.pack, level: $0.level, title: library.levels[index].title) }
        }
        let picks = MobilePlaylistStore.random(10, from: pool, seed: UInt64.random(in: 0...UInt64.max))
        let name = L10n.text("Random 10 \((currentPack?.title ?? ""))")
        guard let created = playlists.create(name: name, entries: picks) else { return }
        savePlaylists()
        openPlaylist(created)
    }

    // MARK: - Lists and runs

    /// Opens a list of levels from any packs as the current library.
    func openList(_ entries: [MobileFavourites.Entry], name: String, back: Route, run: MobilePlaylistRun? = nil, position: Int = 0,
                  checkpoint: MobileCheckpointEnvelope? = nil, startImmediately: Bool = false,
                  restoringMatchingCheckpoint: Bool = false) {
        guard let catalogue else { return }
        // A long list shows its titles without opening every pack.
        let lazy = run != nil || (entries.count > 100 && entries.allSatisfy { $0.title != nil })
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders
        openLibrary({
            MobileListLibrary(entries: entries, name: name, catalogue: MobileCatalogue(portsRoot: ports, fanFolders: fan), lazy: lazy)
        }) { [self] opened in
            guard let list = opened as? MobileListLibrary, !list.levels.isEmpty else { rebuild(); return }
            library = list
            currentPack = nil
            activeRun = run
            previewLoader = MobileMenuPreviewLoader {
                MobileListLibrary(entries: entries, name: name, catalogue: MobileCatalogue(portsRoot: ports, fanFolders: fan), lazy: lazy)
            }
            selectedIndex = min(position, list.levels.count - 1)
            selectedPreview = nil
            browserShown = false
            levelsBackRoute = back
            navigate(.levels)
            if startImmediately {
                startLevel(selectedIndex, checkpoint: checkpoint, restoringMatchingCheckpoint: restoringMatchingCheckpoint)
            } else { selectLevel(selectedIndex) }
        }
    }

    private func playPlaylist(shuffle: Bool) {
        guard let id = openPlaylistID, let run = playlists.startRun(id, shuffle: shuffle) else { return }
        savePlaylists()
        openList(run.entries, name: run.name, back: .playlist(id), run: run)
    }

    func resumeRun() {
        guard let run = playlists.run, let catalogue else { return }
        let owner = profiles.activeID, scope = hotSeat?.scope
        learningTask?.cancel()
        learningTask = Task { [weak self] in
            guard let self, let checkpointStore else { return }
            do {
                let checkpoint = try await checkpointStore.load(owner: owner, scope: scope)
                guard !Task.isCancelled, profiles.activeID == owner, hotSeat?.scope == scope else { return }
                let queue = MobileListLibrary(entries: run.entries, name: run.name, catalogue: catalogue, lazy: true)
                let identifier = try queue.checkpointLevelIdentifier(at: run.position)
                let matching = checkpoint.flatMap {
                    checkpointMatchesSession($0) && $0.matchesJourney(runID: run.id, position: run.position,
                        levelIdentifier: identifier) ? $0 : nil
                }
                openList(run.entries, name: run.name, back: .collections, run: run, position: run.position,
                         checkpoint: matching, startImmediately: true, restoringMatchingCheckpoint: true)
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }

    /// Records a level start in Recently played and moves a running playlist forward.
    func levelStarted(_ index: Int) {
        if let identity = favouriteIdentity(index) {
            recents.record(.init(pack: identity.pack, level: identity.level))
            saveSharedCollections()
        }
        if activeRun != nil {
            playlists.advance(to: index)
            savePlaylists()
            activeRun = playlists.run
        }
    }

    /// The run finished or the player left it. Nothing remains to resume.
    func finishRunIfNeeded(afterLast index: Int) {
        guard activeRun != nil, let count = library?.levels.count, index + 1 >= count else { return }
        playlists.endRun()
        savePlaylists()
        activeRun = nil
    }

    // MARK: - Shuffle all

    func shuffleAllPage(subtitle: String) -> GameFrontEnd.Page {
        var details: [String] = []
        if shuffleScanning { details = [L10n.text("Counting levels...")] }
        else if let pool = shufflePool { details = [L10n.plural("count.levels", count: pool.entries.count, one: "%ld level", other: "%ld levels"), L10n.plural("count.packs", count: pool.packs, one: "%ld pack", other: "%ld packs")] }
        else { details = [L10n.text("Fan levels are not available.")] }
        return .init(title: L10n.text("Shuffle all"), subtitle: subtitle, details: details,
                     footer: [.init(shuffleBackID, L10n.text("Back")),
                              .init("shuffleStart", L10n.text("Start"), enabled: !shuffleScanning && (shufflePool?.entries.isEmpty == false),
                                    primary: true)])
    }

    /// Counts the installed fan levels away from the main thread, then offers to start.
    func beginShuffleAll() {
        guard let catalogue, !shuffleScanning else { return }
        shuffleScanning = true
        shufflePool = nil
        navigate(.shuffleAll)
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders
        shuffleTask = Task {
            let worker = Task.detached(priority: .utility) {
                MobileCatalogue(portsRoot: ports, fanFolders: folders).fanPool()
            }
            let pool = await withTaskCancellationHandler {
                await worker.value
            } onCancel: { worker.cancel() }
            guard !Task.isCancelled, game == nil else { return }
            shuffleTask = nil
            shufflePool = pool
            shuffleScanning = false
            if route == .shuffleAll { rebuild() }
        }
    }

    private func startShuffleAll() {
        guard let pool = shufflePool, let run = playlists.startShuffleAll(pool.entries) else { return }
        savePlaylists()
        openList(run.entries, name: run.name, back: .family(.fan), run: run)
    }
}
#endif
