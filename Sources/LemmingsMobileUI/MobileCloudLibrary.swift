#if os(iOS)
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import UIKit

extension MobileLibraryViewController {
    func configureLibraryCloud() {
        libraryCloud.canImport = { [weak self] in
            guard let self else { return false }
            return game == nil && !preparingCloudLevel && !renamingPlayer && nameDraft == nil
        }
        libraryCloud.captureExtra = { profile, seat in
            let saved = MobileStorage.standard(profile: seat.map { "hotseat." + $0 } ?? profile).load(MobileLearningState.self, name: "learning")
            return saved.map { .init(values: ["LearningJourneyProgress": .learning($0.progress)]) } ?? .init()
        }
        libraryCloud.captureSeats = { [weak self] in
            guard let self else { return [] }
            return (hotSeats.saved + (hotSeats.current.map { [$0] } ?? [])).map {
                .init(id: $0.id, host: $0.host, players: $0.players, turn: $0.turn, active: false,
                      savedAt: $0.savedAt, policy: $0.policy == .everyLevel ? .everyLevel : .atFirstFail)
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
            profiles.importCloudProfiles(records.profiles.map { .init(id: $0.id, name: $0.initials, portrait: $0.portrait) }, active: records.activeProfileID)
            do { try MobileStorage.standard(profile: "_players").save(profiles, name: "players") }
            catch { notice = error.localizedDescription }
            rebuild()
        }
        libraryCloud.onChange = { [weak self] in if self?.route == .cloudSaves { self?.rebuild() } }
        libraryCloud.start()
    }
    func handleCloudSync(_ id: String) -> Bool {
        if id == "cloudSaves" { syncCode = nil; syncDraft = nil; syncMessage = ""; navigate(.cloudSaves); return true }
        guard route == .cloudSaves, id.hasPrefix("sync") else { return false }
        guard (canvas.page.rows + canvas.page.footer).contains(where: { $0.id == id && $0.enabled }) else { return true }
        syncMessage = ""
        switch id {
        case "syncBack": navigate(.players)
        case "syncToggle": libraryCloud.enabled.toggle()
        case "syncCancel": syncCode = nil; syncDraft = nil; searchField.resignFirstResponder()
        case "syncEnterCode": syncDraft = ""; searchField.text = ""; searchField.becomeFirstResponder()
        case "syncCodeField": searchField.becomeFirstResponder()
        case "syncCopy": UIPasteboard.general.string = syncCode; syncMessage = "Copied"
        case "syncNow", "syncMakeLink", "syncJoin":
            syncBusy = true; searchField.resignFirstResponder()
            Task { [weak self] in
                guard let self else { return }
                do {
                    if id == "syncNow" { await libraryCloud.syncNow() }
                    else if id == "syncMakeLink" { syncCode = try await libraryCloud.makeLink() }
                    else { try await libraryCloud.join(syncDraft ?? ""); syncDraft = nil; await libraryCloud.syncNow() }
                } catch { syncMessage = error.localizedDescription }
                syncBusy = false; rebuild()
            }
        default: break
        }
        rebuild(); return true
    }
}
#endif
