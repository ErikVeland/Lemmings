import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

@MainActor struct ProfileIdentityTests {
    @Test func testSameInitialsKeepSeparateRecords() throws {
        let storage = try AppStorage.temporary(named: "profile-identity")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(store.importProfiles([.init(id: "default", initials: "AB"), .init(id: "second", initials: "AB")], activeID: "default"))
        let level = ArcadeLevel(id: "level", title: "Test", game: "Classic", rules: "DOS", total: 10, required: 5)
        let first = ArcadeRun(profileID: "default", level: level, saved: 10, didWin: true, skills: [:], seconds: 15)
        let second = ArcadeRun(profileID: "second", level: level, saved: 3, didWin: false, skills: ["build": 1], seconds: 25)
        #expect(store.record(first)?.newRescueBest == true)
        #expect(store.record(second)?.run.profileID == "second")
        #expect(store.records.stats(level: level, profileID: "default", assisted: false).clears == 1)
        #expect(store.records.stats(level: level, profileID: "second", assisted: false).clears == 0)
        #expect(store.records.careerAchievements(profileID: "default").contains(.allHome))
        #expect(store.records.careerAchievements(profileID: "second").isEmpty)
        #expect(store.record(first) == nil)
        let repeated = ArcadeRun(profileID: "default", level: level, saved: 10, didWin: true, skills: [:], seconds: 15)
        let report = try #require(store.record(repeated))
        #expect(!report.newRescueBest && !report.newSkillBest && report.earned.isEmpty)
        let restored = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(restored.records.profiles.map(\.id) == ["default", "second"])
        #expect(restored.records.careerAchievements(profileID: "second").isEmpty)
    }

    @Test func failedRecordsSaveDoesNotAdvanceOwnerOrCredit() throws {
        let storage = try AppStorage.temporary(named: "record-failure")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("records.json")
        let store = ArcadeStore(storage: storage, file: file, bundledProofs: nil)
        let owner = store.records.activeProfileID
        let before = store.records
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let run = ArcadeRun(profileID: owner,
            level: .init(id: "l", title: "Level", game: "Classic", rules: "DOS", total: 10, required: 5),
            saved: 10, didWin: true, skills: [:], seconds: 10)
        #expect(store.record(run) == nil)
        #expect(store.storageError != nil)
        #expect(store.records == before)
        #expect(store.playingProfileID == owner)
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "pack", levelID: "level-0",
            levelFingerprint: String(repeating: "c", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let started = store.beginAttempt(id: UUID(), profileID: owner,
            level: .init(id: "l", title: "Level", game: "Classic", rules: "DOS", total: 10, required: 5, conditions: conditions), previousID: nil)
        #expect(!started)
        #expect(store.records == before)
    }
}
