#if os(iOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

/// Collections, playlists and playlist runs, as the Mac library offers them.
extension MobileLibraryViewController {
    // MARK: - Pages

    func collectionsPage(subtitle: String) -> GameFrontEnd.Page {
        var rows: [GameFrontEnd.Action] = [
            .init("favourites", "Favourites  \(favourites.entries.count)", enabled: !favourites.entries.isEmpty),
            .init("recents", "Recently played  \(recents.entries.count)", enabled: !recents.entries.isEmpty),
            .init("playlists", "Playlists  \(playlists.playlists.count)"),
        ]
        if let run = playlists.run {
            rows.insert(.init("runResume", "Resume \(run.name)  \(run.position + 1)/\(run.entries.count)", primary: true), at: 0)
        }
        return .init(title: "Collections", subtitle: subtitle, rows: rows, footer: [.init("home", "Back")])
    }

    func playlistsPage(subtitle: String) -> GameFrontEnd.Page {
        var rows = playlists.playlists.map { list in
            GameFrontEnd.Action("list." + list.id.uuidString, list.name + "  \(list.entries.count)")
        }
        rows.append(.init("listNew", "New playlist"))
        return .init(title: "Playlists", subtitle: subtitle, rows: rows, footer: [.init("collections", "Back")])
    }

    func playlistPage(_ id: UUID, subtitle: String) -> GameFrontEnd.Page {
        guard let list = playlists.playlist(id) else { return playlistsPage(subtitle: subtitle) }
        if let draft = nameDraft {
            return .init(title: "Rename", subtitle: subtitle,
                         rows: [.init("nameField", "Name: " + draft.uppercased() + "_", selected: true)],
                         footer: [.init("nameCancel", "Cancel"), .init("nameDone", "Done", primary: true)])
        }
        let shown = MobileListLibrary(entries: list.entries, name: list.name, catalogue: catalogue!)
        // Entries whose pack or level is gone stay listed, so the player can remove them.
        var titles = [Int: String]()
        for (offset, entryIndex) in shown.entryIndices.enumerated() { titles[entryIndex] = shown.levels[offset].title }
        let rows = list.entries.enumerated().map { index, entry -> GameFrontEnd.Action in
            let title = titles[index].map { "\(index + 1)  " + $0 } ?? "\(index + 1)  Unavailable"
            return .init("entry.\(index)", title, enabled: true, selected: playlistSelection == index)
        }
        let selected = playlistSelection
        let hasSelection = selected.map { list.entries.indices.contains($0) } ?? false
        let playable = !shown.levels.isEmpty && shown.levels.count == list.entries.count
        return .init(
            title: list.name, subtitle: subtitle.isEmpty ? "\(list.entries.count) levels" : subtitle, rows: rows,
            footer: [
                .init("listPlay", "Play", enabled: playable, primary: true),
                .init("listShuffle", "Shuffle", enabled: playable && list.entries.count > 1),
                .init("entryUp", "Up", enabled: hasSelection && (selected ?? 0) > 0),
                .init("entryDown", "Down", enabled: hasSelection && (selected ?? 0) + 1 < list.entries.count),
                .init("entryRemove", "Remove", enabled: hasSelection),
                .init("listRename", "Rename"),
                .init("listDelete", confirmingDelete ? "Confirm delete" : "Delete", selected: confirmingDelete),
                .init("playlists", "Back"),
            ])
    }

    func addToPlaylistPage(subtitle: String) -> GameFrontEnd.Page {
        var rows = playlists.playlists.map { GameFrontEnd.Action("add." + $0.id.uuidString, $0.name + "  \($0.entries.count)") }
        rows.append(.init("addNew", "New playlist"))
        return .init(title: "Add to playlist", subtitle: subtitle, rows: rows, footer: [.init("back", "Back")])
    }

    // MARK: - Actions

