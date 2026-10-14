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
            return game == nil && !preparingCloudLevel && !renamingPlayer && nameDraft == nil
        }
        libraryCloud.captureExtra = { profile, seat in
            let saved = MobileStorage.standard(profile: seat.map { "hotseat." + $0 } ?? profile).load(MobileLearningState.self, name: "learning")
            return saved.map { .init(values: ["LearningJourneyProgress": .learning($0.progress)]) } ?? .init()
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
            profiles.importCloudProfiles(records.profiles.map { .init(id: $0.id, name: $0.initials, portrait: $0.portrait) }, active: records.activeProfileID)
            do { try MobileStorage.standard(profile: "_players").save(profiles, name: "players") }
            catch { notice = error.localizedDescription }
            rebuild()
        }
        libraryCloud.onChange = { [weak self] in if self?.route == .cloudSaves { self?.rebuild() } }
        libraryCloud.start()
    }
    func handleCloudSync(_ id: String) -> Bool {
        if id == "cloudSaves" { syncBackRoute = route; syncCode = nil; syncDraft = nil; syncMessage = ""; navigate(.cloudSaves); return true }
        guard route == .cloudSaves, id.hasPrefix("sync") else { return false }
        guard (canvas.page.rows + canvas.page.footer).contains(where: { $0.id == id && $0.enabled }) else { return true }
        #if os(tvOS)
        if handleTVSaveBackup(id) { return true }
        #endif
        syncMessage = ""
        switch id {
        case "syncBack": navigate(syncBackRoute)
        case "syncToggle": libraryCloud.enabled.toggle()
        case "syncCancel": syncCode = nil; syncDraft = nil; searchField.resignFirstResponder()
        case "syncEnterCode": syncDraft = ""; searchField.text = ""; searchField.becomeFirstResponder()
        case "syncCodeField": searchField.becomeFirstResponder()
        case "syncCopy":
            #if os(iOS)
            UIPasteboard.general.string = syncCode; syncMessage = "Copied"
            #else
            syncMessage = syncCode ?? ""
            #endif
        case "syncExportKey":
            do {
                importingSyncKey = false
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent("Ultimate Lemmings Recovery.lemmingssync")
                try libraryCloud.recoveryData().write(to: url, options: .atomic)
                syncRecoveryExport = url
                #if os(tvOS)
                MobileTVFileTransfer.exportFile(url, from: self) { [weak self] in
                    try? FileManager.default.removeItem(at: folder)
                    self?.syncRecoveryExport = nil
                }
                #else
                let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
                picker.delegate = self
                syncMessage = "Keep the recovery key private."
                present(picker, animated: true)
                #endif
            } catch { syncMessage = error.localizedDescription }
        case "syncImportKey":
            importingSyncKey = true
            #if os(tvOS)
            MobileTVFileTransfer.importFiles(from: self, directory: false) { [weak self] in self?.importCloudRecoveryKey($0) }
            #else
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
            picker.delegate = self; picker.allowsMultipleSelection = false
            present(picker, animated: true)
            #endif
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
    func importCloudRecoveryKey(_ source: URL) {
        let accessed = source.startAccessingSecurityScopedResource()
        defer {
            if accessed { source.stopAccessingSecurityScopedResource() }
            #if os(tvOS)
            MobileTVFileTransfer.removeImportedFiles(source)
            #endif
        }
        do {
            let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 16385
            guard size <= 16384 else { throw CocoaError(.fileReadCorruptFile) }
            try libraryCloud.restoreRecoveryData(Data(contentsOf: source))
            Task { [weak self] in await self?.libraryCloud.syncNow(); self?.rebuild() }
        } catch { syncMessage = error.localizedDescription; rebuild() }
    }
}
#endif
