import Foundation
import NxlvKit

// Rewind is only useful if it is exact. These compare state hashes before and
// after going back, so any drift fails loudly rather than showing up later as
// a level that behaves differently after a rewind.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func loadLevelOne(_ directory: URL) throws -> ClassicDOSSimulation {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
    let assets = try ClassicMainDATAssets.load(from: directory)
    let level = campaign.levels[0].level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    let rendered = try ClassicLevelRenderer.render(
        level, groundSet: ground, specialGraphic: nil)
    return try ClassicDOSSimulation(
        level: level, renderedLevel: rendered, mainDATAssets: assets)
}

private func hash(_ simulation: ClassicDOSSimulation) -> String {
    ClassicDOSReplayRecorder.stateHash(of: simulation)
}

private func testRewindIsExact(_ directory: URL) throws {
    var session = ClassicDOSRewind(simulation: try loadLevelOne(directory))
    for _ in 0..<400 { session.tick() }
    let reference = hash(session.simulation)

    try require(session.seek(toTick: 150), "could not seek back to 150")
    try require(session.currentTick == 150, "seek landed on \(session.currentTick)")
    try require(session.seek(toTick: 400), "could not seek forward to 400")
    try require(
        hash(session.simulation) == reference,
        "state after a round trip did not match the original")
    print("PASS rewind is exact — 400 to 150 and back reproduces the same state")
}

private func testCommandsSurviveRewind(_ directory: URL) throws {
    var session = ClassicDOSRewind(simulation: try loadLevelOne(directory))
    for _ in 0..<60 { session.tick() }
    let result = session.assign(.digger, to: 0)
    try require(result == .assigned, "the digger was refused: \(result.rawValue)")
    for _ in 0..<340 { session.tick() }
    let reference = hash(session.simulation)

    // Go back before the assignment, then forward past it again.
    try require(session.seek(toTick: 20), "could not seek behind the assignment")
    try require(session.seek(toTick: 400), "could not seek forward again")
    try require(
        hash(session.simulation) == reference,
        "the assignment was lost or duplicated across a rewind")
    try require(session.commands.count == 1, "expected one logged command")
    print("PASS commands survive rewind — the digger is reapplied at the same tick")
}

private func testStepping(_ directory: URL) throws {
    var session = ClassicDOSRewind(simulation: try loadLevelOne(directory))
    for _ in 0..<200 { session.tick() }
    let atTwoHundred = hash(session.simulation)

    try require(session.stepBackward(), "could not step back")
    try require(session.currentTick == 199, "step back landed on \(session.currentTick)")
    try require(session.stepForward(), "could not step forward")
    try require(session.currentTick == 200, "step forward landed on \(session.currentTick)")
    try require(
        hash(session.simulation) == atTwoHundred,
        "single frame stepping did not return to the same state")
    print("PASS frame stepping — back one, forward one, identical state")
}

private func testHistoryIsBounded(_ directory: URL) throws {
    var session = ClassicDOSRewind(
        simulation: try loadLevelOne(directory),
        keyframeInterval: 17,
        maximumKeyframes: 10)
    for _ in 0..<1000 { session.tick() }
    let heldKeyframes = session.keyframeCount
    let megabytesHeld = Double(session.estimatedMemoryBytes) / 1_048_576
    try require(
        heldKeyframes <= 10,
        "history grew to \(heldKeyframes) keyframes past its cap")
    try require(heldKeyframes > 1, "history kept only \(heldKeyframes) keyframe")
    try require(
        !session.seek(toTick: 0),
        "a tick older than the history was accepted")
    try require(session.seek(toTick: session.earliestTick), "the earliest tick is unreachable")
    print(String(
        format: "PASS history is bounded — %d keyframes, about %.1f MB",
        heldKeyframes, megabytesHeld))
}

private func testRewindSeconds(_ directory: URL) throws {
    var session = ClassicDOSRewind(simulation: try loadLevelOne(directory))
    for _ in 0..<500 { session.tick() }
    try require(session.rewind(seconds: 5), "could not rewind five seconds")
    let expected = 500 - ClassicDOSRules.ticksPerSecond * 5
    try require(
        session.currentTick == expected,
        "five seconds back landed on \(session.currentTick), expected \(expected)")
    print("PASS rewind by seconds — five seconds is \(ClassicDOSRules.ticksPerSecond * 5) ticks")
}

private func testFreshLoadsAreIdentical(_ directory: URL) throws {
    let a = hash(try loadLevelOne(directory))
    let b = hash(try loadLevelOne(directory))
    try require(a == b, "two fresh loads of the same level hash differently:\n  \(a)\n  \(b)")
    print("PASS two fresh loads of a level are identical")
}

