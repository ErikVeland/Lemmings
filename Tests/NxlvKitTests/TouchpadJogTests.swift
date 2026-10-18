import Testing
@testable import NxlvKit

struct TouchpadJogTests {
    @Test func slideStepsOneTickPerStepWidth() {
        var jog = TouchpadJog()
        #expect(jog.update(x: -0.5, y: 0.2) == 0)
        #expect(jog.update(x: -0.4, y: 0.2) == 0)
        #expect(jog.update(x: -0.37, y: 0.2) == 1)
        #expect(jog.update(x: -0.12, y: 0.2) == 2)
        #expect(jog.update(x: -0.3, y: 0.2) == -1)
    }

    @Test func liftClickAndJumpsNeverStep() {
        var jog = TouchpadJog()
        _ = jog.update(x: 0.5, y: 0.1)
        // GameController reports a lifted finger as (0, 0).
        #expect(jog.update(x: 0, y: 0) == 0)
        #expect(jog.update(x: -0.5, y: 0.1) == 0)
        #expect(jog.update(x: nil) == 0)
        #expect(jog.update(x: 0.2, y: 0.1) == 0)
        // A new touch far from the last sample starts a new slide.
        #expect(jog.update(x: 0.9, y: 0.1) == 0)
        #expect(jog.update(x: 0.9 - TouchpadJog.stepWidth, y: 0.1) == -1)
    }

    @Test func fastSwipeIsCapped() {
        var jog = TouchpadJog()
        _ = jog.update(x: -0.3, y: 0.1)
        #expect(jog.update(x: 0.3, y: 0.1) == 4)
        var fast = TouchpadJog()
        _ = fast.update(x: 0, y: 0.5)
        #expect(fast.update(x: 0.58, y: 0.5) == 4)
    }
}