    /// Handles the collection and playlist actions. Returns false for any other action.
    func handleCollections(_ id: String) -> Bool {
        switch id {
        case "collections": navigate(.collections)
        case "players": navigate(.players)
        case "fanBack": navigate(.family(.fan))
        case "shuffleAll": beginShuffleAll()
        case "shuffleStart": startShuffleAll()
        case "playerNew": newPlayer()
        case "playerRename": beginRenamingPlayer()
        case "playerDelete": deleteActivePlayer()
        case "playerPortrait": cyclePlayerPortrait()
        case "favourites": openList(favourites.entries, name: "Favourites", back: .collections)
        case "recents": openList(recents.entries, name: "Recently played", back: .collections)
        case "playlists": navigate(.playlists)
        case "listNew": if let created = playlists.create(name: "Playlist \(playlists.playlists.count + 1)") { savePlaylists(); openPlaylist(created) }
        case "addPlaylist": navigate(.addToPlaylist)
        case "addNew": addCurrentLevel(to: playlists.create(name: "Playlist \(playlists.playlists.count + 1)"))
        case "random": makeRandomPlaylist()
        case "runResume": resumeRun()
        case "listPlay": playPlaylist(shuffle: false)
        case "listShuffle": playPlaylist(shuffle: true)
        case "entryUp", "entryDown": moveSelectedEntry(id == "entryUp" ? -1 : 1)
        case "entryRemove": removeSelectedEntry()
        case "listRename": beginNaming()
        case "nameCancel": endNaming(commit: false)
        case "nameDone": endNaming(commit: true)
        case "listDelete": deleteSelectedPlaylist()
        default:
            if id.hasPrefix("player."), case let key = String(id.dropFirst(7)), profiles.players.contains(where: { $0.id == key }) { switchPlayer(key) }
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
        notice = added ? "ADDED" : "ALREADY IN PLAYLIST"
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
        let name = "Random 10 " + (currentPack?.title ?? "")
        guard let created = playlists.create(name: name, entries: picks) else { return }
        savePlaylists()
        openPlaylist(created)
    }

    // MARK: - Lists and runs

    /// Opens a list of levels from any packs as the current library.
    func openList(_ entries: [MobileFavourites.Entry], name: String, back: Route, run: MobilePlaylistRun? = nil, position: Int = 0) {
        guard let catalogue else { return }
        // A long list shows its titles without opening every pack.
        let lazy = entries.count > 100 && entries.allSatisfy { $0.title != nil }
        let list = MobileListLibrary(entries: entries, name: name, catalogue: catalogue, lazy: lazy)
        guard !list.levels.isEmpty else { return }
        library = list
        currentPack = nil
        activeRun = run
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders
        previewLoader = MobileMenuPreviewLoader {
            MobileListLibrary(entries: entries, name: name, catalogue: MobileCatalogue(portsRoot: ports, fanFolders: fan), lazy: lazy)
        }
        selectedIndex = min(position, list.levels.count - 1)
        selectedPreview = nil
        browserShown = false
        levelsBackRoute = back
        navigate(.levels)
        selectLevel(selectedIndex)
    }

    private func playPlaylist(shuffle: Bool) {
        guard let id = openPlaylistID, let run = playlists.startRun(id, shuffle: shuffle) else { return }
        savePlaylists()
        openList(run.entries, name: run.name, back: .playlist(id), run: run)
    }

    func resumeRun() {
        guard let run = playlists.run else { return }
        openList(run.entries, name: run.name, back: .collections, run: run, position: run.position)
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
        if shuffleScanning { details = ["Counting levels..."] }
        else if let pool = shufflePool { details = ["\(pool.entries.count) levels", "\(pool.packs) packs"] }
        else { details = ["Fan levels are not available."] }
        return .init(title: "Shuffle all", subtitle: subtitle, details: details,
                     footer: [.init("fanBack", "Back"),
                              .init("shuffleStart", "Start", enabled: !shuffleScanning && (shufflePool?.entries.isEmpty == false),
                                    primary: true)])
    }

    /// Counts the installed fan levels away from the main thread, then offers to start.
    func beginShuffleAll() {
        guard let catalogue, !shuffleScanning else { return }
        shuffleScanning = true
        shufflePool = nil
        navigate(.shuffleAll)
        let ports = catalogue.portsRoot, folders = catalogue.fanFolders
        Task {
            let pool = await Task.detached(priority: .userInitiated) {
                MobileCatalogue(portsRoot: ports, fanFolders: folders).fanPool()
            }.value
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