private func testProducesAValidReplay(_ directory: URL) throws {
    let start = try loadLevelOne(directory)
    let initial = hash(start)
    var session = ClassicDOSRewind(simulation: start)
    session.setReleaseRate(99)
    for _ in 0..<60 { session.tick() }
    _ = session.assign(.digger, to: 0)
    session.setReleaseRate(70)
    for _ in 0..<40 { session.tick() }
    session.beginNuke()
    // Play to the end, the same rule the replay player uses. A fixed budget
    // here made the test depend on the level finishing inside it: any change
    // that cost a few ticks left this session stopped mid-level while the
    // replay ran on to the end, and the two states then differed.
    var played = 0
    while !session.simulation.isComplete, played < ClassicDOSReplayPlayer.defaultTickLimit {
        session.tick()
        played += 1
    }
    print("     (level one finished after \(session.simulation.tickCount) ticks)")

    let replay = session.replay(
        rank: "Fun", number: 1, title: "Just dig!", initialStateHash: initial)
    let encoded = try JSONEncoder().encode(replay)
    let decoded = try JSONDecoder().decode(ClassicDOSReplay.self, from: encoded)
    let outcome = try ClassicDOSReplayPlayer.run(
        decoded, simulation: try loadLevelOne(directory), verify: true)
    try require(
        outcome.stateHash == hash(session.simulation),
        "the exported replay did not reproduce the played session")
    print("PASS a rewound session still exports a replay that verifies")
}

private func testCommandBoundariesAndBranches(_ directory: URL) throws {
    let start = try loadLevelOne(directory)
    var session = ClassicDOSRewind(simulation: start, keyframeInterval: 20)
    session.setReleaseRate(99)
    for _ in 0..<60 { session.tick() }
    try require(session.assign(.digger, to: 0) == .assigned, "boundary digger refused")
    session.setReleaseRate(80)
    let boundary = hash(session.simulation)
    for _ in 0..<140 { session.tick() }
    let reference = hash(session.simulation)
    try require(session.seek(toTick: 60), "boundary seek failed")
    try require(hash(session.simulation) == boundary, "commands after keyframe capture were lost")
    try require(session.seek(toTick: 0), "tick zero seek failed")
    try require(session.simulation.releaseRate == 99, "tick zero command was lost")
    for _ in 0..<200 { session.tick() }
    try require(hash(session.simulation) == reference, "normal playback lost future commands")
    try require(session.seek(toTick: 20), "branch seek failed")
    try require(session.assign(.digger, to: -1) != .assigned, "invalid assignment accepted")
    try require(session.commands.count == 3, "refused command erased future history")
    let partial = session.replay(rank: "Fun", number: 1, title: "Just dig!", initialStateHash: hash(start))
    try require(partial.events.count == 1, "replay exported an unplayed future")
    session.setReleaseRate(70)
    try require(session.commands.count == 2, "new branch retained old future commands")
    var expected = ClassicDOSRewind(simulation: start, keyframeInterval: 20)
    expected.setReleaseRate(99)
    for _ in 0..<20 { expected.tick() }
    expected.setReleaseRate(70)
    for _ in 0..<180 { session.tick(); expected.tick() }
    try require(hash(session.simulation) == hash(expected.simulation), "abandoned future changed the new branch")
    try require(session.seek(toTick: 40), "branch round trip failed")
    try require(session.seek(toTick: 200), "branch forward seek failed")
    try require(hash(session.simulation) == hash(expected.simulation), "rebuilt keyframes used the wrong command count")
    let before = hash(session.simulation)
    for seconds in [Double.nan, Double.infinity, -Double.infinity, -1] {
        try require(!session.rewind(seconds: seconds), "invalid rewind duration accepted")
        try require(hash(session.simulation) == before, "invalid duration changed state")
    }
    try require(session.rewind(seconds: Double.greatestFiniteMagnitude), "large duration did not clamp")
    try require(session.currentTick == session.earliestTick, "large duration missed earliest tick")
    print("PASS keyframe boundaries, tick zero, resumed playback, branching, replay prefix and invalid durations")
}

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

do {
    try testCommandBoundariesAndBranches(directory)
    try testRewindIsExact(directory)
    try testCommandsSurviveRewind(directory)
    try testStepping(directory)
    try testHistoryIsBounded(directory)
    try testRewindSeconds(directory)
    try testFreshLoadsAreIdentical(directory)
    try testProducesAValidReplay(directory)
    print("Classic DOS rewind tests passed.")
} catch {
    FileHandle.standardError.write(Data("Rewind tests failed: \(error)\n".utf8))
    exit(1)
}
