#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    @discardableResult func saveProfiles() -> Bool {
        let imported = profiles.players.map { ArcadeProfile(id: $0.id, initials: $0.name, portrait: $0.portrait) }
        let storage = MobileStorage.standard(profile: "_players")
        let previous = storage.load(MobileProfiles.self, name: "players") ?? MobileProfiles()
        do { try storage.save(profiles, name: "players") }
        catch { notice = error.localizedDescription; return false }
        guard arcadeStore.importProfiles(imported, activeID: profiles.activeID) else {
            notice = arcadeStore.storageError ?? L10n.text("Players were not saved.")
            do { try storage.save(previous, name: "players") }
            catch { notice = error.localizedDescription }
            return false
        }
        return true
    }

    func playersPage(subtitle: String) -> GameFrontEnd.Page {
        #if os(tvOS)
        let holdToEdit = true
        #else
        let holdToEdit = false
        #endif
        let page = MobileCareerArt.players(profiles, subtitle: subtitle, draft: renamingPlayer ? nameDraft : nil,
            creating: creatingPlayer, portrait: draftPortrait, canDelete: canDeleteActivePlayer,
            confirmingDelete: confirmingDelete, hotSeatTurn: hotSeat.map { playerName($0.turn) }, holdToEdit: holdToEdit,
            editingPlayerID: editingPlayerID, hasSavedHotSeats: !hotSeats.sharedSessions(player: profiles.activeID).isEmpty)
        return page
    }

    var canDeleteActivePlayer: Bool {
        guard !creatingPlayer, let editingPlayerID else { return false }
        return arcadeStore.canDeleteProfile(editingPlayerID, runInProgress: game != nil)
    }

    func switchPlayer(_ id: String) {
        let previous = profiles
        profiles.select(id)
        guard saveProfiles() else { profiles = previous; rebuild(); return }
        if hotSeat != nil {
            hotSeats.endSession()
            guard saveHotSeats() else {
                let error = notice
                profiles = previous
                _ = saveProfiles()
                notice = error; rebuild(); return
            }
            hotSeatRoster = nil
        }
        reloadPlayerData()
        navigate(.players)
    }

    func reloadPlayerData() {
        MobileSettings.activateProfile(settingsProfileID, in: .standard)
        libraryInput.reset()
        MobileMusic.shared.selectProfile(settingsProfileID)
        let isDefault = profiles.active.id == MobileProfiles.defaultID
        do {
            collectionsBridge = try MobileCollectionsBridge(profileID: profiles.activeID)
            favourites = collectionsBridge!.favourites
            recents = collectionsBridge!.recents
            playlists = collectionsBridge!.playlists(hotSeatID: hotSeat?.id)
        } catch {
            collectionsBridge = nil
            favourites = MobileFavourites.load(from: storage, legacy: isDefault)
            recents = MobileRecents.load(from: storage, legacy: isDefault)
            playlists = MobilePlaylistStore.load(from: storage, legacy: isDefault)
            notice = error.localizedDescription
        }
        activeRun = nil
        playlistSelection = nil
        confirmingDelete = false
        loadCheckpoint()
    }

    func saveSharedCollections() {
        do {
            guard let collectionsBridge else { throw CocoaError(.fileWriteUnknown) }
            try collectionsBridge.save(favourites: favourites, recents: recents, playlists: playlists, hotSeatID: hotSeat?.id)
        } catch {
            if let collectionsBridge {
                favourites = collectionsBridge.favourites; recents = collectionsBridge.recents; playlists = collectionsBridge.playlists(hotSeatID: hotSeat?.id)
            }
            notice = error.localizedDescription
        }
    }

    func newPlayer() {
        guard profiles.players.count < MobileProfiles.maximum else { return }
        if route != .hotSeat { hotSeatRoster = nil }
        creatingPlayer = true; renamingPlayer = true
        editingPlayerID = nil; confirmingDelete = false
        nameDraft = ""; draftPortrait = profiles.players.count % 8
        searchField.text = ""
        navigate(.players)
        canvas.focusAction("nameField")
        #if os(iOS)
        searchField.becomeFirstResponder()
        #endif
    }

    func beginRenamingPlayer(_ id: String? = nil) {
        let candidate = id ?? profiles.activeID
        guard let player = profiles.players.first(where: { $0.id == candidate }) else { return }
        creatingPlayer = false; renamingPlayer = true
        editingPlayerID = candidate; confirmingDelete = false
        nameDraft = arcadeStore.records.profile(candidate)?.initials ?? player.name
        draftPortrait = player.portrait
        searchField.text = nameDraft
        rebuild()
        canvas.focusAction("nameField")
    }

    func cyclePlayerPortrait() { draftPortrait = (draftPortrait + 1) % 8; rebuild() }

    func finishProfileNaming(commit: Bool) {
        let newGuest = creatingPlayer && hotSeatRoster != nil
        if commit, let draft = nameDraft {
            if creatingPlayer && !newGuest && hotSeat != nil {
                hotSeats.endSession()
                guard saveHotSeats() else { rebuild(); return }
                hotSeatRoster = nil
            }
            let initials = ArcadeProfile(initials: draft).initials
            let previous = profiles
            let previousRoster = hotSeatRoster
            if creatingPlayer {
                guard let id = profiles.add(name: initials) else { return }
                if newGuest {
                    profiles.setPortrait(id, to: draftPortrait)
                    hotSeatRoster?.toggle(id)
                } else { profiles.select(id) }
            } else if let editingPlayerID {
                profiles.rename(editingPlayerID, to: initials)
                profiles.setPortrait(editingPlayerID, to: draftPortrait)
            }
            if creatingPlayer && !newGuest { profiles.setPortrait(profiles.activeID, to: draftPortrait) }
            guard saveProfiles() else { profiles = previous; hotSeatRoster = previousRoster; rebuild(); return }
            if creatingPlayer && !newGuest {
                reloadPlayerData()
            }
        }
        renamingPlayer = false; creatingPlayer = false; nameDraft = nil
        editingPlayerID = nil; confirmingDelete = false
        searchField.resignFirstResponder()
        searchField.text = searchQuery
        libraryCloud.requestSync()
        if newGuest { navigate(.hotSeat) } else { rebuild() }
    }

    func deleteActivePlayer() {
        guard canDeleteActivePlayer else { return }
        if !confirmingDelete { confirmingDelete = true; canvas.focusedID = "playerDeleteCancel"; rebuild(); return }
        deleteEditedPlayer()
    }

    private func deleteEditedPlayer() {
        guard canDeleteActivePlayer else { return }
        guard confirmingDelete, let removed = editingPlayerID else { return }
        let previous = profiles
        let previousSeats = hotSeats
        hotSeats.removePlayer(removed)
        guard saveHotSeats() else { rebuild(); return }
        profiles.delete(removed)
        guard saveProfiles() else {
            let error = notice
            profiles = previous; hotSeats = previousSeats; _ = saveHotSeats()
            notice = error; rebuild(); return
        }
        guard arcadeStore.deleteProfile(removed) else {
            let error = arcadeStore.storageError ?? L10n.text("Player was not deleted.")
            profiles = previous
            _ = saveProfiles()
            hotSeats = previousSeats; _ = saveHotSeats()
            notice = error; rebuild(); return
        }
        hotSeatRoster = nil
        renamingPlayer = false; creatingPlayer = false; nameDraft = nil; editingPlayerID = nil
        searchField.resignFirstResponder(); searchField.text = searchQuery
        Task {
            var cleanupError: String?
            do { try await removePlayerFiles(removed) }
            catch { cleanupError = error.localizedDescription }
            reloadPlayerData(); navigate(.players)
            if let cleanupError { notice = cleanupError; rebuild() }
            libraryCloud.requestSync()
        }
    }

    /// Local and cloud deletions remove the same player-owned files and settings.
    func removePlayerFiles(_ id: String) async throws {
        UserDefaults.standard.removeObject(forKey: PlayerControlSettings.defaultsKey(profileID: id))
        #if os(tvOS)
        UserDefaults.standard.removeObject(forKey: LemmingsTVCore.TVPreferences.inputKey(id))
        #endif
        guard let checkpointStore else { throw MobileCheckpointError.invalid }
        try await checkpointStore.removeSoloRuns(owner: id)
        let directory = MobileStorage.standard(profile: id).directory
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
#endif
