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
check(speed.selected == 1 && speed.multiplier == 1 && speed.cruise == 2, "Decreasing must reach 1× and remember 2×")
speed.reset(at: 13); speed.step(1, at: 14)
check(speed.target == 2 && speed.cruise == 2, "Choosing a tier must start the selected speed")
speed.update(at: 15); check(speed.multiplier == 2, "Selected speed must affect the clock")
print("PASS immediate toggle, remembered tiers, bounded arrows and double-click absorption")

for input in [GameplaySpeed.Hold.key, .mouse, .shift, .controller] {
    speed.newLevel(at: 20)
    speed.press(input, at: 21)
    speed.update(at: 21.24); check(speed.target == 1, "A press must not start a boost before the hold threshold")
    for (time, tier) in [(21.26, 2.0), (21.77, 3), (22.27, 5), (22.77, 10)] {
        speed.update(at: time); check(speed.target == tier, "Hold must ramp through tiers")
    }
    speed.release(input, at: 23)
    check(speed.multiplier == (input == .key ? 10 : 1), "F must keep the reached speed; temporary boosts must restore it")
    speed.newLevel(at: 24); speed.step(1, at: 25)
    speed.press(input, at: 26); speed.update(at: 28)
    speed.release(input, at: 29)
    check(speed.multiplier == (input == .key ? 10 : 2), "F must retain the reached tier from an existing cruise")
    speed.press(input, at: 30); speed.update(at: 32); speed.reset(at: 32.1)
    speed.release(input, at: 32.2)
    check(speed.multiplier == 1, "Release after an emergency exit must not restart")
}
for (duration, tier) in [(0.3, 2.0), (0.8, 3), (1.3, 5), (1.8, 10)] {
    speed.newLevel(at: 0); speed.press(.key, at: 1)
    speed.release(.key, at: 1 + duration)
    speed.update(at: 5)
    check(speed.selected == tier && speed.multiplier == tier && speed.cruise == tier,
          "F release must keep each reached tier even between render updates")
    speed.tap(at: 6); check(speed.multiplier == 1, "F tap must stop a retained speed")
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

speed.newLevel(at: 100)
for (time, expected) in [(101.0, 2.0), (101.1, 1), (101.2, 2), (101.3, 1)] {
    speed.press(.mouse, at: time)
    speed.release(.mouse, at: time + 0.01)
    check(speed.target == expected, "Every middle click must toggle, including rapid clicks")
}
speed.step(1, at: 102); speed.step(1, at: 103)
speed.tap(at: 104, absorbRapidClicks: false)
check(speed.target == 1 && speed.cruise == 3, "Stopping must preserve the chosen fast tier")
speed.tap(at: 104.1, absorbRapidClicks: false)
check(speed.target == 3, "Middle toggle must restore the most recent fast tier")
print("PASS toolbar 1× floor and rapid remembered-speed toggles")

var pitch = GameplayMusicPitch()
var previousPitch = 1.0
for (index, tier) in GameplaySpeed.steps.dropFirst().enumerated() {
    let time = 200 + Double(index)
    let ratio = GameplayMusicPitch.ratio(for: tier)
    check(ratio > previousPitch && ratio <= 1.5, "Each tier must raise pitch within the 1.5× cap")
    pitch.update(speed: tier, at: time)
    let start = pitch.cents
    pitch.update(speed: tier, at: time + 0.06)
    check(pitch.cents > start && pitch.cents < 1200 * log2(ratio), "Pitch must glide without jumping")
    pitch.update(speed: tier, at: time + 0.13)
    check(abs(pow(2, pitch.cents / 1200) - ratio) < 0.000001, "Pitch did not settle in 120 ms")
    previousPitch = ratio
}
pitch.update(speed: 1, at: 205)
pitch.update(speed: 1, at: 205.04)
let fallingPitch = pitch.cents
pitch.update(speed: 5, at: 205.04)
check(pitch.cents == fallingPitch, "A reversed glide jumped in pitch")
pitch.update(speed: 1, at: 206)
pitch.update(speed: 1, at: 206.13)
check(pitch.cents == 0, "Returning to normal retained raised pitch")
check(GameplayMusicPitch.ratio(for: 100) <= 1.5 && GameplayMusicPitch.ratio(for: 0) == 1,
      "Out-of-range speed escaped the pitch limits")
print("PASS per-tier music pitch, 120 ms glides, reversals and pitch cap")
