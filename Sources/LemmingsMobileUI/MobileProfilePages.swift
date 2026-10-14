#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
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
            notice = arcadeStore.storageError ?? "Players were not saved."
            do { try storage.save(previous, name: "players") }
            catch { notice = error.localizedDescription }
            return false
        }
        return true
    }

    func playersPage(subtitle: String) -> GameFrontEnd.Page {
        var page = MobileCareerArt.players(profiles, subtitle: subtitle, draft: renamingPlayer ? nameDraft : nil,
            creating: creatingPlayer, portrait: draftPortrait, canDelete: canDeleteActivePlayer,
            confirmingDelete: confirmingDelete, hotSeatTurn: hotSeat.map { playerName($0.turn) })
        if !renamingPlayer { page.rows.append(.init("cloudSaves", "Cloud saves")) }
        return page
    }

    var canDeleteActivePlayer: Bool {
        let ownsCheckpoint = pendingCheckpoint?.owner == profiles.activeID
            || (pendingCheckpoint != nil && pendingCheckpoint?.owner == nil && profiles.activeID == MobileProfiles.defaultID)
        return !ownsCheckpoint && arcadeStore.canDeleteProfile(profiles.activeID, runInProgress: game != nil)
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
        nameDraft = ""; draftPortrait = profiles.players.count % 8
        searchField.text = ""
        navigate(.players)
        searchField.becomeFirstResponder()
    }

    func beginRenamingPlayer() {
        creatingPlayer = false; renamingPlayer = true
        nameDraft = arcadeStore.records.profile(profiles.activeID)?.initials ?? profiles.active.name
        draftPortrait = profiles.active.portrait
        searchField.text = nameDraft; rebuild(); searchField.becomeFirstResponder()
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
            } else { profiles.rename(profiles.activeID, to: initials) }
            if !newGuest { profiles.setPortrait(profiles.activeID, to: draftPortrait) }
            guard saveProfiles() else { profiles = previous; hotSeatRoster = previousRoster; rebuild(); return }
            if creatingPlayer && !newGuest {
                reloadPlayerData()
            }
        }
        renamingPlayer = false; creatingPlayer = false; nameDraft = nil
        searchField.text = searchQuery
        if newGuest { navigate(.hotSeat) } else { rebuild() }
    }

    func deleteActivePlayer() {
        guard canDeleteActivePlayer else { return }
        let candidate = profiles.activeID
        Task {
            do {
                guard let checkpointStore else { throw MobileCheckpointError.invalid }
                let ownsSavedRun = try await checkpointStore.hasSavedSoloRun(owner: candidate)
                guard candidate == profiles.activeID else { return }
                if ownsSavedRun {
                    loadCheckpoint(); notice = "Resume this player's saved run before deleting."; rebuild(); return
                }
                deleteUnsavedActivePlayer()
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }

    private func deleteUnsavedActivePlayer() {
        guard canDeleteActivePlayer else { return }
        if !confirmingDelete { confirmingDelete = true; rebuild(); return }
        let removed = profiles.activeID
        let previous = profiles
        profiles.delete(removed)
        guard saveProfiles() else { profiles = previous; rebuild(); return }
        guard arcadeStore.deleteProfile(removed) else {
            profiles = previous
            _ = saveProfiles()
            notice = arcadeStore.storageError ?? "Player was not deleted."; rebuild(); return
        }
        removeFromHotSeats(removed)
        do { try FileManager.default.removeItem(at: MobileStorage.standard(profile: removed).directory) }
        catch { notice = error.localizedDescription }
        reloadPlayerData(); navigate(.players)
    }
}
#endif
