#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit
import UniformTypeIdentifiers

extension MobileLibraryViewController {
    func configureLibraryCloud() {
        #if os(iOS)
        cloudProgress.isEnabled = { [weak self] in self?.libraryCloud.enabled == true }
        #endif
        libraryCloud.canImport = { [weak self] in
            guard let self else { return false }
            return game == nil && !preparingCloudLevel && !learningPreparing && !renamingPlayer && nameDraft == nil
        }
        libraryCloud.captureExtra = { profile, seat in
            let storage = MobileStorage.standard(profile: seat.map { "hotseat." + $0 } ?? profile)
            var progress = try MobileCampaignProgress.capture(storage: storage)
            guard var saved = storage.load(MobileLearningState.self, name: "learning") else { return progress }
            if saved.journeySession == nil, saved.run?.source == .playlist(LearningJourney.playlistID) {
                saved.refreshJourneySession()
                try storage.save(saved, name: "learning")
            }
            var values: [String: GameProgressValue] = ["LearningJourneyProgress": .learning(saved.progress)]
            if let snapshot = saved.journeySession { values["LearningJourneySession"] = .journeySession(snapshot) }
            try progress.merge(.init(values: values))
            return progress
        }
        libraryCloud.captureSeats = { [weak self] in
            guard let self else { return [] }
            let current: [MobileHotSeat] = hotSeats.current.map { [$0] } ?? []
            let seats: [MobileHotSeat] = hotSeats.saved + current
            return seats.map { seat -> ArcadeStore.SavedHotSeat in
                let policy: ArcadeStore.TurnPolicy = seat.policy == .everyLevel ? .everyLevel : .atFirstFail
                return ArcadeStore.SavedHotSeat(id: seat.id, host: seat.host, players: seat.players,
                    turn: seat.turn, active: false, savedAt: seat.savedAt, policy: policy)
            }
        }
        libraryCloud.importSeats = { [weak self] sessions in
            guard let self else { return }
            let seats = sessions.compactMap { saved -> MobileHotSeat? in
                guard var seat = MobileHotSeat(host: saved.host, players: saved.players,
                    policy: saved.policy == .atFirstFail ? .atFirstFail : .everyLevel,
                    id: saved.id, savedAt: saved.savedAt ?? .distantPast) else { return nil }
                seat.pass(to: saved.turn ?? saved.host); seat.savedAt = saved.savedAt ?? .distantPast
                return seat
            }
            hotSeats.importCloudSessions(seats)
            try hotSeats.save(to: MobileStorage.standard(profile: "_players"))
        }
        libraryCloud.onImported = { [weak self] in
            guard let self else { return }
            let records = arcadeStore.records
            let removed = Set(profiles.players.map(\.id)).subtracting(records.profiles.map(\.id))
            profiles.importCloudProfiles(records.profiles.map { .init(id: $0.id, name: $0.initials, portrait: $0.portrait) }, active: records.activeProfileID)
            do { try MobileStorage.standard(profile: "_players").save(profiles, name: "players") }
            catch { notice = error.localizedDescription }
            if !removed.isEmpty {
                for id in removed { hotSeats.removePlayer(id) }
                hotSeatRoster = nil
                _ = saveHotSeats()
                Task {
                    for id in removed {
                        do { try await removePlayerFiles(id) }
                        catch { notice = error.localizedDescription }
                    }
                    loadCheckpoint(); rebuild()
                }
            }
            reloadPlayerData()
            rebuild()
        }
        libraryCloud.onChange = { [weak self] in if self?.route == .cloudSaves { self?.rebuild() } }
        libraryCloud.start()
    }
    func handleCloudSync(_ id: String) -> Bool {
        if id == "cloudSaves" {
            syncBackRoute = route; syncMessage = ""
            navigate(.cloudSaves); return true
        }
        guard route == .cloudSaves, id.hasPrefix("sync") else { return false }
        guard (canvas.page.rows + canvas.page.footer).contains(where: { $0.id == id && $0.enabled }) else { return true }
        switch id {
        case "syncBack": navigate(syncBackRoute)
        case "syncTester":
            syncBusy = true; syncMessage = ""
            Task { [weak self] in
                guard let self else { return }
                do { try await libraryCloud.enableTesterSync() }
                catch { if route == .cloudSaves { syncMessage = error.localizedDescription } }
                syncBusy = false; rebuild()
            }
        default: break
        }
        rebuild(); return true
    }
}
#endif
