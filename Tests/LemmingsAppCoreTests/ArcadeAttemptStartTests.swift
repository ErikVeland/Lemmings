import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct ArcadeAttemptStartTests {
    @Test(arguments: ["lemmings2-mobile-runtime-v1", "lemmings3-mobile-runtime-v1", "neolemmix"])
    func enginesWithoutRankingConditionsCanStartAndRetry(rules: String) throws {
        let storage = try AppStorage.temporary(named: "attempt-start")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let owner = store.records.activeProfileID
        let level = ArcadeLevel(id: "level", title: "Level", game: rules, rules: rules, total: 60, required: 30)
        let original = store.records
        let attempt = UUID()
        #expect(store.beginAttempt(id: attempt, profileID: owner, level: level, previousID: nil))
        #expect(store.beginAttempt(id: UUID(), profileID: owner, level: level, previousID: attempt))
        #expect(store.records == original)
        #expect(store.storageError == nil)
        let run = ArcadeRun(id: attempt, profileID: owner, level: level, saved: 60, didWin: true,
                            skills: [:], seconds: 10)
        #expect(store.record(run) != nil)
        let reopened = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(reopened.records.runs.contains { $0.id == attempt })
    }

    @Test func classicStartsStillPersistAndLinkRestarts() throws {
        let storage = try AppStorage.temporary(named: "classic-attempt-start")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let owner = store.records.activeProfileID
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "lemmings-LEVEL-120", levelID: "level-0",
            levelFingerprint: String(repeating: "a", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let level = ArcadeLevel(id: "lemmings:level-0", title: "Level", game: "Lemmings", rules: "classic-dos-v1",
                                total: 10, required: 5, conditions: conditions)
        let first = UUID(), retry = UUID()
        #expect(store.beginAttempt(id: first, profileID: owner, level: level, previousID: nil))
        #expect(store.beginAttempt(id: retry, profileID: owner, level: level, previousID: first))
        let reopened = ArcadeStore(storage: storage, bundledProofs: nil)
        let start = try #require(reopened.records.trolley.starts.first { $0.id == retry })
        #expect(start.kind == .restartDuringPlay && start.parentAttemptID == first)
        #expect(start.conditions == conditions && start.profileID == owner)
    }

    @Test func unreadableRecordsStillBlockStartsWithoutRankingConditions() throws {
        let storage = try AppStorage.temporary(named: "blocked-attempt-start")
        defer { storage.removeTemporaryFiles() }
        let file = ArcadeStore.recordsFile(storage: storage)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("broken records".utf8).write(to: file)
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let level = ArcadeLevel(id: "level", title: "Level", game: "Lemmings 2", rules: "l2", total: 60, required: 30)
        #expect(!store.beginAttempt(id: UUID(), profileID: store.records.activeProfileID, level: level, previousID: nil))
        #expect(store.storageError != nil)
        #expect(try Data(contentsOf: file) == Data("broken records".utf8))
    }
}
