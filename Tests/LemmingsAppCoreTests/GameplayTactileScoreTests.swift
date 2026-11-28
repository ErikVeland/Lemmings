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
    func testHardLandingThudsButAnUnseenLossDoesNot() {
        var score = GameplayTactileScore()
        XCTAssertNil(score.update(nuking: false, cues: [.fallOut, .drown], at: 0))
        XCTAssertEqual(score.update(nuking: false, cues: [.splat], at: 0.1), .fallLanding)
        XCTAssertNil(score.update(nuking: false, cues: [.splat], at: 0.4))
        XCTAssertEqual(score.update(nuking: false, cues: [.splat], at: 0.6), .fallLanding)
    }

    func testPositionalMixSteersBothHandlesAndAttenuatesOffscreen() {
        let camera = GameplaySoundViewport(x: 100, y: 50, width: 200, height: 100)
        let left = GameplayTactileMix.at(.init(x: 110, y: 100), in: camera)
        let right = GameplayTactileMix.at(.init(x: 290, y: 100), in: camera)
        let offscreen = GameplayTactileMix.at(.init(x: 320, y: 100), in: camera)
        XCTAssertGreaterThan(left.left, 3 * left.right)
        XCTAssertGreaterThan(right.right, 3 * right.left)
        XCTAssertLessThan(offscreen.gain, right.gain)
        XCTAssertEqual(GameplayTactileMix.centered.left, GameplayTactileMix.centered.right)
        XCTAssertEqual(left.deviceGain(controllerPlayback: []), 1)
        XCTAssertGreaterThan(left.deviceGain(controllerPlayback: [.accepted]), 0)
        XCTAssertLessThan(left.deviceGain(controllerPlayback: [.accepted]), left.deviceGain(controllerPlayback: []))
    }

    func testPickTheVisibleImpactRatherThanTheFirstOffscreenOne() throws {
        let camera = GameplaySoundViewport(x: 0, y: 0, width: 100, height: 100)
        let visible = PositionedSoundCue(.splat, at: .init(x: 80, y: 50))
        let distant = PositionedSoundCue(.splat, at: .init(x: -180, y: 50))
        let genericDeath = PositionedSoundCue(.splat, at: .init(x: 20, y: 50), isFatalLanding: false)
        XCTAssertNil(GameplayTactileMix.select(for: .fallLanding, from: [distant, genericDeath], viewport: camera))
        let chosen = try XCTUnwrap(GameplayTactileMix.select(for: .fallLanding, from: [distant, genericDeath, visible], viewport: camera))
        XCTAssertGreaterThan(chosen.right, chosen.left)
        XCTAssertEqual(GameplayTactileMix.select(for: .nukeArm, from: [visible], viewport: camera), .centered)
        XCTAssertNotNil(GameplayTactileMix.select(for: .nukeImpact, from: [.init(.explode, at: distant.point)], viewport: camera))
    }

    func testPhoneStaysFullStrengthUntilAControllerActuatorAcceptsPlayback() {
        let mix = GameplayTactileMix.centered
        for outcomes: [GameplayTactilePlayback] in [[], [.unavailable], [.queued], [.queued, .unavailable]] {
            XCTAssertEqual(mix.deviceGain(controllerPlayback: outcomes), 1)
        }
        XCTAssertLessThan(mix.deviceGain(controllerPlayback: [.queued, .accepted]), 1)
    }

}
