import Foundation
import NxlvKit

// Walks the whole chain the way a player does: find the installed games, pick
// the quest, take the first rating, read the briefing, play the level with a
// real solution, win it, and carry on to the next one.
//
// Unit tests cover each part. This checks they are actually joined together.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private let directories = Array(CommandLine.arguments.dropFirst())

do {
    try require(!directories.isEmpty, "pass one or more game directories")

    // 1. Find what is installed.
    var chapters: [ClassicSagaChapter] = []
    var sets: [ClassicDataSet] = []
    for path in directories {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard let set = try? ClassicDataSet.detect(directory: url) else { continue }
        guard let title = ClassicTitle.identify(
            levelPrefix: set.levelFilePrefix,
            levelCount: set.campaign.levels.count,
            folderName: url.lastPathComponent) else { continue }
        sets.append(set)
        chapters.append(ClassicSagaChapter(
            title: title, storageKey: set.identifierKey,
            flow: ClassicGameFlow(campaign: set.campaign)))
    }
    try require(!chapters.isEmpty, "no installed games were recognised")
    var saga = ClassicSaga(chapters: chapters)
    let overall = saga.completion
    print("PASS found \(saga.chapters.count) games, \(overall.total) levels")

    // 2. Choose the quest from the launch screen.
    let entries = saga.launchEntries()
    try require(entries.first?.mode == .fullQuest, "the quest was not offered first")
    saga.start(.fullQuest)
    guard var flow = saga.currentFlow, let chapter = saga.currentChapter else {
        throw Failure(description: "the quest did not open a game")
    }
    print("PASS quest started on \(chapter.title.displayName)")

    // 3. Title, then rating, then briefing.
    flow.startGame()
    try require(flow.screen == .rankSelect, "starting did not offer the ratings")
    flow.selectRank(0)
    guard case let .briefing(levelIndex) = flow.screen else {
        throw Failure(description: "choosing a rating did not brief a level")
    }
    guard let set = sets.first(where: { $0.identifierKey == chapter.storageKey }) else {
        throw Failure(description: "the chosen game is missing")
    }
    let entry = set.campaign.levels[levelIndex]
    print("PASS briefing \(entry.rank) \(entry.number)")

    // 4. Build the level exactly as the app does.
    let directory = URL(fileURLWithPath: directories[0], isDirectory: true)
    let ground = try ClassicGroundSet.load(style: entry.level.groundStyle, from: directory)
    let special = entry.level.specialStyle > 0
        ? try? ClassicSpecialGraphic.load(index: entry.level.specialStyle - 1, from: directory)
        : nil
    let rendered = try ClassicLevelRenderer.render(
        entry.level, groundSet: ground, specialGraphic: special)
    let assets = try ClassicMainDATAssets.load(from: directory)
    let simulation = try ClassicDOSSimulation(
        level: entry.level, renderedLevel: rendered, mainDATAssets: assets)
    flow.beginPlaying()
    try require(flow.screen.isPlaying, "the level did not start")
    print("PASS level built and running")

    // 5. Play it with the known solution, through the rewind wrapper the app uses.
    var session = ClassicDOSRewind(simulation: simulation)
    var heardSounds = Set<ClassicSoundEffect>()
    var assigned = false
    for _ in 0..<(ClassicDOSRules.ticksPerSecond * 120) {
        let events = session.tick()
        heardSounds.formUnion(ClassicSoundCue.cues(for: events))
        if !assigned, session.simulation.tickCount == 60 {
            assigned = session.assign(.digger, to: 0) == .assigned
        }
        if session.simulation.isComplete { break }
    }
    try require(assigned, "the digger was refused")
    try require(session.simulation.isComplete, "the level never finished")
    try require(session.simulation.didWin, "the level was not won")
    print("PASS level won, \(session.simulation.savedCount)"
        + "/\(session.simulation.configuration.requiredToSave) saved")
    try require(!heardSounds.isEmpty, "the level produced no sound cues")
    print("PASS \(heardSounds.count) kinds of sound were asked for while playing")

    // 6. Results, then on to the next level.
    flow.finishLevel(
        saved: session.simulation.savedCount,
        required: session.simulation.configuration.requiredToSave,
        total: session.simulation.configuration.totalLemmings)
    guard case .results = flow.screen else {
        throw Failure(description: "finishing did not show a result")
    }
    flow.acknowledgeResults()
    guard case let .briefing(next) = flow.screen else {
        throw Failure(description: "the result did not lead to the next level")
    }
    try require(next != levelIndex, "the next briefing is the same level")
    try require(flow.hasPassed(rank: entry.rank, position: 0), "the win was not recorded")
    print("PASS advanced to the next level, progress recorded")

    // 7. Progress survives being saved and reloaded.
    saga.updateCurrentFlow(flow)
    let stored = flow.progress
    var reloaded = ClassicGameFlow(campaign: set.campaign)
    reloaded.restore(stored)
    try require(
        reloaded.hasPassed(rank: entry.rank, position: 0),
        "progress did not survive a save and reload")
    print("PASS progress survives a restart")

    print("Play-through tests passed.")
} catch {
    FileHandle.standardError.write(Data("Play-through failed: \(error)\n".utf8))
    exit(1)
}
