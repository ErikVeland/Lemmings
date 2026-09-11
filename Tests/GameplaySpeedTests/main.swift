import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a-b) < 0.001 }

var speed = GameplaySpeed()
for (index, expected) in [2.0, 3, 5, 10, 1].enumerated() {
    let now = Double(index)
    speed.tap(at: now)
    check(speed.target == expected, "The tap sequence skipped a tier")
    speed.update(at: now + 0.25)
    check(near(speed.multiplier, expected), "The speed failed to settle")
}
speed.reset(at: 10)
speed.press(.key, at: 11)
speed.press(.key, at: 11.1)
speed.update(at: 11.24)
check(speed.target == 1, "A tap began a held boost")
for (time, target) in [(11.26, 2.0), (11.77, 3), (12.27, 5), (12.77, 10)] {
    speed.update(at: time)
    check(speed.target == target, "A held key skipped a tier")
    speed.update(at: time + 0.25)
    check(near(speed.multiplier, target), "A held tier did not settle")
}
speed.release(.key, at: 13.1)
check(speed.target == 1 && near(speed.multiplier, 10), "Release did not start a continuous return")
speed.update(at: 13.22)
check(speed.multiplier > 1 && speed.multiplier < 10, "Release snapped instead of easing")
speed.update(at: 13.35)
check(near(speed.multiplier, 1), "Release left speed stuck")
print("PASS tier sequence, bounded hold ramp, repeat suppression and smooth release")

speed.tap(at: 20); speed.tap(at: 21); speed.update(at: 21.3)
check(speed.selected == 3, "Cruise speed was not selected")
speed.press(.shift, at: 22); speed.update(at: 23.8); speed.update(at: 24.1)
speed.press(.key, at: 24.2); speed.release(.shift, at: 24.3)
check(speed.isHeld && speed.target == 10, "Releasing one of two held keys ended the boost")
speed.release(.key, at: 24.4); speed.update(at: 24.7)
check(speed.selected == 3 && near(speed.multiplier, 3), "Release forgot the selected cruising speed")
speed.press(.key, at: 25); speed.update(at: 26)
speed.reset(at: 26.1); speed.release(.key, at: 26.2)
check(!speed.isFast && speed.selected == 1, "A key-up restarted an emergency stop")
speed.tap(at: 27); speed.press(.key, at: 27.1); speed.release(.key, at: 27.2)
check(!speed.isFast, "Rapid F did not stop immediately")
speed.tap(at: 27.25); check(!speed.isFast, "Triple tapping re-engaged speed")
speed.tap(at: 28); speed.tap(at: 29, clickCount: 2)
check(!speed.isFast, "Double-click did not stop")
speed.press(.shift, at: 30); speed.update(at: 31); speed.cancelInput(at: 31.1)
speed.press(.key, at: 32); speed.release(.key, at: 32.1)
check(speed.selected == 2, "Focus recovery retained a stuck key")
print("PASS cruising speed, overlapping keys, rapid exits and focus recovery")

for legacy in [3.0, 8] {
    var original = GameplaySpeed(legacyMultiplier: legacy)
    original.variableEnabled = false
    original.tap(at: 0)
    check(original.multiplier == legacy, "OG fast-forward changed")
    original.tap(at: 0.1)
    check(original.multiplier == 1, "OG toggle failed")
    original.press(.shift, at: 1); original.update(at: 10)
    check(original.multiplier == legacy, "Fixed-speed hold became variable")
    original.release(.shift, at: 11)
    check(original.multiplier == 1, "Fixed-speed hold failed to release")
}
print("PASS original fixed speeds and temporary boost")
