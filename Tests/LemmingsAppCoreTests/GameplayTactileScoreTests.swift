import XCTest
import NxlvKit
@testable import LemmingsAppCore

final class GameplayTactileScoreTests: XCTestCase {
    func testNukeBuildsOnceThenFirstBlastTakesPriority() {
        var score = GameplayTactileScore()
        XCTAssertEqual(score.update(nuking: true, cues: [.builderWarning], at: 0), .nukeArm)
        XCTAssertNil(score.update(nuking: true, cues: [.builderWarning], at: 0.3))
        XCTAssertEqual(score.update(nuking: true, cues: [.explode, .pop, .builderWarning], at: 4), .nukeImpact)
        XCTAssertNil(score.update(nuking: true, cues: [.explode], at: 4.1))
        XCTAssertEqual(score.update(nuking: true, cues: [.pop], at: 4.5), .nukeEcho)
        XCTAssertEqual(score.update(nuking: false, cues: [.builderWarning], at: 5), .bridgeWarning)
    }

    func testBuilderClinksRemainRecognisableWithoutStacking() {
        var score = GameplayTactileScore()
        XCTAssertNil(score.update(nuking: false, cues: [.brickPlace, .assignSkill], at: 0))
        XCTAssertEqual(score.update(nuking: false, cues: [.builderWarning, .builderWarning], at: 0.02), .bridgeWarning)
        XCTAssertNil(score.update(nuking: false, cues: [.builderWarning], at: 0.12))
        XCTAssertEqual(score.update(nuking: false, cues: [.builderWarning], at: 0.30), .bridgeWarning)
        XCTAssertEqual(score.update(nuking: false, cues: [.builderWarning, .explode], at: 1), .bomber)
    }

    func testFinalFuseFollowsActualCountdownOnce() {
        var score = GameplayTactileScore()
        XCTAssertEqual(score.update(nuking: true, cues: [], at: 0, secondsToBlast: 5), .nukeArm)
        XCTAssertNil(score.update(nuking: true, cues: [], at: 2, secondsToBlast: 0.89))
        XCTAssertEqual(score.update(nuking: true, cues: [], at: 2.2, secondsToBlast: 0.82), .nukeFuse)
        XCTAssertNil(score.update(nuking: true, cues: [], at: 2.4, secondsToBlast: 0.41))
        XCTAssertEqual(score.update(nuking: true, cues: [.explode], at: 2.6, secondsToBlast: 0), .nukeImpact)
    }

    func testRewindAndRestoreDoNotReplayArming() {
        var score = GameplayTactileScore()
        XCTAssertEqual(score.update(nuking: true, cues: [], at: 0), .nukeArm)
        score.rebase(nuking: true)
        XCTAssertNil(score.update(nuking: true, cues: [], at: 1))
        XCTAssertEqual(score.update(nuking: true, cues: [.explode], at: 2), .nukeImpact)
        score.rebase(nuking: false)
        XCTAssertEqual(score.update(nuking: true, cues: [], at: 3), .nukeArm)
    }

    func testPatternsSeparatePrecisionFromWeight() {
        XCTAssertGreaterThan(GameplayTactileCue.bridgeWarning.pulses.first!.sharpness,
                             GameplayTactileCue.nukeImpact.pulses.first!.sharpness)
        XCTAssertGreaterThan(GameplayTactileCue.nukeImpact.pulses.first!.intensity,
                             GameplayTactileCue.bomber.pulses.first!.intensity)
        XCTAssertEqual(GameplayTactileCue.nukeArm.pulses.count, 3)
    }
}
