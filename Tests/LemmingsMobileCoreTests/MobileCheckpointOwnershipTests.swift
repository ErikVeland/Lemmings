import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileCheckpointOwnershipTests {
    @Test func aCopiedScopedFileCannotResumeAsAnotherOwner() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json")
        let store = MobileCheckpointStore(url: url)
        try await store.save(envelope(owner: "one"))
        let scoped = try #require(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("scoped-") && !$0.lastPathComponent.hasSuffix("backup") })
        let other = root.appendingPathComponent("other/current.json")
        try await MobileCheckpointStore(url: other).save(envelope(owner: "two"))
        let bytes = try Data(contentsOf: other)
        try bytes.write(to: scoped)
        await #expect(throws: MobileCheckpointError.invalid) { try await store.load(owner: "one", scope: nil) }
        #expect(try Data(contentsOf: scoped) == bytes)
    }
    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func journeyBindingSurvivesDiskAndRejectsAnotherQueueOrPosition(engine: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json"), queue = UUID()
        var saved = envelope(owner: "guest", scope: "hotseat.team", engine: engine)
        saved.journeyContext = .init(runID: queue, position: 3)
        try await MobileCheckpointStore(url: url).save(saved)
        let loaded = try #require(await MobileCheckpointStore(url: url).load(owner: "host", scope: "hotseat.team"))
        #expect(loaded.matchesJourney(runID: queue, position: 3, levelIdentifier: "level"))
        #expect(!loaded.matchesJourney(runID: UUID(), position: 3, levelIdentifier: "level"))
        #expect(!loaded.matchesJourney(runID: queue, position: 2, levelIdentifier: "level"))
        #expect(!loaded.matchesJourney(runID: queue, position: 3, levelIdentifier: "changed"))
        saved.journeyContext = .init()
        #expect(!saved.matchesJourney(runID: queue, position: 3, levelIdentifier: "level"))
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        legacy.removeValue(forKey: "journeyContext")
        let older = try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(older.journeyContext == nil && older.matchesJourney(runID: queue, position: 3, levelIdentifier: "level"))
    }
    private func envelope(owner: String?, scope: String? = nil, tick: Int = 10, date: Date = Date(), id: UUID = UUID(), engine: String = "classic-dos") -> MobileCheckpointEnvelope {
        .init(runID: id, engine: engine, engineFingerprint: "engine", levelIdentifier: "level", levelIndex: 0,
              levelFingerprint: "level-hash", tick: tick, selectedControl: 0,
              camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data("saved".utf8),
              savedAt: date, scope: scope, owner: owner)
    }

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func selectedHotSeatNeverFallsBackToSoloOrAnotherHotSeat(engine: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-seat-resume-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MobileCheckpointStore(url: root.appendingPathComponent("current.json"))
        let now = Date()
        let shared = envelope(owner: "guest", scope: "hotseat.selected", date: now, engine: engine)
        let solo = envelope(owner: "host", date: now.addingTimeInterval(1), engine: engine)
        try await store.save(solo)
        #expect(try await store.load(owner: "host", scope: "hotseat.selected") == nil)
        try await store.save(shared)
        try await store.save(solo)
        #expect(try await store.load(owner: "host", scope: "hotseat.selected") == shared)
        #expect(try await store.load(owner: "host", scope: "hotseat.other") == nil)
        #expect(try await store.load(owner: "host", scope: nil) == solo)
        try await store.retire(runID: shared.runID)
        #expect(try await store.load(owner: "host", scope: "hotseat.selected") == nil)
        #expect(try await store.load() == solo)
    }

    @Test func matchingLegacyGlobalSaveStillResumesInItsOwnSession() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-legacy-resume-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MobileCheckpointStore(url: root.appendingPathComponent("current.json"))
        for saved in [envelope(owner: nil), envelope(owner: "guest", scope: "hotseat.selected")] {
            try await store.save(saved)
            for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                where file.lastPathComponent.hasPrefix("scoped-") { try FileManager.default.removeItem(at: file) }
            #expect(try await store.load(owner: "default", scope: saved.scope) == saved)
            #expect(try await store.load(owner: "default", scope: "hotseat.other") == nil)
            if saved.scope == nil { #expect(try await store.load(owner: "other", scope: nil) == nil) }
        }
    }

    @Test func differentPlayersAndHotSeatsKeepTheirCheckpoints() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-owners-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json")
        let store = MobileCheckpointStore(url: url)
        let now = Date()
        let legacy = envelope(owner: nil, date: now)
        let other = envelope(owner: "other", tick: 20, date: now.addingTimeInterval(1))
        let shared = envelope(owner: "other", scope: "hotseat.team", tick: 30, date: now.addingTimeInterval(2))
        try await store.save(legacy)
        try await store.save(other)
        try await store.save(shared)
        let reopened = MobileCheckpointStore(url: url)
        #expect(try await reopened.hasSavedSoloRun(owner: MobileProfiles.defaultID))
        #expect(try await reopened.hasSavedSoloRun(owner: "other"))
        #expect(try await reopened.hasSavedSoloRun(owner: "unknown") == false)
        #expect(try await reopened.load(owner: MobileProfiles.defaultID, scope: nil)?.runID == legacy.runID)
        #expect(try await reopened.load(owner: "other", scope: nil)?.runID == other.runID)
        #expect(try await reopened.load(owner: "default", scope: "hotseat.team")?.runID == shared.runID)
        #expect(try await reopened.load(owner: "unknown", scope: nil) == nil)
        try await reopened.retire(runID: other.runID)
        #expect(try await reopened.hasSavedSoloRun(owner: "other") == false)
        try await reopened.save(envelope(owner: "other", tick: 40, date: now.addingTimeInterval(3), id: other.runID))
        #expect(try await reopened.load(owner: "other", scope: nil) == nil)
        #expect(try await reopened.load(owner: MobileProfiles.defaultID, scope: nil)?.runID == legacy.runID)
    }

    @Test func newerCheckpointVersionCannotBeOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-future-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json")
        let store = MobileCheckpointStore(url: url)
        try await store.save(envelope(owner: "default"))
        var document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        document["version"] = 2
        let future = try JSONSerialization.data(withJSONObject: document)
        try future.write(to: url, options: .atomic)
        var rejected = false
        do { try await store.save(envelope(owner: "other", date: Date().addingTimeInterval(1))) }
        catch MobileCheckpointError.version { rejected = true }
        #expect(rejected)
        #expect(try Data(contentsOf: url) == future)
    }

    @Test(arguments: ["classic-dos", "lemmings2", "lemmings3"])
    func deletingPlayerRemovesOlderSoloBackupsWithoutTouchingOtherSessions(engine: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-delete-player-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json")
        let store = MobileCheckpointStore(url: url)
        let now = Date()
        let older = envelope(owner: "guest", date: now, engine: engine)
        let newest = envelope(owner: "guest", date: now.addingTimeInterval(1), engine: engine)
        let other = envelope(owner: "host", date: now.addingTimeInterval(2), engine: engine)
        let shared = envelope(owner: "guest", scope: "hotseat.team", date: now.addingTimeInterval(3), engine: engine)
        for saved in [older, newest, other, shared] { try await store.save(saved) }
        try await store.removeSoloRuns(owner: "guest")
        let reopened = MobileCheckpointStore(url: url)
        #expect(try await reopened.load(owner: "guest", scope: nil) == nil)
        #expect(try await reopened.load(owner: "host", scope: nil) == other)
        #expect(try await reopened.load(owner: "host", scope: "hotseat.team") == shared)
        #expect(try await reopened.load() == shared)
        // Neither the current nor older deleted run can return through a late save.
        for saved in [older, newest] { try await store.save(saved) }
        #expect(try await reopened.load(owner: "guest", scope: nil) == nil)
    }

    @Test func deletingDefaultPlayerRemovesOwnerlessLegacySaveAndGlobalBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-delete-default-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("current.json")
        let store = MobileCheckpointStore(url: url)
        try await store.save(envelope(owner: nil))
        try await store.removeSoloRuns(owner: "default")
        #expect(try await store.load() == nil)
        #expect(try await store.load(owner: "default", scope: nil) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
