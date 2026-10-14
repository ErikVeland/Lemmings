import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileCheckpointOwnershipTests {
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
}
