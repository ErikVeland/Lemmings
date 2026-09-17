import Foundation
import CryptoKit
import NxlvKit

@MainActor final class ArcadeStore {
    static var shared = ArcadeStore()
    private(set) var records = ArcadeRecords()
    private(set) var storageError: String?
    private let file: URL
    private var recordFile: ArcadeRecordFile
    private let recoveryStore: RunRecoveryStore
    private(set) var storageNotice: String?
    private var canWrite = true
    private let bundledProofs: TrolleyBundledProofs?
    var profilesAreWritable: Bool { canWrite }

    /// The house rule and shared campaign survive app restarts.
    enum TurnPolicy: String, CaseIterable, Sendable {
        case everyLevel = "Every level", atFirstFail = "At first fail"
        var title: String { rawValue }
        var detail: String {
            switch self {
            case .everyLevel: return "The turn passes when a level ends, won or lost."
            case .atFirstFail: return "A player keeps going until they lose a level."
            }
        }
    }
    private static let turnPolicyKey = "HotSeat.turnPolicy"
    private let defaults: UserDefaults
    var turnPolicy: TurnPolicy {
        get { defaults.string(forKey: Self.turnPolicyKey).flatMap(TurnPolicy.init(rawValue:)) ?? .everyLevel }
        set { defaults.set(newValue.rawValue, forKey: Self.turnPolicyKey) }
    }

    private(set) var sessionProfileIDs: [String] = []
    private var sessionTurnID: String?
    /// True only with a real roster. One player is not a hot seat.
    var hotSeatIsActive: Bool { sessionProfileIDs.count > 1 }
    var playingProfile: ArcadeProfile? { records.profile(playingProfileID) }
    var playingProfileID: String { sessionTurnID ?? records.activeProfileID }
    var sessionProfiles: [ArcadeProfile] {
        let ids = sessionProfileIDs.isEmpty ? [records.activeProfileID] : sessionProfileIDs
        return ids.compactMap { records.profile($0) }
    }
    func toggleSessionProfile(_ id: String) {
        guard id != records.activeProfileID, records.profile(id) != nil else { return }
        if sessionProfileIDs.count == 2, sessionProfileIDs.contains(id) { endHotSeat(); return }
        if sessionProfileIDs.isEmpty { sessionProfileIDs = [records.activeProfileID] }
        if sessionProfileIDs.contains(id) { sessionProfileIDs.removeAll { $0 == id } }
        else { sessionProfileIDs.append(id) }
        // A player who leaves cannot still be holding the turn.
        if let turn = sessionTurnID, !sessionProfileIDs.contains(turn) { sessionTurnID = nil }
        if sessionProfileIDs.count < 2 { endHotSeat() } else { startHotSeatProgress() }
    }
    private struct SavedHotSeat: Codable {
        let id: String
        let host: String
        let players: [String]
        let turn: String?
        let active: Bool
    }
    private(set) var hotSeatID: String?
    private var hotSeatHostID: String?
    private func sessionKey(host: String) -> String {
        let fileID = SHA256.hash(data: Data(file.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return "HotSeat.saved.\(fileID).\(host)"
    }
    private func persistSession(active: Bool = true) {
        guard let id = hotSeatID, let host = hotSeatHostID else { return }
        let saved = SavedHotSeat(id: id, host: host, players: sessionProfileIDs, turn: sessionTurnID, active: active)
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: sessionKey(host: host)) }
    }
    private func restoreSession(activeOnly: Bool) -> Bool {
        let host = records.activeProfileID
        guard let data = defaults.data(forKey: sessionKey(host: host)),
              let saved = try? JSONDecoder().decode(SavedHotSeat.self, from: data),
              saved.host == host, !activeOnly || saved.active else { return false }
        let players = saved.players.filter { records.profile($0) != nil }
        guard Set(players).count == players.count, players.count >= 2, players.contains(host) else { return false }
        hotSeatID = saved.id; hotSeatHostID = host; sessionProfileIDs = players
        sessionTurnID = saved.turn.flatMap { players.contains($0) ? $0 : nil }
        return true
    }
    func endHotSeat() {
        persistSession(active: false)
        sessionProfileIDs = []; sessionTurnID = nil; hotSeatID = nil; hotSeatHostID = nil
    }
    private func startHotSeatProgress() {
        if hotSeatID == nil { hotSeatID = UUID().uuidString; hotSeatHostID = records.activeProfileID }
        persistSession()
    }
    /// Resume the shared campaign before offering a new roster.
    func prepareHotSeat() {
        guard sessionProfileIDs.count < 2, records.profiles.count >= 2 else { return }
        if restoreSession(activeOnly: false) { persistSession(); return }
        let host = records.activeProfileID
        let guest = records.profiles.map(\.id).first { $0 != host }
        sessionProfileIDs = [host] + (guest.map { [$0] } ?? [])
        sessionTurnID = nil
        if sessionProfileIDs.count >= 2 { startHotSeatProgress() }
    }
    /// A fresh namespace starts every shared campaign at the beginning.
    @discardableResult func startNewHotSeat() -> Bool {
        guard hotSeatIsActive, canWrite, storageError == nil else { return false }
        hotSeatID = UUID().uuidString
        hotSeatHostID = records.activeProfileID
        sessionTurnID = nil
        persistSession()
        return true
    }
    func nextSessionProfile(after id: String) -> ArcadeProfile? {
        let players = sessionProfiles
        guard players.count > 1 else { return nil }
        let index = players.firstIndex { $0.id == id }
        return players[index.map { ($0 + 1) % players.count } ?? 0]
    }
    @discardableResult func passSessionTurn(after id: String) -> Bool {
        guard let next = nextSessionProfile(after: id), canWrite, storageError == nil else { return false }
        sessionTurnID = next.id
        persistSession()
        return true
    }


