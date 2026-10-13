import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobilePauseSummaryTests {
    func summary(saved: Int = 12, active: Int = 18, released: Int = 40, required: Int = 60,
                 complete: Bool = false, won: Bool = false, ending: Bool = false,
                 time: Int? = 97, replay: Bool = false) -> MobilePauseSummary {
        .init(level: .init(index: 26, rank: "Fun", number: 27, title: "Let's be careful out there"),
            snapshot: .init(tick: 510, released: released, total: 80, saved: saved, required: required,
                remainingSeconds: time, releaseRate: 50, isComplete: complete, didWin: won,
                isEndingRun: ending, skills: [.init(name: "Builder", count: 6)]),
            activeCount: active, ticksPerSecond: 17, speed: 2, assignedSkills: 4,
            supportsRewind: true, usedRewind: false, isReplay: replay,
            soundtrack: "Original", track: "Lemming 1", audio: "Music paused")
    }

    @Test func lossMarginSubtractsActualLossesAndIncludesUnreleasedLemmings() {
        let value = summary()
        #expect(value.lost == 10 && value.waiting == 40 && value.active == 18)
        #expect(value.canLose == 10 && value.goalReachable)
        #expect(value.fields.first { $0.label == "Elapsed" }?.value == "0:30")
        #expect(value.fields.first { $0.label == "Time left" }?.value == "1:37")
        #expect(value.supplies == [.init("Builder", "6")])
    }
    @Test func zeroMarginDiffersFromAnImpossibleGoal() {
        let exact = summary(active: 8)
        #expect(exact.canLose == 0 && exact.goalReachable)
        #expect(exact.status == "Rescue in progress")
        let failed = summary(active: 7)
        #expect(failed.canLose == 0 && !failed.goalReachable)
        #expect(failed.status == "Rescue target out of reach")
    }
    @Test func securedGoalAndRunEndingHaveDistinctStates() {
        let secured = summary(saved: 60, active: 5, released: 70)
        #expect(secured.status == "Rescue target reached" && secured.canLose == 15)
        #expect(summary(ending: true).status == "Ending the run")
        #expect(summary(complete: true, won: true).status == "Level complete")
        #expect(summary(complete: true).status == "Level ended")
    }
    @Test func replayAndUnlimitedTimeKeepTheirOwnLabels() {
        let replay = summary(time: nil, replay: true)
        #expect(replay.status == "Replay paused")
        #expect(replay.fields.first { $0.label == "Time left" }?.value == "Unlimited")
        #expect(replay.playDetails.hasSuffix("Replay"))
    }
}
