import Foundation
import Testing
@testable import NxlvKit

struct ExtraSkillRewardTests {
    private func conditions(_ number: Int, game: String = "lemmings", stock: [String: Int] = ["digger": 1]) -> TrolleyConditions {
        .init(gameID: game, packID: "bonus-tests", levelID: String(number), levelFingerprint: "fixture",
            rulesetVersion: "fixture", physicsMode: "fixture", population: 3, rescueRequirement: 1,
            startingSkills: stock, timeLimitSeconds: 60)
    }

    private func run(_ conditions: TrolleyConditions, id: UUID = UUID(), rewound: Bool = false,
        skills: [String: Int] = [:]) -> ArcadeRun {
        .init(id: id, profileID: ArcadeProfile.legacyID,
            level: .init(id: conditions.levelID, title: "Fixture", game: conditions.gameID, rules: "fixture",
                total: 3, required: 1, conditions: conditions), saved: 3, didWin: true, skills: skills,
            seconds: 10, assisted: rewound, telemetry: .init(released: 3, rewindCount: rewound ? 1 : 0))
    }

    private func earn(_ count: Int, records: inout ArcadeRecords) throws {
        for index in 0..<count {
            let report = records.record(run(conditions(index, game: ["lemmings", "lemmings2", "lemmings3"][index % 3])))
            let result = try #require(report)
            #expect(result.earnedExtraSkill == ((index + 1) % 10 == 0))
        }
    }

    @Test func tenDistinctUnassistedLevelsEarnOneSharedReward() throws {
        var records = ArcadeRecords()
        try earn(10, records: &records)
        let owner = records.activeProfileID
        #expect(records.extraSkills(profileID: owner).available == 1)
        #expect(records.extraSkills(profileID: owner).threeStarLevelsToNext == 10)
        for index in 0..<10 {
            let duplicate = records.record(run(conditions(index, game: ["lemmings", "lemmings2", "lemmings3"][index % 3])))
            let assisted = records.record(run(conditions(index + 100), rewound: true))
            #expect(duplicate?.earnedExtraSkill == false)
            #expect(assisted?.earnedExtraSkill == false)
        }
        #expect(records.extraSkills(profileID: owner).earned == 1)
        let added = records.addProfile(initials: "GST", portrait: 0)
        let guest = try #require(added)
        #expect(records.extraSkills(profileID: guest.id).available == 0)
    }

    @Test func bonusGrantIsAtomicAndDoesNotEnterNormalRecordsOrEarnRewards() throws {
        var records = ArcadeRecords()
        try earn(10, records: &records)
        let owner = records.activeProfileID, id = UUID(), original = conditions(100)
        let missing = records.spendExtraSkill(attemptID: id, profileID: owner, skill: "builder", conditions: original)
        #expect(!missing)
        #expect(records.extraSkills(profileID: owner).available == 1)
        // Practice attempts can receive a grant without an earlier start.
        let granted = records.spendExtraSkill(attemptID: id, profileID: owner, skill: "digger", conditions: original)
        let repeated = records.spendExtraSkill(attemptID: id, profileID: owner, skill: "digger", conditions: original)
        #expect(granted)
        #expect(!repeated)
        let bonus = try #require(records.extraSkillUse(attemptID: id, profileID: owner)?.conditions)
        #expect(bonus.startingSkills["digger"] == 2)
        #expect(records.trolley.starts.first { $0.id == id }?.conditions == bonus)
        #expect(bonus.fingerprint != original.fingerprint)
        let missingProvenance = records.record(run(original, id: id))
        #expect(missingProvenance == nil)
        let submitted = run(bonus, id: id, skills: ["digger": 2])
        let recorded = records.record(submitted)
        let report = try #require(recorded)
        let celebration = TrolleyCelebration(report: report, history: records.trolley)
        #expect(report.run.usedBonusSkill && report.run.qualifies)
        #expect(report.earned.isEmpty && report.trolley?.attempt.achievements.isEmpty == true)
        #expect(!report.earnedExtraSkill && !report.earnedLevelSkip)
        #expect(celebration.precisionRewards.superzoomUses == 0)
        #expect(celebration.career.threeStarLevels == 10)
        #expect(celebration.recordMessage == "BONUS SKILL USED")
        #expect(records.leaderboard(level: run(original).level, board: .rescue, assisted: false).isEmpty)
        #expect(records.trolley.maximum(conditions: original, assisted: false).status == .unknown)
        #expect(records.trolley.personal(profileID: owner).attempts == 10)
        #expect(records.extraSkills(profileID: owner).available == 0)
        _ = try records.validated()
    }

