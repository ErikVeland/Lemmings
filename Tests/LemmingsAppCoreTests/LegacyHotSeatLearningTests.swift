import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

@MainActor struct LegacyHotSeatLearningTests {
    private func fixture(engine: LevelSourceEngine, file: URL) throws -> (LevelSequenceRun, LearningJourneyProgress, [LevelPlaylistEntry]) {
        let entries = try (0..<4).map { index in
            try LevelPlaylistEntry(identity: .init(engine: engine, packID: "legacy-test", levelID: "\(index)"),
                catalogueRevision: "test", sourceRevision: "test", packNameSnapshot: "Legacy",
                levelNameSnapshot: "Level \(index)", levelNumberSnapshot: index + 1)
        }
        let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: "Legacy", entries: entries)
        let run = try LevelSequenceRun(source: .playlist(playlist.id), pool: .init(id: "learning-999", summary: "Legacy"),
            entries: entries, currentIndex: 2)
        var progress = LearningJourneyProgress()
        progress.record(entries[0].identity, won: true)
        progress.record(entries[1].identity, won: false)
        progress.record(entries[3].identity, won: true) // An unrelated solo win beyond the saved frontier.
        let store = try LevelPlaylistStore(file: file)
        try store.add(playlist); try store.startRun(run, hotSeatID: "old-seat")
        try store.mergeLearningProgress(progress)
        var raw = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        raw.removeValue(forKey: "recoveredLegacyHotSeatLearning")
        raw.removeValue(forKey: "hotSeatLearningProgress")
        raw.removeValue(forKey: "journeySessions")
        try JSONSerialization.data(withJSONObject: raw).write(to: file)
        return (run, progress, entries)
    }

    @Test func legacyVisitsRecoverRecordedOutcomesWithoutInventingWins() throws {
        for engine: LevelSourceEngine in [.classic, .lemmings2, .lemmings3] {
            let storage = try AppStorage.temporary(named: "legacy-\(engine)")
            defer { storage.removeTemporaryFiles() }
            let file = storage.applicationSupport.appendingPathComponent("legacy.json")
            let (run, original, entries) = try fixture(engine: engine, file: file)
            let store = try LevelPlaylistStore(file: file)
            #expect(store.learningProgress(hotSeatID: "old-seat").completed == [entries[0].identity])
            #expect(store.learningProgress(hotSeatID: "old-seat").later == [entries[1].identity])
            #expect(store.learningProgress(hotSeatID: "other-seat").completed.isEmpty)
            #expect(store.learningProgress == original)
            #expect(store.activeRun == run && store.activeRunHotSeatID == "old-seat")
            #expect(store.completedLearningEntries(hotSeatID: "old-seat").map(\.identity) == [entries[0].identity])
            let once = try Data(contentsOf: file)
            _ = try LevelPlaylistStore(file: file)
            #expect(try Data(contentsOf: file) == once)
        }
    }

    @Test func emptyHistoryWrittenBy21RecoversFromItsMatchingLegacyBackup() throws {
        let storage = try AppStorage.temporary(named: "legacy-backup")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("legacy.json")
        let (run, _, entries) = try fixture(engine: .classic, file: file)
        let legacy = try Data(contentsOf: file)
        var raw = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        raw["hotSeatLearningProgress"] = ["old-seat": ["completed": [], "later": []]]
        raw["journeySessions"] = [:]
        try JSONSerialization.data(withJSONObject: raw).write(to: file)
        try legacy.write(to: file.appendingPathExtension("backup"))
        let store = try LevelPlaylistStore(file: file)
        #expect(store.learningProgress(hotSeatID: "old-seat").completed == [entries[0].identity])
        #expect(store.activeRun == run)
    }

    @Test func newSessionsDoNotInheritLegacyOrSoloOutcomes() throws {
        let storage = try AppStorage.temporary(named: "new-seat")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("legacy.json")
        let (run, original, _) = try fixture(engine: .classic, file: file)
        let old = try Data(contentsOf: file)
        var raw = try #require(JSONSerialization.jsonObject(with: old) as? [String: Any])
        raw["activeRunHotSeatID"] = "new-seat"
        raw["hotSeatLearningProgress"] = ["new-seat": ["completed": [], "later": []]]
        raw["journeySessions"] = [:]
        try JSONSerialization.data(withJSONObject: raw).write(to: file)
        try old.write(to: file.appendingPathExtension("backup"))
        let store = try LevelPlaylistStore(file: file)
        #expect(store.learningProgress(hotSeatID: "new-seat").completed.isEmpty)
        #expect(store.learningProgress(hotSeatID: "old-seat").completed.isEmpty)
        #expect(store.learningProgress == original && store.activeRun == run)
    }
}
