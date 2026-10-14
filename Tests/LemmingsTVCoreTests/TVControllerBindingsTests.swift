import Foundation
import NxlvKit
import LemmingsMobileCore
import Testing
@testable import LemmingsTVCore

struct TVControllerBindingsTests {
    @Test func shuffleChordFiresOnceWithoutMovingTheCameraOrBypassingNeutral() {
        var input = TVControllerBindings()
        #expect(input.update(pressed: [.options, .leftStick]).isEmpty)
        #expect(!input.shuffleRequested)
        _ = input.update(pressed: [])
        #expect(input.update(pressed: [.options, .leftStick]).isEmpty)
        #expect(input.shuffleRequested)
        #expect(input.update(pressed: [.options, .leftStick]).isEmpty)
        #expect(!input.shuffleRequested)
        #expect(input.update(pressed: []).isEmpty)
    }
    @Test func televisionStickAndTriggerPreferencesStayWithTheirPlayer() {
        let suite = "TVPlayerInput.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var legacy = TVPreferences(); legacy.aimSensitivity = 1.5
        legacy.saveInputPreferences(to: defaults)
        var first = TVPreferences.inputPreferences(from: defaults, profileID: "first")
        first.deadZone = 0.3; first.triggerFeedback = false
        first.saveInputPreferences(to: defaults, profileID: "first")
        let second = TVPreferences.inputPreferences(from: defaults, profileID: "second")
        #expect(second.aimSensitivity == 1.5 && second.deadZone == 0.15 && second.triggerFeedback != false)
        #expect(TVPreferences.inputPreferences(from: defaults, profileID: "first") == first)
    }
    @Test func triggersControlTheTimelineWithoutAChord() {
        var input = TVControllerBindings()
        _ = input.update(pressed: [])
        #expect(input.update(pressed: [.leftTrigger]).isEmpty)
        #expect(input.rewindHeld)
        #expect(input.update(pressed: [.leftTrigger, .a]) == [.assign])
        #expect(input.update(pressed: []).isEmpty)
        #expect(!input.rewindHeld)
        #expect(input.update(pressed: [.rightTrigger]) == [.boost(true)])
        #expect(input.update(pressed: []) == [.boost(false)])
    }
    @Test func heldHandoverInputsCannotStartRewindOrHelp() {
        var input = TVControllerBindings()
        #expect(input.update(pressed: [.leftTrigger, .options, .a]).isEmpty)
        #expect(!input.rewindHeld)
        #expect(input.update(pressed: [.leftTrigger, .options, .a]).isEmpty)
        #expect(!input.rewindHeld)
        #expect(input.update(pressed: []).isEmpty)
        #expect(input.update(pressed: [.menu]).isEmpty && input.menuRequested)
        input.reset()
        #expect(input.update(pressed: [.menu]).isEmpty)
        #expect(!input.menuRequested)
        #expect(input.update(pressed: [.menu]).isEmpty)
    }
    @Test func forwardTakesOverHeldRewindAndRearmsOnFreshBackwardPress() {
        var input = TVControllerBindings()
        _ = input.update(pressed: [])
        _ = input.update(pressed: [.leftTrigger])
        #expect(input.rewindHeld)
        #expect(input.update(pressed: [.leftTrigger, .rightTrigger]) == [.boost(true)])
        #expect(!input.rewindHeld)
        #expect(input.update(pressed: [.leftTrigger, .rightTrigger]).isEmpty)
        #expect(!input.rewindHeld)
        #expect(input.update(pressed: [.leftTrigger]) == [.boost(false)])
        #expect(!input.rewindHeld)
        _ = input.update(pressed: [])
        _ = input.update(pressed: [.leftTrigger])
        #expect(input.rewindHeld)
    }
    @Test func createTapAndExtraActionsRemainDistinct() {
        var input = TVControllerBindings(); _ = input.update(pressed: [])
        #expect(input.update(pressed: [.options]).isEmpty)
        #expect(input.update(pressed: []) == [.help])
        let chords: [(ControllerBindings.Button, ControllerBindings.Action)] = [
            (.a, .repeatAssignment), (.b, .focusLast), (.x, .speedReset), (.y, .hints), (.menu, .retry),
            (.leftShoulder, .step(-1)), (.rightShoulder, .step(1)),
            (.left, .speedStep(-1)), (.right, .speedStep(1)), (.up, .focusUnassigned(-1)),
            (.down, .focusUnassigned(1)), (.rightStick, .settings)]
        for (button, action) in chords {
            #expect(input.update(pressed: [.options, button]) == [action])
            #expect(input.update(pressed: [.options, button]).isEmpty)
            #expect(input.update(pressed: []).isEmpty)
        }
    }
    @Test func requestedFaceAndRateLayoutKeepsSelectBackAndSkills() {
        let actions: [(ControllerBindings.Button, ControllerBindings.Action)] = [
            (.a, .assign), (.b, .cancel), (.x, .pause), (.y, .endRun),
            (.left, .rate(-99)), (.right, .rate(99)), (.up, .rate(1)), (.down, .rate(-1)),
            (.leftShoulder, .cycle(-1)), (.rightShoulder, .cycle(1))]
        for (button, action) in actions {
            var input = TVControllerBindings(); _ = input.update(pressed: [])
            #expect(input.update(pressed: [button]) == [action])
            #expect(input.update(pressed: [button]).isEmpty)
        }
    }
    @Test func olderPreferencesRetainSensitivityAndEnableFeedback() throws {
        let legacy = Data("{\"planningOnSkillChange\":false,\"aimSensitivity\":1.5,\"deadZone\":0.2,\"textScale\":1,\"swapSticks\":false,\"musicEnabled\":true,\"effectsEnabled\":true,\"mappings\":{}}".utf8)
        let prefs = try JSONDecoder().decode(TVPreferences.self, from: legacy)
        #expect(prefs.aimSensitivity == 1.5 && prefs.deadZone == 0.2)
        #expect(prefs.triggerFeedback != false)
    }
    @Test func classicCursorCanSelectFreshActorsAfterAssignmentAndRewind() throws {
        var solid = Data(repeating: 0, count: 160 * 80)
        solid.replaceSubrange(50 * 160..<solid.count, with: Data(repeating: 1, count: 30 * 160))
        let terrain = try ClassicDOSTerrain(width: 160, height: 80, solidMask: solid, steelMask: Data(repeating: 0, count: solid.count))
        let config = ClassicDOSConfiguration(totalLemmings: 5, requiredToSave: 1, timeLimitTicks: 1_000,
            initialReleaseRate: 50, entrances: [.init(x: 20, y: 20)], initialSkills: [.climber: 5], maximumX: 159, maximumY: 79)
        let session = ClassicMobileSession(simulation: try ClassicDOSSimulation(terrain: terrain, configuration: config),
            levelIdentifier: "controller/fixture", levelIndex: 0)
        for _ in 0..<80 where !session.targetCandidates(for: 0).contains(where: { $0.assignment == .eligible }) { session.tick() }
        let first = try #require(session.targetCandidates(for: 0).first { $0.assignment == .eligible })
        var lock = TVTargetLock(); lock.select(first.id)
        #expect(session.assign(control: 0, to: first.id))
        lock.clear()
        for _ in 0..<90 where !session.targetCandidates(for: 0).contains(where: { $0.assignment == .eligible }) { session.tick() }
        let fresh = try #require(session.targetCandidates(for: 0).first { $0.assignment == .eligible })
        #expect(fresh.id != first.id)
        let viewport = MobileViewport(levelSize: session.levelSize, viewSize: session.levelSize, zoom: 1)
        let picked = try #require(MobileTargetSelector.select(candidates: session.targetCandidates(for: 0),
            touch: viewport.viewPoint(fromLevel: fresh.point), viewport: viewport, input: .precision))
        #expect(picked.state == .eligible && session.assign(control: 0, to: picked.id))
        for _ in 0..<40 { session.tick() }
        #expect(session.rewind(seconds: 2))
        lock.clear()
        for _ in 0..<90 where !session.targetCandidates(for: 0).contains(where: { $0.assignment == .eligible }) { session.tick() }
        let next = try #require(session.targetCandidates(for: 0).first { $0.assignment == .eligible })
        #expect(session.assign(control: 0, to: next.id))
    }
}