    @Test func onlyExistingFiniteSkillsAndOriginalL3ToolsCanReceiveOneUse() throws {
        let original = conditions(0, stock: ["digger": 1, "builder": 0, "climber": -1])
        #expect(original.addingBonusSkill("digger")?.startingSkills["digger"] == 2)
        #expect(original.addingBonusSkill("builder") == nil)
        #expect(original.addingBonusSkill("climber") == nil)
        #expect(original.addingBonusSkill("miner") == nil)
        #expect(original.addingBonusSkill("digger")?.addingBonusSkill("digger") == nil)
        let third = conditions(1, game: "lemmings3", stock: [:])
        #expect(third.addingBonusSkill("spade") == nil)
        #expect(third.addingBonusSkill("clock", existingLevelSkills: ["clock"]) == nil)
        let bonus = try #require(third.addingBonusSkill("spade", existingLevelSkills: ["spade"]))
        #expect(bonus.startingSkills.isEmpty && bonus.bonusSkillID == "spade")
        #expect(bonus.isBonusUpgrade(of: third))
        #expect(!bonus.isBonusUpgrade(of: original))
    }

    @Test func spendSurvivesSaveAndCloudMergeWithoutDuplication() throws {
        var records = ArcadeRecords()
        try earn(10, records: &records)
        let id = UUID(), owner = records.activeProfileID, original = conditions(100)
        records.beginTrolleyAttempt(.init(id: id, profileID: owner, conditions: original))
        let beforeSpend = try records.cloudRecords(profileID: owner)
        let granted = records.spendExtraSkill(attemptID: id, profileID: owner, skill: "digger", conditions: original)
        #expect(granted)
        let restored = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records))
        #expect(restored.extraSkillSpent(attemptID: id, profileID: owner) == "digger")
        let cloud = try restored.cloudRecords(profileID: owner)
        var device = ArcadeRecords()
        try device.mergeCloudRecords(beforeSpend, profileID: owner)
        try device.mergeCloudRecords(cloud, profileID: owner)
        try device.mergeCloudRecords(cloud, profileID: owner)
        try device.mergeCloudRecords(beforeSpend, profileID: owner)
        #expect(device.extraSkills(profileID: owner).spent == 1)
        #expect(device.extraSkills(profileID: owner).available == 0)
        #expect(device.trolley.starts.first { $0.id == id }?.conditions.bonusSkillID == "digger")
        _ = try device.validated()
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ArcadeRecords())) as? [String: Any])
        legacy.removeValue(forKey: "extraSkillUses")
        let migrated = try JSONDecoder().decode(ArcadeRecords.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(migrated.extraSkillUses.isEmpty)
    }

    @Test func offlineSpendsMergeWithoutReturningEitherCharge() throws {
        var first = ArcadeRecords()
        try earn(10, records: &first)
        var second = first
        let owner = first.activeProfileID
        let firstGranted = first.spendExtraSkill(attemptID: UUID(), profileID: owner, skill: "digger", conditions: conditions(100))
        let secondGranted = second.spendExtraSkill(attemptID: UUID(), profileID: owner, skill: "digger", conditions: conditions(101))
        #expect(firstGranted)
        #expect(secondGranted)
        try first.mergeCloudRecords(second.cloudRecords(profileID: owner), profileID: owner)
        #expect(first.extraSkills(profileID: owner).spent == 2)
        #expect(first.extraSkills(profileID: owner).available == 0)
        for index in 10..<20 { _ = first.record(run(conditions(index))) }
        #expect(first.extraSkills(profileID: owner).earned == 2)
        #expect(first.extraSkills(profileID: owner).available == 0)
    }

    @Test func checkpointRecoveryKeepsItsChargeBeforeCloudRecordsArrive() throws {
        var source = ArcadeRecords()
        try earn(10, records: &source)
        let owner = source.activeProfileID, id = UUID(), original = conditions(100)
        source.beginTrolleyAttempt(.init(id: id, profileID: owner, conditions: original,
            date: Date(timeIntervalSince1970: 1234), parentAttemptID: source.trolley.attempts.last?.id,
            kind: .retryAfterSuccess))
        let spent = source.spendExtraSkill(attemptID: id, profileID: owner, skill: "digger", conditions: original)
        #expect(spent)
        let use = try #require(source.extraSkillUse(attemptID: id, profileID: owner))
        var destination = ArcadeRecords()
        let recovered = destination.recoverExtraSkillUse(use, profileID: owner)
        let repeated = destination.recoverExtraSkillUse(use, profileID: owner)
        #expect(recovered && repeated)
        #expect(destination.extraSkills(profileID: owner).earned == 0)
        #expect(destination.extraSkills(profileID: owner).spent == 1)
        #expect(destination.extraSkills(profileID: owner).available == 0)
        #expect(destination.trolley.starts.first { $0.id == id } == source.trolley.starts.first { $0.id == id })
        let conflict = ExtraSkillUse(attemptID: id, skill: "digger", originalConditions: conditions(101))
        let changed = destination.recoverExtraSkillUse(conflict, profileID: owner)
        let secondGrant = destination.spendExtraSkill(attemptID: id, profileID: owner, skill: "digger", conditions: original)
        #expect(!changed && !secondGrant)
        try destination.mergeCloudRecords(source.cloudRecords(profileID: owner), profileID: owner)
        #expect(destination.extraSkills(profileID: owner).earned == 1)
        #expect(destination.extraSkills(profileID: owner).spent == 1)
        #expect(destination.extraSkills(profileID: owner).available == 0)
        _ = try destination.validated()
    }
}
