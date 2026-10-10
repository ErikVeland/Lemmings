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
require(director.cue(for: .init(savedCount: 50, requiredCount: 50)) == .init(reason: .won, timing: .atNextPhrase), "Rescue target did not allow a transition")
let target = AdaptiveDJEngine.Telemetry(savedCount: 50, requiredCount: 50, didWin: true, isComplete: true)
require(director.cue(for: target) == nil, "Completed win repeated the target transition")
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
require(!old.pauseMusicBeatOnly, "An upgrade unexpectedly enabled pause music")
var changed = old; changed.djIncludesOtherSoundtracks = false; changed.fullScreenHDRFlashes = false; changed.pauseMusicBeatOnly = true
let restored = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(changed))
require(restored == changed, "New options did not persist")
print("PASS rescue-target transitions, one transition per level, countdown beeps and settings migration")

director.reset()
require(director.cue(for: .init(didWin: false, isComplete: true)) == nil, "A loss replaced the funeral track")
require(LevelMusicSelection.track(index: 0, title: "", holiday: false, ohNo: false) == "cancan", "Opening tune wrong")
require(LevelMusicSelection.track(index: 1, title: "A BeastII of a level", holiday: false, ohNo: false) == "beastII", "Special tune wrong")

require(!LevelMusicSelection.matchesRecording("01 Awesome", track: "cancan"), "Incomplete album picked unrelated tune")
require(LevelMusicSelection.matchesRecording("04 Lemmings - Smile if you Love Lemmings", track: "tim2"), "Named recording did not match")

require(LevelMusicSelection.matchesRecording("12 Lemmings - Dance of the Little Swans", track: "tim8"), "Tim8 album mapping wrong")
require(LevelMusicSelection.matchesRecording("10 Lemmings - Forest Green", track: "tim10"), "Tim10 album mapping wrong")
let expectedCycle = ["cancan", "lemming1", "tim2", "lemming2", "tim8", "tim3", "tim5", "doggie", "tim6", "lemming3", "tim7", "tim9", "tim1", "tim10", "tim4", "tenlemmings", "mountain"]
for index in 0..<34 {
    require(LevelMusicSelection.track(index: index, title: "ordinary", holiday: false, ohNo: false) == expectedCycle[index % 17], "Reference rotation mismatch")
}

var scoreTitles = Array(repeating: "Ordinary", count: 120)
scoreTitles[21] = "A Beast of a level"
scoreTitles[50] = "A Beast of a level"
require(LevelMusicSelection.cycle(index: 21, titles: scoreTitles, holiday: false, ohNo: false) == 0,
    "First special theme must be authentic even late in the campaign")
require(LevelMusicSelection.cycle(index: 50, titles: scoreTitles, holiday: false, ohNo: false) == 1,
    "Repeated special theme did not advance its own cycle")
require(LevelMusicSelection.cycle(index: 17, titles: scoreTitles, holiday: false, ohNo: false) == 1,
    "Ordinary score cycle did not advance")

require(LevelMusicSelection.track(index: 13, title: "Professor Mariarti", holiday: false, ohNo: false) == "mariarti", "Missing Archimedes special assignment")
require(LevelMusicSelection.track(index: 13, title: "Professor Mariarti", holiday: true, ohNo: false) != "mariarti", "Special leaked into seasonal campaign")

// A retry brakes the record to near rest and fades it out. The release
// climbs from near rest to full speed, and both curves stay monotonic.
for phase in [VinylMotion.Phase.stop, .start] {
    let first = VinylMotion.sample(phase, progress: 0), last = VinylMotion.sample(phase, progress: 1)
    var previous = first
    for step in 1...20 {
        let now = VinylMotion.sample(phase, progress: Double(step) / 20)
        require(phase == .stop ? now.rate <= previous.rate : now.rate >= previous.rate, "Vinyl rate must change in one direction")
        require(now.rate >= VinylMotion.minimumRate && now.rate <= 1 && now.gain >= 0 && now.gain <= 1, "Vinyl sample out of range")
        previous = now
    }
    if phase == .stop {
        require(first.rate == 1 && first.gain == 1 && last.rate == VinylMotion.minimumRate && last.gain == 0, "Vinyl stop must start at speed and end silent near rest")
        require(VinylMotion.sample(.stop, progress: 0.5).gain == 1, "The brake must keep the level until the pitch is low")
    } else {
        require(first.rate == VinylMotion.minimumRate && first.gain == 0 && last.rate == 1 && last.gain == 1, "Vinyl start must rise from rest to full speed")
        require(VinylMotion.sample(.start, progress: 0.5).rate > 0.8, "The release must reach most of its speed quickly")
    }
}
require(VinylMotion.stopSeconds <= 0.5 && VinylMotion.startSeconds <= 0.35, "Vinyl stop and start must stay quick")
print("PASS quick vinyl brake and release curves")
