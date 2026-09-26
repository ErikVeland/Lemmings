import Foundation
import NxlvKit

// The progression is the game. Passing carries you forward, failing puts you
// back on the same level, finishing a rank moves you to the next, and
// finishing the last rank ends the game. All of that is testable without an
// interface, so it is tested here rather than by playing.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func makeFlow() -> ClassicGameFlow {
    ClassicGameFlow(ranks: [
        ClassicRank(name: "Fun", levelIndices: [0, 1, 2]),
        ClassicRank(name: "Tricky", levelIndices: [3, 4]),
    ])
}

private func testTitleToPlaying() throws {
    var flow = makeFlow()
    try require(flow.screen == .title, "the game should open on the title screen")
    flow.startGame()
    try require(flow.screen == .rankSelect, "starting should offer the ranks")
    flow.selectRank(0)
    try require(flow.screen == .briefing(level: 0), "selecting a rank should brief its first level")
    flow.beginPlaying()
    try require(flow.screen == .playing(level: 0), "beginning should start the level")
    print("PASS title to rank to briefing to playing")
}

private func testPassingAdvances() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 5, total: 10)
    guard case .results = flow.screen else {
        throw Failure(description: "finishing should show a result")
    }
    flow.acknowledgeResults()
    try require(
        flow.screen == .briefing(level: 1), "passing should brief the next level")
    try require(flow.currentNumber == 2, "the level number should be 2, got \(flow.currentNumber)")
    try require(flow.hasPassed(rank: "Fun", position: 0), "the passed level was not recorded")
    print("PASS passing a level advances to the next")
}

private func testFailingRepeats() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 2, required: 5, total: 10)
    flow.acknowledgeResults()
    try require(
        flow.screen == .briefing(level: 0), "failing should return to the same level")
    try require(!flow.hasPassed(rank: "Fun", position: 0), "a failed level was recorded as passed")
    print("PASS failing a level returns to it")
}

private func testSkipOpensTheNextLevel() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 5, total: 10)
    try require(!flow.skipLevel(), "a passed level must not take a skip")
    flow.acknowledgeResults()
    flow.beginPlaying()
    flow.finishLevel(saved: 2, required: 5, total: 10)
    try require(flow.canSkipLevel && flow.skipLevel(), "a failed level must accept a skip")
    try require(flow.screen == .briefing(level: 2), "a skip must open the next level")
    try require(!flow.hasPassed(rank: "Fun", position: 1), "a skipped level was recorded as passed")
    try require(flow.isLevelUnlocked(2), "a skip must unlock the next level")
    flow.beginPlaying()
    flow.finishLevel(saved: 0, required: 5, total: 10)
    try require(flow.skipLevel() && flow.screen == .briefing(level: 3),
        "skipping the last level of a rank must open the next rank, not a rank completion")
    flow.beginPlaying()
    flow.finishLevel(saved: 0, required: 5, total: 10)
    flow.acknowledgeResults()
    flow.beginPlaying()
    flow.finishLevel(saved: 0, required: 5, total: 10)
    var practice = flow
    try require(practice.skipLevel(recordsCampaignProgress: false) && !practice.isLevelUnlocked(4),
        "a skip outside the campaign must not change campaign reach")
    flow.acknowledgeResults(); flow.selectLevel(rank: 1, position: 1); flow.beginPlaying()
    flow.finishLevel(saved: 0, required: 5, total: 10)
    try require(flow.skipLevel() && flow.screen == .rankSelect, "skipping the final level must return to the ranks")
    print("PASS a skip opens the next level without passing the skipped one")
}

private func testRankAndGameCompletion() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    for _ in 0..<3 {
        flow.beginPlaying()
        flow.finishLevel(saved: 10, required: 1, total: 10)
        flow.acknowledgeResults()
    }
    try require(
        flow.screen == .rankComplete(rank: "Fun"),
        "finishing every level of a rank should complete the rank")

    flow.acknowledgeRankComplete()
    try require(flow.screen == .briefing(level: 3), "the next rank should begin")

    for _ in 0..<2 {
        flow.beginPlaying()
        flow.finishLevel(saved: 10, required: 1, total: 10)
        flow.acknowledgeResults()
    }
    try require(
        flow.screen == .rankComplete(rank: "Tricky"), "the last rank should complete")
    flow.acknowledgeRankComplete()
    try require(flow.screen == .gameComplete, "finishing the last rank should end the game")
    flow.acknowledgeGameComplete()
    try require(flow.screen == .title, "the game should return to the title")
    print("PASS ranks complete in order and the game ends")
}

private func testResumeAtFurthest() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 1, total: 10)
    flow.acknowledgeResults()   // now on level 2 of Fun
    flow.abandonLevel()
    try require(flow.screen == .rankSelect, "abandoning should return to the ranks")

    flow.selectRank(0)
    try require(
        flow.screen == .briefing(level: 1),
        "returning to a rank should resume at the furthest level reached")
    print("PASS a rank resumes where it was left")
}

