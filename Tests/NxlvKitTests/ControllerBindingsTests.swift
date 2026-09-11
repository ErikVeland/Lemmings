import Testing
@testable import NxlvKit

struct ControllerBindingsTests {
    @Test func remappingKeepsEveryActionReachable() {
        let mapping = ControllerBindings.swapping([:], physical: .a, role: .rightTrigger)
        #expect(ControllerBindings.remap([.a], using: mapping) == [.rightTrigger])
        #expect(ControllerBindings.remap([.rightTrigger], using: mapping) == [.a])
        #expect(ControllerBindings.remap(Set(ControllerBindings.Button.allCases), using: mapping).count == ControllerBindings.Button.allCases.count)
        let next = ControllerBindings.swapping(mapping, physical: .b, role: .rightTrigger)
        #expect(ControllerBindings.remap([.b], using: next) == [.rightTrigger])
        #expect(ControllerBindings.remap([.a], using: next) == [.b])
        #expect(ControllerBindings.validatedMapping(["a": "b"]) == [:])
        #expect(ControllerBindings.validatedMapping(["unknown": "a"]) == [:])
        #expect(ControllerBindings.validatedMapping(["a": "unknown"]) == [:])
    }

    @Test func everyQoLChordAndMenuLayer() {
        let chords: [(ControllerBindings.Button, ControllerBindings.Action)] = [
            (.a, .endRun), (.b, .rewind), (.x, .speedReset), (.y, .hints),
            (.menu, .retry), (.options, .settings), (.leftShoulder, .step(-1)), (.rightShoulder, .step(1)),
            (.left, .speedStep(-1)), (.right, .speedStep(1)), (.up, .centre(true)), (.down, .centre(false))
        ]
        for (button, expected) in chords {
            var bindings = ControllerBindings()
            _ = bindings.update(pressed: [])
            #expect(bindings.update(pressed: [.leftTrigger, button]) == [expected])
            #expect(bindings.update(pressed: [.leftTrigger, button]) == [])
        }
        for (button, expected): (ControllerBindings.Button, ControllerBindings.Action) in [
            (.a, .assign), (.b, .cancel), (.leftShoulder, .cycle(-1)), (.rightShoulder, .cycle(1)),
            (.left, .focusUnassigned(-1)), (.right, .focusUnassigned(1)), (.up, .rate(1)), (.down, .rate(-1))
        ] {
            var bindings = ControllerBindings(); _ = bindings.update(pressed: [])
            #expect(bindings.update(pressed: [.leftTrigger, button], inMenu: true) == [expected])
        }
    }

    @Test func triggerMatchesFTapHoldAndRapidExit() {
        var speed = GameplaySpeed()
        for (index, target) in [2.0, 1, 2, 1].enumerated() {
            let time = Double(index)
            speed.press(.controller, at: time)
            speed.release(.controller, at: time + 0.05)
            #expect(speed.target == target)
        }
        speed.press(.controller, at: 6)
        speed.update(at: 8.5)
        #expect(speed.target == 10)
        speed.release(.controller, at: 8.6)
        speed.update(at: 8.9)
        #expect(speed.multiplier == 1)
        speed.press(.controller, at: 10); speed.release(.controller, at: 10.05)
        speed.press(.controller, at: 10.2)
        speed.release(.controller, at: 10.25)
        #expect(speed.target == 1)
    }

    @Test func interruptedAndDisabledTapsNeverSelectSpeed() {
        var speed = GameplaySpeed()
        speed.press(.controller, at: 0)
        speed.release(.controller, at: 0.05, allowTap: false)
        #expect(speed.target == 1)
        speed.press(.controller, at: 1, tapEnabled: false)
        speed.release(.controller, at: 1.05)
        #expect(speed.target == 1)
        speed.press(.controller, at: 2); speed.reset(at: 2.03)
        speed.release(.controller, at: 2.05)
        #expect(speed.target == 1)
    }
    @Test func buttonsAndModifier() {
        var bindings = ControllerBindings()
        #expect(bindings.update(pressed: []) == [])
        #expect(bindings.update(pressed: [.a]) == [.assign])
        #expect(bindings.update(pressed: [.a]) == [])
        _ = bindings.update(pressed: [])
        #expect(bindings.update(pressed: [.x]) == [.repeatAssignment])
        _ = bindings.update(pressed: [])
        #expect(bindings.update(pressed: [.right]) == [.focusUnassigned(1)])
        _ = bindings.update(pressed: [])
        #expect(bindings.update(pressed: [.leftTrigger, .right]) == [.speedStep(1)])
        _ = bindings.update(pressed: [])
        #expect(bindings.update(pressed: [.leftTrigger, .up]) == [.centre(true)])
    }
    @Test func reconnectAndRelease() {
        var bindings = ControllerBindings()
        #expect(bindings.update(pressed: [.a, .rightTrigger]) == [])
        #expect(bindings.update(pressed: []) == [.boost(false)])
        #expect(bindings.update(pressed: [.rightTrigger]) == [.boost(true)])
        #expect(bindings.update(pressed: [.rightTrigger]) == [])
        bindings.reset()
        #expect(bindings.update(pressed: [.x]) == [])
    }
    @Test func controllerSpeedHoldRestoresSelection() {
        var speed = GameplaySpeed()
        speed.tap(at: 0)
        speed.press(.controller, at: 1)
        speed.update(at: 2)
        #expect(speed.target > 2)
        speed.release(.controller, at: 2)
        #expect(speed.target == 2)
    }
}
