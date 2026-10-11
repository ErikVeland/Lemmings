import Foundation
import Testing
@testable import NxlvKit

struct PrecisionRewardTests {
    private func run(_ engine: String, level: String = "1", saved: Int = 3,
                     owner: String = ArcadeProfile.legacyID, rewound: Bool = false,
                     won: Bool = true) -> ArcadeRun {
        let conditions = TrolleyConditions(gameID: engine, packID: "reward-test", levelID: level,
            levelFingerprint: "fixture", rulesetVersion: "fixture", physicsMode: "fixture",
            population: 3, rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: 60)
        let level = ArcadeLevel(id: engine + level, title: "Reward fixture", game: engine, rules: "fixture",
            total: 3, required: 1, conditions: conditions)
        return .init(profileID: owner, level: level, saved: saved, didWin: won, skills: [:], seconds: 10, assisted: rewound,
            telemetry: .init(released: 3, rewindCount: rewound ? 1 : 0))
    }

    private func record(_ run: ArcadeRun, in records: inout ArcadeRecords) throws -> ArcadeReport {
        let report = records.record(run)
        return try #require(report)
    }

    @Test func distinctThreeStarLevelsEarnZoomAndSuperzoomAcrossEngines() throws {
        var records = ArcadeRecords()
        for (index, engine) in ["lemmings", "lemmings2", "lemmings3"].enumerated() {
            let report = try record(run(engine), in: &records)
            let celebration = TrolleyCelebration(report: report, history: records.trolley)
            #expect(celebration.precisionRewards.zoomUses == 1)
            #expect(celebration.precisionRewards.superzoomUses == (index == 2 ? 1 : 0))
            let duplicate = try record(run(engine), in: &records)
            let repeated = TrolleyCelebration(report: duplicate, history: records.trolley)
            #expect(repeated.precisionRewards == .init(zoomUses: 0, superzoomUses: 0))
        }
        let score = TrolleyCareerScore(profileID: ArcadeProfile.legacyID, attempts: records.trolley.attempts, assisted: false)
        #expect(PrecisionZoomEarnings(careerStars: score.stars, threeStarLevels: score.threeStarLevels)
            == .init(zoomUses: 3, superzoomUses: 1))
    }

    @Test func improvementsEarnOnlyTheNewCreditAndRewindsDoNotEarnUses() throws {
        var records = ArcadeRecords()
        _ = records.record(run("lemmings", saved: 1))
        let improved = try record(run("lemmings"), in: &records)
        #expect(TrolleyCelebration(report: improved, history: records.trolley).precisionRewards
            == .init(zoomUses: 1, superzoomUses: 0))
        for attempt in [run("lemmings2", rewound: true), run("lemmings3", won: false)] {
            let report = try record(attempt, in: &records)
            #expect(TrolleyCelebration(report: report, history: records.trolley).precisionRewards
                == .init(zoomUses: 0, superzoomUses: 0))
        }
        let createdGuest = records.addProfile(initials: "GST", portrait: 0, select: false)
        let guest = try #require(createdGuest)
        let own = try record(run("lemmings3", owner: guest.id), in: &records)
        #expect(TrolleyCelebration(report: own, history: records.trolley).precisionRewards
            == .init(zoomUses: 1, superzoomUses: 0))
        let restored = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records))
        let score = TrolleyCareerScore(profileID: ArcadeProfile.legacyID, attempts: restored.trolley.attempts, assisted: false)
        #expect(score.stars == 3 && score.threeStarLevels == 1)
    }
}