private func testLevelUnlocksFollowProgress() throws {
    var flow = makeFlow()
    try require(flow.isLevelUnlocked(0), "the first Fun level should start unlocked")
    try require(!flow.isLevelUnlocked(1), "the second Fun level should start locked")
    try require(flow.isLevelUnlocked(3), "the first Tricky level should start unlocked")
    try require(!flow.isLevelUnlocked(4), "the second Tricky level should start locked")
    try require(!flow.isLevelUnlocked(-1) && !flow.isLevelUnlocked(99),
        "a level outside the campaign should not be unlocked")

    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 1, total: 10)
    flow.acknowledgeResults()
    try require(flow.isLevelUnlocked(1), "passing Fun 1 did not unlock Fun 2")
    try require(!flow.isLevelUnlocked(2), "progress unlocked a level beyond the furthest reached")

    var restored = makeFlow()
    restored.restore(.init(
        furthestReached: ["Fun": 2, "Tricky": 1],
        passed: ["Fun#0", "Fun#1", "Tricky#0"]))
    try require([0, 1, 2, 3, 4].allSatisfy(restored.isLevelUnlocked),
        "restored progress did not unlock each reached level")
    print("PASS direct selection follows the player's restored campaign progress")
}

private func testSequenceResultDoesNotChangeCampaignProgress() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectLevel(rank: 0, position: 1, recordsCampaignProgress: false)
    flow.beginPlaying()
    flow.finishLevel(
        saved: 10,
        required: 1,
        total: 10,
        recordsCampaignProgress: false)

    try require(!flow.hasPassed(rank: "Fun", position: 0),
        "a playlist result changed Classic campaign progress")
    try require(!flow.hasPassed(rank: "Fun", position: 1),
        "a playlist result recorded its selected Classic level")
    try require(!flow.isLevelUnlocked(1),
        "selecting a playlist level changed Classic campaign reach")
    print("PASS playlist results stay separate from Classic campaign progress")
}

private func testUnlockOverrideDoesNotPersistCampaignReach() throws {
    var flow = makeFlow()
    let savedBeforeSelection = flow.progress
    try require(!flow.isLevelUnlocked(2), "the override fixture level should start locked")

    // The Settings override permits this UI choice. The flow must still receive
    // a non-campaign selection so turning the override off restores the lock.
    flow.selectLevel(rank: 0, position: 2, recordsCampaignProgress: false)
    try require(flow.progress == savedBeforeSelection,
        "opening an override-only level advanced campaign reach")
    flow.beginPlaying()
    flow.finishLevel(
        saved: 0,
        required: 1,
        total: 10,
        recordsCampaignProgress: false)
    flow.acknowledgeResults(recordsCampaignProgress: false)
    try require(flow.progress == savedBeforeSelection,
        "retrying an override-only level advanced campaign reach")

    var restored = makeFlow()
    restored.restore(flow.progress)
    try require(!restored.isLevelUnlocked(2),
        "turning the override off left the skipped level unlocked")
    print("PASS the Classic unlock override does not persist skipped campaign reach")
}

private func testProgressSurvives() throws {
    var flow = makeFlow()
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 1, total: 10)
    flow.acknowledgeResults()
    let saved = flow.progress

    var restored = makeFlow()
    restored.restore(saved)
    try require(
        restored.hasPassed(rank: "Fun", position: 0),
        "a passed level did not survive being saved and restored")
    restored.startGame()
    restored.selectRank(0)
    try require(
        restored.screen == .briefing(level: 1),
        "the restored game did not resume at the right level")
    print("PASS progress survives saving and restoring")
}

private func testQuitIsConfirmed() throws {
    var flow = makeFlow()
    flow.requestQuit()
    try require(flow.screen == .quitConfirm, "quitting should ask first")
    flow.cancelQuit()
    try require(flow.screen == .title, "cancelling should return to the title")
    print("PASS quitting asks before leaving")
}

private func testBuildsFromACampaign(_ directory: URL) throws {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
    let flow = ClassicGameFlow(campaign: campaign)
    try require(flow.ranks.count == 4, "expected four ranks, got \(flow.ranks.count)")
    for rank in flow.ranks {
        try require(
            rank.levelIndices.count == 30,
            "\(rank.name) holds \(rank.levelIndices.count) levels, expected 30")
    }
    let names = flow.ranks.map(\.name).joined(separator: ", ")
    print("PASS built from the real campaign — \(names)")
}

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

do {
    try testTitleToPlaying()
    try testPassingAdvances()
    try testFailingRepeats()
    try testSkipOpensTheNextLevel()
    try testRankAndGameCompletion()
    try testResumeAtFurthest()
    try testLevelUnlocksFollowProgress()
    try testSequenceResultDoesNotChangeCampaignProgress()
    try testUnlockOverrideDoesNotPersistCampaignReach()
    try testProgressSurvives()
    try testQuitIsConfirmed()
    if FileManager.default.fileExists(atPath: directory.path) {
        try testBuildsFromACampaign(directory)
    }
    print("Classic game flow tests passed.")
} catch {
    FileHandle.standardError.write(Data("Game flow tests failed: \(error)\n".utf8))
    exit(1)
}
