import Foundation
import NxlvKit

// The mapping from engine events to sounds is what makes skill placement
// audible, so it is worth testing on its own rather than only through the app.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func testCoreEventsMap() throws {
    let events: [ClassicDOSEvent] = [
        .entrancesOpened,
        .skillAssigned(lemmingID: 3, skill: .digger),
        .actionChanged(lemmingID: 3, from: .walking, to: .ohNo),
        .actionChanged(lemmingID: 3, from: .ohNo, to: .exploding),
        .saved(lemmingID: 7),
        .hitSteel(lemmingID: 2),
        .builderWarning(lemmingID: 5),
        .nukeStarted,
    ]
    let cues = ClassicSoundCue.cues(for: events)
    for expected: ClassicSoundEffect in [
        .doorOpen, .assignSkill, .ohNo, .explode, .exitLevel, .hitSteel,
        .builderWarning, .nuke,
    ] {
        try require(cues.contains(expected), "\(expected.rawValue) was not produced")
    }
    print("PASS the core events all produce a sound")
}

private func testHazardsMap() throws {
    let events: [ClassicDOSEvent] = [
        .actionChanged(lemmingID: 1, from: .falling, to: .splatting),
        .actionChanged(lemmingID: 2, from: .walking, to: .drowning),
        .actionChanged(lemmingID: 3, from: .walking, to: .vaporizing),
    ]
    let cues = ClassicSoundCue.cues(for: events)
    try require(cues.contains(.splat), "splatting produced no sound")
    try require(cues.contains(.drown), "drowning produced no sound")
    try require(cues.contains(.vaporize), "vaporizing produced no sound")
    print("PASS the hazards all produce a sound")
}

private func testDuplicatesCollapse() throws {
    // A nuke pushes many lemmings into the same state on one tick.
    let events = (0..<12).map {
        ClassicDOSEvent.actionChanged(lemmingID: $0, from: .walking, to: .ohNo)
    }
    let cues = ClassicSoundCue.cues(for: events)
    try require(cues == [.ohNo], "twelve lemmings produced \(cues.count) sounds")
    print("PASS twelve lemmings entering the same state play one sound")
}

private func testQuietEventsStaySilent() throws {
    let events: [ClassicDOSEvent] = [
        .directionChanged(lemmingID: 1, direction: .left),
        .terrainRemoved(lemmingID: 1, skill: .basher, pixelCount: 40),
        .releaseRateChanged(60),
        .hatched(lemmingID: 0, entranceIndex: 0),
    ]
    try require(
        ClassicSoundCue.cues(for: events).isEmpty,
        "an event that should be silent produced a sound")
    print("PASS routine events stay silent")
}

private func testMappingReportsGaps() throws {
    var mapping = ClassicSoundMapping()
    try require(!mapping.isComplete, "an empty mapping claimed to be complete")
    try require(
        mapping.missingEffects.count == ClassicSoundEffect.allCases.count,
        "an empty mapping did not report every effect as missing")

    for (offset, effect) in ClassicSoundEffect.allCases.enumerated() {
        mapping.indices[effect] = offset
    }
    try require(mapping.isComplete, "a full mapping did not report as complete")
    try require(mapping.missingEffects.isEmpty, "a full mapping still reports gaps")
    print("PASS the mapping reports which sounds are unassigned")
}

private func testPitchRatio() throws {
    // A Sound Blaster derived its rate from a time constant, so the round
    // numbers people quote were never what the hardware ran at.
    let recorded = ClassicSoundMapping.soundBlasterRate(timeConstant: 165)
    let played = ClassicSoundMapping.soundBlasterRate(timeConstant: 208)
    try require(
        abs(recorded - 10_989.0) < 1.0,
        "time constant 165 gave \(recorded) Hz, expected about 10989")
    try require(
        abs(played - 20_833.0) < 1.0,
        "time constant 208 gave \(played) Hz, expected about 20833")

    let mapping = ClassicSoundMapping()
    try require(
        abs(mapping.pitchRatio - 1.896) < 0.002,
        "the default pitch ratio is \(mapping.pitchRatio), expected about 1.896")

    let flat = ClassicSoundMapping(recordedRate: 11_025, playbackRate: 11_025)
    try require(abs(flat.pitchRatio - 1.0) < 0.0001, "matched rates should not shift pitch")
    print(String(
        format: "PASS playback pitch — %.0f Hz recorded, %.0f Hz played, ratio %.3f",
        recorded, played, mapping.pitchRatio))
}

do {
    try testCoreEventsMap()
    try testHazardsMap()
    try testDuplicatesCollapse()
    try testQuietEventsStaySilent()
    try testMappingReportsGaps()
    try testPitchRatio()
    print("Classic sound cue tests passed.")
} catch {
    FileHandle.standardError.write(Data("Sound cue tests failed: \(error)\n".utf8))
    exit(1)
}
