import Foundation
import NxlvKit

func require(_ condition: Bool, _ message: String) {
    if !condition { print("FAIL: \(message)"); exit(1) }
}
var director = AdaptiveDJDirector()
for saved in 0..<50 {
    let telemetry = AdaptiveDJEngine.Telemetry(savedCount: saved, requiredCount: 50,
        remainingSeconds: 5, isNuking: true, didWin: true)
    require(director.cue(for: telemetry) == nil, "Transition before the actual rescue target")
}
let target = AdaptiveDJEngine.Telemetry(savedCount: 50, requiredCount: 50)
require(director.cue(for: target) == .init(reason: .won, timing: .atNextPhrase), "Missing target transition")
for _ in 0..<100 { require(director.cue(for: target) == nil, "Repeated victory transition") }
director.reset()
require(director.cue(for: target)?.reason == .won, "New level did not reset the cue")
director.reset()
require(director.cue(for: .init(savedCount: 0, requiredCount: 0)) == nil, "Empty target triggered music")
var warning = LastSecondsWarning()
warning.reset(seconds: 12)
var heard: [Int] = []
for second in stride(from: 12, through: 0, by: -1) {
    for _ in 0..<23 { if warning.update(seconds: second) { heard.append(second) } }
}
require(heard == Array(stride(from: 10, through: 1, by: -1)), "Countdown beeps missing or duplicated")
require(!warning.update(seconds: 8), "Rewind played a warning")
require(warning.update(seconds: 7), "Countdown did not resume after rewind")
require(!warning.update(seconds: nil), "Untimed level played a warning")
let old = try JSONDecoder().decode(ClassicSettings.self, from: Data("{}".utf8))
require(old.djIncludesOtherSoundtracks && old.hdEffectsEnabled && old.fullScreenHDRFlashes, "Upgrade defaults are wrong")
var changed = old; changed.djIncludesOtherSoundtracks = false; changed.fullScreenHDRFlashes = false
let restored = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(changed))
require(restored == changed, "New options did not persist")
print("PASS rescue quota only, one transition per level, ten countdown beeps, rewind, untimed levels and settings migration")
