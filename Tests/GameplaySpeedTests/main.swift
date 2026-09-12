import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
var speed = GameplaySpeed()
speed.tap(at: 1)
check(speed.target == 2, "First tap must engage 2× without a double-click wait")
for (time, tier) in [(2.0, 3.0), (3, 5), (4, 10), (5, 10)] {
    speed.step(1, at: time); speed.update(at: time + 0.3)
    check(speed.selected == tier && speed.multiplier == tier, "Increasing must stop at 10×")
}
speed.tap(at: 6)
check(speed.multiplier == 1, "Toggle off must be immediate")
speed.tap(at: 6.1, clickCount: 2); speed.tap(at: 6.2, clickCount: 3)
check(speed.multiplier == 1, "Extra clicks must not restart speed")
speed.tap(at: 7)
check(speed.target == 10, "Toggle must remember the chosen tier")
for time in 8...12 { speed.step(-1, at: Double(time)) }
check(speed.selected == 2 && speed.multiplier == 2, "Decreasing must stop at 2× immediately")
speed.reset(at: 13); speed.step(1, at: 14)
check(speed.target == 1 && speed.cruise == 3, "Choosing a tier while off must not start speed")
speed.tap(at: 15); check(speed.target == 3, "Toggle must use the prepared tier")
print("PASS immediate toggle, remembered tiers, bounded arrows and double-click absorption")

for input in [GameplaySpeed.Hold.key, .mouse, .shift, .controller] {
    speed.newLevel(at: 20)
    speed.press(input, at: 21)
    speed.update(at: 21.24); check(speed.target == 1, "A press must not start a boost before the hold threshold")
    for (time, tier) in [(21.26, 2.0), (21.77, 3), (22.27, 5), (22.77, 10)] {
        speed.update(at: time); check(speed.target == tier, "Hold must ramp through tiers")
    }
    speed.release(input, at: 23)
    check(speed.multiplier == 1 && speed.selected == 1, "Release must immediately restore the previous speed")
    speed.tap(at: 24); speed.step(1, at: 25)
    speed.press(input, at: 26); speed.update(at: 28)
    speed.release(input, at: 29)
    check(speed.multiplier == 3, "Boost from cruise must restore cruise")
    speed.press(input, at: 30); speed.update(at: 32); speed.reset(at: 32.1)
    speed.release(input, at: 32.2)
    check(speed.multiplier == 1, "Release after an emergency exit must not restart")
}
speed.newLevel(at: 40); speed.press(.shift, at: 41); speed.press(.controller, at: 41.1)
speed.update(at: 43); speed.release(.shift, at: 43.1)
check(speed.isHeld && speed.target == 10, "One release must not end another held boost")
speed.release(.controller, at: 43.2); check(speed.multiplier == 1, "The final release must restore speed")
speed.tap(at: 44); speed.step(1, at: 45); speed.newLevel(at: 46)
check(speed.multiplier == 1 && speed.cruise == 2, "New levels must start at 1× with a 2× first tier")
speed.press(.controller, at: 47); speed.update(at: 49); speed.cancelInput(at: 50); speed.release(.controller, at: 51)
check(speed.multiplier == 1, "Focus loss must clear the boost")
print("PASS F, mouse, Shift and controller holds, overlapping inputs, emergency exits and level reset")
for legacy in [3.0, 8] {
    var original = GameplaySpeed(legacyMultiplier: legacy); original.variableEnabled = false
    original.tap(at: 0); check(original.multiplier == legacy, "OG fixed speed changed")
    original.tap(at: 0.1); check(original.multiplier == 1, "OG toggle failed")
    original.press(.shift, at: 1); original.update(at: 10)
    check(original.multiplier == legacy, "OG hold must stay fixed")
    original.release(.shift, at: 11); check(original.multiplier == 1, "OG hold did not release")
}
print("PASS original fixed-speed controls")
