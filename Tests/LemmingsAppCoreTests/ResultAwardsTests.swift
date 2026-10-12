import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

struct ResultAwardsTests {
    @Test func sharedAwardsUseSavedResultsAndPersonalImprovements() throws {
        var records = ArcadeRecords()
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "pack", levelID: "level-0",
            levelFingerprint: String(repeating: "b", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 5], timeLimitSeconds: 300)
        let level = ArcadeLevel(id: "level-0", title: "Test", game: "Classic", rules: "classic-dos-v1",
                                total: 10, required: 5, conditions: conditions)
        let owner = records.activeProfileID
        func run(_ saved: Int, _ seconds: Double, won: Bool = true) -> ArcadeRun {
            .init(profileID: owner, level: level, saved: saved, didWin: won,
                  skills: ["digger": 1], seconds: seconds, telemetry: .init(released: 10))
        }
        let first = records.record(run(5, 20))
        let firstReport = try #require(first)
        let firstAwards = TrolleyCelebration(report: firstReport, history: records.trolley)
        #expect(firstAwards.goals.stars == 1)
        #expect(!ResultAwards.ornament(report: firstReport, celebration: firstAwards, history: records.trolley))
        let improved = records.record(run(6, 20))
        let improvedReport = try #require(improved)
        let improvedAwards = TrolleyCelebration(report: improvedReport, history: records.trolley)
        #expect(improvedAwards.goals.stars == 2)
        #expect(ResultAwards.ornament(report: improvedReport, celebration: improvedAwards, history: records.trolley))
        let repeated = records.record(run(6, 20))
        let repeatedReport = try #require(repeated)
        #expect(!ResultAwards.ornament(report: repeatedReport,
            celebration: .init(report: repeatedReport, history: records.trolley), history: records.trolley))
        let quicker = records.record(run(6, 15))
        let quickerReport = try #require(quicker)
        #expect(ResultAwards.ornament(report: quickerReport,
            celebration: .init(report: quickerReport, history: records.trolley), history: records.trolley))
        let failed = records.record(run(4, 10, won: false))
        let failedReport = try #require(failed)
        let failedAwards = TrolleyCelebration(report: failedReport, history: records.trolley)
        #expect(failedAwards.goals.stars == 0)
        #expect(!ResultAwards.ornament(report: failedReport, celebration: failedAwards, history: records.trolley))
    }
}
