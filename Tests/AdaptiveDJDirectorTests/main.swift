import Foundation
import NxlvKit

// The director decides when the soundtrack may change. It never chooses a
// track and never fades anything, so every rule here is testable without any
// audio present.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private typealias Telemetry = AdaptiveDJEngine.Telemetry

/// A level under way, with nothing remarkable happening.
private func quiet(saved: Int = 0) -> Telemetry {
    Telemetry(releasedCount: 10, totalCount: 10, savedCount: saved, requiredCount: 1,
        releaseRate: 50, dangerCount: 0, remainingSeconds: 300)
}

private func testQuietLevelAsksForNothing() throws {
    var director = AdaptiveDJDirector()
    for _ in 0..<120 {
        try require(director.cue(for: quiet()) == nil, "a quiet level asked for a change")
    }
    print("PASS a level with nothing happening never changes the music")
}

/// The cue this whole design exists for.
private func testFirstRescueCuesOnce() throws {
    var director = AdaptiveDJDirector()
    try require(director.cue(for: quiet()) == nil, "nothing should happen before a rescue")

    guard let cue = director.cue(for: quiet(saved: 1)) else {
        throw Failure(description: "the first lemming home did not cue a change")
    }
    try require(cue.reason == .firstRescue, "expected the first rescue, got \(cue.reason)")
    try require(
        cue.timing == .atNextPhrase,
        "a rescue should wait for the phrase, not cut in")

    // The count stays above zero for the rest of the level, and the music must
    // not ask to change again on every frame that follows.
    for saved in 2...9 {
        try require(
            director.cue(for: quiet(saved: saved)) == nil,
            "the rescue cue fired again at \(saved) saved")
    }
    print("PASS the first lemming home cues one change, on the next phrase")
}

private func testNukeCutsImmediately() throws {
    var director = AdaptiveDJDirector()
    var telemetry = quiet(saved: 3)
    telemetry.isNuking = true

    guard let cue = director.cue(for: telemetry) else {
        throw Failure(description: "the nuke did not cue a change")
    }
    // A rescue is pending in the same frame. The nuke is louder.
    try require(cue.reason == .nuke, "the nuke should outrank a rescue, got \(cue.reason)")
    try require(cue.timing == .immediate, "the nuke should not wait for the phrase")
    print("PASS the nuke cuts in at once, ahead of anything else")
}

private func testWinCuesOnce() throws {
    var director = AdaptiveDJDirector()
    var telemetry = quiet(saved: 5)
    telemetry.didWin = true

    // The rescue already happened earlier in the level.
    _ = director.cue(for: quiet(saved: 1))
    guard let cue = director.cue(for: telemetry) else {
        throw Failure(description: "winning did not cue a change")
    }
    try require(cue.reason == .won, "expected the win, got \(cue.reason)")
    try require(cue.timing == .atNextPhrase, "the win should land on the phrase")
    try require(director.cue(for: telemetry) == nil, "the win cued twice")
    print("PASS winning cues one change, on the next phrase")
}

private func testTimeRunningOutCuesOnce() throws {
    var director = AdaptiveDJDirector()
    var telemetry = quiet()
    telemetry.remainingSeconds = 59

    guard let cue = director.cue(for: telemetry) else {
        throw Failure(description: "the closing minute did not cue a change")
    }
    try require(cue.reason == .timeRunningOut, "expected the clock, got \(cue.reason)")
    telemetry.remainingSeconds = 20
    try require(director.cue(for: telemetry) == nil, "the clock cued twice")
    print("PASS the closing minute cues one change")
}

/// Rewinding is a supported move, so the music has to cope with it.
private func testRewindLetsACueHappenAgain() throws {
    var director = AdaptiveDJDirector()
    _ = director.cue(for: quiet(saved: 1))
    try require(director.cue(for: quiet(saved: 1)) == nil, "the rescue cued twice")

    director.reset()
    guard let cue = director.cue(for: quiet(saved: 1)) else {
        throw Failure(description: "after a rewind the rescue should cue again")
    }
    try require(cue.reason == .firstRescue, "expected the rescue after a rewind")
    print("PASS a rewind lets the same moment cue the music again")
}

/// A whole level, in the order a player would live it.
private func testOneLevelEndToEnd() throws {
    var director = AdaptiveDJDirector()
    var seen: [AdaptiveDJCue.Reason] = []

    for tick in 0..<400 {
        var telemetry = quiet(saved: tick >= 100 ? 1 : 0)
        telemetry.remainingSeconds = 300 - tick
        telemetry.didWin = tick >= 300
        if let cue = director.cue(for: telemetry) { seen.append(cue.reason) }
    }
    try require(
        seen == [.firstRescue, .timeRunningOut, .won],
        "a level should cue three times in order, got \(seen)")
    print("PASS one level cues three times, in the order they happen")
}

do {
    try testQuietLevelAsksForNothing()
    try testFirstRescueCuesOnce()
    try testNukeCutsImmediately()
    try testWinCuesOnce()
    try testTimeRunningOutCuesOnce()
    try testRewindLetsACueHappenAgain()
    try testOneLevelEndToEnd()
    print("Adaptive DJ director tests passed.")
} catch {
    FileHandle.standardError.write(Data("Adaptive DJ director tests failed: \(error)\n".utf8))
    exit(1)
}