    init(file: URL? = nil, bundledProofs: TrolleyBundledProofs? = .load(), defaults: UserDefaults = .standard,
         checkpoints: RunRecoveryStore? = nil) {
        self.bundledProofs = bundledProofs
        self.defaults = defaults
        recoveryStore = checkpoints ?? RunRecoveryStore()
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let preview = Bundle.main.bundleIdentifier?.contains("preview") == true ? "Arcade Preview" : "Arcade"
        self.file = file ?? support.appendingPathComponent("Ultimate Lemmings/\(preview)/records-v1.json")
        recordFile = ArcadeRecordFile(url: self.file)
        do {
            if let loaded = try recordFile.load() { records = loaded }
            if recordFile.recovered {
                storageNotice = "Records recovered from backup. Recent results may be missing."
            }
        } catch {
            storageError = (error as? ArcadeRecordFile.Failure)?.errorDescription
                ?? "Records could not be read. Existing files have been preserved."
            canWrite = false
        }
        _ = restoreSession(activeOnly: true)
        adoptBundledProofs()
    }
    private func adoptBundledProofs() {
        records.retainBundledTrolleyMaxima(bundledProofs?.maxima ?? [:])
        for entry in bundledProofs?.catalogue.levels ?? [] {
            if let conditions = entry.conditions { acceptBundledProof(for: conditions) }
        }
    }
    /// Reads the records file again, for example after another copy of the app changed it.
    @discardableResult func reloadRecords() -> Bool {
        let reopened = ArcadeRecordFile(url: file)
        do {
            records = try reopened.load() ?? ArcadeRecords()
            recordFile = reopened; canWrite = true; storageError = nil
            storageNotice = reopened.recovered ? "Records recovered from backup. Recent results may be missing." : nil
            adoptBundledProofs()
            return true
        } catch {
            storageError = (error as? ArcadeRecordFile.Failure)?.errorDescription
                ?? "Records could not be read. Existing files have been preserved."
            return false
        }
    }
    /// The way out when records cannot be read. The unreadable files stay beside the new records.
    @discardableResult func startNewRecords() -> Bool {
        let manager = FileManager.default
        let stamp = UUID().uuidString
        do {
            for url in [file, recordFile.backupURL] where manager.fileExists(atPath: url.path) {
                try manager.moveItem(at: url, to: url.deletingLastPathComponent()
                    .appendingPathComponent("\(url.lastPathComponent).set-aside-\(stamp)"))
            }
        } catch {
            storageError = "Records could not be moved aside. Check folder access."
            return false
        }
        endHotSeat()
        recordFile = ArcadeRecordFile(url: file)
        records = ArcadeRecords(); canWrite = true; storageError = nil; storageNotice = nil
        adoptBundledProofs()
        save()
        return storageError == nil
    }
    /// Players who can be removed now. A player in the current turn or run stays until it ends.
    func canDeleteProfile(_ id: String, runInProgress: Bool) -> Bool {
        guard canWrite, storageError == nil, records.profiles.count > 1, records.profile(id) != nil else { return false }
        guard runInProgress else { return true }
        return id != records.activeProfileID && id != playingProfileID && !sessionProfileIDs.contains(id)
    }
    /// Removes a player, their records, campaign progress, saved runs and replay movies.
    @discardableResult func deleteProfile(_ id: String) -> Bool {
        guard canWrite, storageError == nil else { return false }
        let previous = records
        guard let replays = records.removeProfile(id) else { return false }
        save()
        guard storageError == nil else { records = previous; return false }
        if sessionProfileIDs.contains(id) {
            if hotSeatHostID == id || sessionProfileIDs.count <= 2 { endHotSeat() }
            else {
                sessionProfileIDs.removeAll { $0 == id }
                if sessionTurnID == id { sessionTurnID = nil }
                persistSession()
            }
        }
        if previous.activeProfileID == id { endHotSeat() }
        let folder = file.deletingLastPathComponent()
        for replay in replays { try? FileManager.default.removeItem(at: folder.appendingPathComponent(replay.relativePath)) }
        try? recoveryStore.discard(profileID: id)
        removeSavedProgress(of: id)
        return true
    }
    private func removeSavedProgress(of id: String) {
        let prefix = "ArcadeProfile.\(id)."
        for (key, value) in defaults.dictionaryRepresentation() {
            if key.hasPrefix(prefix) || (id == ArcadeProfile.legacyID && LegacySaveMigration.isProgress(key)) {
                defaults.removeObject(forKey: key)
            } else if key.hasPrefix("GameCenter.profile."), value as? String == id {
                defaults.removeObject(forKey: key)
            }
        }
        // A shared campaign hosted by this player can no longer be resumed.
        let hosted = sessionKey(host: id)
        if let data = defaults.data(forKey: hosted), let saved = try? JSONDecoder().decode(SavedHotSeat.self, from: data) {
            let shared = "HotSeat.\(saved.id)."
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(shared) { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: hosted)
    }
    func progressKey(_ key: String) -> String {
        // A hot seat campaign is nobody's solo campaign, so it never reads or
        // writes a profile's own progress.
        if let hotSeatID { return "HotSeat.\(hotSeatID).\(key)" }
        return Self.progressKey(key, profileID: records.activeProfileID)
    }
    static func progressKey(_ key: String, profileID: String) -> String {
        profileID == ArcadeProfile.legacyID ? key : "ArcadeProfile.\(profileID).\(key)"
    }
    func save() {
        guard canWrite else { return }
        do {
            try recordFile.save(records)
            storageError = nil
        } catch {
            storageError = (error as? ArcadeRecordFile.Failure)?.errorDescription
                ?? "Records were not saved. Check free space and folder access."
            if case ArcadeRecordFile.Failure.changedOnDisk = error { canWrite = false }
        }
    }
    @discardableResult func record(_ run: ArcadeRun) -> ArcadeReport? {
        if let conditions = run.level.conditions { acceptBundledProof(for: conditions) }
        let result = records.record(run)
        if result != nil {
            save()
            if storageError == nil { GameCenterScores.shared.completed(profileID: run.profileID, history: records.trolley) }
        }
        return result
    }
    func beginAttempt(id: UUID, profileID: String, level: ArcadeLevel, previousID: UUID?) {
        guard let conditions = level.conditions else { return }
        acceptBundledProof(for: conditions)
        let prior = records.trolley.starts.first { $0.id == previousID && $0.profileID == profileID && $0.conditions == conditions }
        let completed = records.trolley.attempts.first { $0.id == previousID && $0.run.profileID == profileID && $0.run.level.conditions == conditions }
        let kind: TrolleyStartKind = completed.map { $0.run.didWin ? .retryAfterSuccess : .retryAfterFailure }
            ?? (prior == nil ? .fresh : .restartDuringPlay)
        records.beginTrolleyAttempt(.init(id: id, profileID: profileID, conditions: conditions,
            parentAttemptID: completed?.id ?? prior?.id, kind: kind))
        save()
    }
    func acceptMaximum(_ evidence: TrolleyMaximum, conditions: TrolleyConditions, assisted: Bool) throws {
        try records.acceptTrolleyMaximum(evidence, conditions: conditions, assisted: assisted); save()
    }
    private func acceptBundledProof(for conditions: TrolleyConditions) {
        guard let proof = bundledProofs?.maximum(for: conditions) else { return }
        for assisted in [false, true] where records.trolley.maximum(conditions: conditions, assisted: assisted) != proof {
            try? records.acceptTrolleyMaximum(proof, conditions: conditions, assisted: assisted)
        }
    }
    /// Called only for a completed movie. A movie hash is local evidence, not replay or server verification.
    func preserveReplay(_ url: URL, attemptID: UUID) {
        guard canWrite, records.trolley.attempts.contains(where: { $0.id == attemptID }),
              !records.trolley.replays.contains(where: { $0.attemptID == attemptID }) else { return }
        do {
            let relative = "Replays/\(attemptID.uuidString).mp4"
            let destination = file.deletingLastPathComponent().appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.copyItem(at: url, to: destination) }
            let handle = try FileHandle(forReadingFrom: destination)
            defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
            records.attachTrolleyReplay(.init(attemptID: attemptID, relativePath: relative,
                sha256: hash.finalize().map { String(format: "%02x", $0) }.joined()))
            save()
        } catch { /* Movie retention is optional. The immutable local attempt remains valid. */ }
    }
    @discardableResult func saveProfile(id: String?, initials: String, portrait: Int, select: Bool) -> ArcadeProfile? {
        guard canWrite else { return nil }
        let previous = records
        let profileID: String
        if let id {
            guard records.profile(id) != nil else { return nil }
            records.updateProfile(id, initials: initials, portrait: portrait)
            if select { records.selectProfile(id) }
            profileID = id
        } else {
            guard let added = records.addProfile(initials: initials, portrait: portrait, select: select) else { return nil }
            profileID = added.id
        }
        save()
        guard storageError == nil else { records = previous; return nil }
        if select && previous.activeProfileID != records.activeProfileID { endHotSeat() }
        return records.profile(profileID)
    }
    @discardableResult func updateProfile(_ id: String, initials: String, portrait: Int) -> ArcadeProfile? {
        saveProfile(id: id, initials: initials, portrait: portrait, select: false)
    }
    @discardableResult func addProfile(initials: String, portrait: Int, select: Bool = true) -> ArcadeProfile? {
        saveProfile(id: nil, initials: initials, portrait: portrait, select: select)
    }
    func selectProfile(_ id: String) {
        guard canWrite, let profile = records.profile(id) else { return }
        saveProfile(id: id, initials: profile.initials, portrait: profile.portrait, select: true)
    }
    static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
