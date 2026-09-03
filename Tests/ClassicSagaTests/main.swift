import Foundation
import NxlvKit

// The saga chains the releases into one canon. Ordering, identification and
// chapter advancement are all testable without any game data present.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func makeFlow(levels: Int, rankSize: Int = 2) -> ClassicGameFlow {
    var ranks: [ClassicRank] = []
    var index = 0
    var rankNumber = 1
    while index < levels {
        let count = min(rankSize, levels - index)
        ranks.append(ClassicRank(
            name: "Rank\(rankNumber)", levelIndices: Array(index..<(index + count))))
        index += count
        rankNumber += 1
    }
    return ClassicGameFlow(ranks: ranks)
}

private func chapter(_ title: ClassicTitle, levels: Int) -> ClassicSagaChapter {
    ClassicSagaChapter(
        title: title, storageKey: title.rawValue, flow: makeFlow(levels: levels))
}

private func testIdentification() throws {
    try require(
        ClassicTitle.identify(levelPrefix: "LEVEL", levelCount: 120, folderName: "lemming1.pc")
            == .lemmings,
        "retail Lemmings was not identified")
    try require(
        ClassicTitle.identify(levelPrefix: "DLVEL", levelCount: 100, folderName: "ohno")
            == .ohNoMoreLemmings,
        "Oh No! was not identified")
    try require(
        ClassicTitle.identify(
            levelPrefix: "LEVEL", levelCount: 32, folderName: "HolidayLemmings1993")
            == .holidayLemmings1993,
        "Holiday 1993 was not identified")
    try require(
        ClassicTitle.identify(
            levelPrefix: "LEVEL", levelCount: 4, folderName: "xmas_lemmings_1991")
            == .xmasLemmings1991,
        "Xmas 1991 was not identified")
    print("PASS releases are told apart by prefix, level count and folder name")
}

private func testCanonOrder() throws {
    // Deliberately out of order, to prove the saga sorts them.
    let saga = ClassicSaga(chapters: [
        chapter(.holidayLemmings1994, levels: 4),
        chapter(.lemmings, levels: 4),
        chapter(.ohNoMoreLemmings, levels: 4),
        chapter(.xmasLemmings1991, levels: 2),
    ])
    let order = saga.chapters.map(\.title)
    try require(
        order == [.lemmings, .xmasLemmings1991, .ohNoMoreLemmings, .holidayLemmings1994],
        "the saga did not sort into release order, got \(order.map(\.rawValue))")
    try require(saga.currentChapter?.title == .lemmings, "the saga should open on the first title")
    print("PASS chapters sort into release order, festive titles among them")
}

private func testChapterAdvance() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 2),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    try require(!saga.isFinalChapter, "the first of two should not be the last")
    try require(saga.advanceChapter(), "advancing from the first chapter failed")
    try require(saga.currentChapter?.title == .ohNoMoreLemmings, "did not move to the next title")
    try require(saga.isFinalChapter, "the second of two should be the last")
    try require(!saga.advanceChapter(), "advancing past the last chapter should fail")
    print("PASS finishing a title carries on to the next, and stops at the end")
}

private func testStartAnywhere() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 4),
        chapter(.ohNoMoreLemmings, levels: 4),
        chapter(.holidayLemmings1993, levels: 4),
    ])
    saga.selectChapter(2)
    try require(
        saga.currentChapter?.title == .holidayLemmings1993,
        "choosing a chapter directly did not work")

    // And inside a chapter, any rating and level.
    guard var flow = saga.currentFlow else {
        throw Failure(description: "the chosen chapter has no flow")
    }
    flow.selectLevel(rank: 1, position: 0)
    saga.updateCurrentFlow(flow)
    try require(
        saga.currentFlow?.currentRank?.name == "Rank2",
        "jumping to a rating inside a chapter did not work")
    print("PASS a player can start at any title, rating or level")
}

private func testCompletionCounts() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 4),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    try require(saga.completion.total == 6, "expected 6 levels, got \(saga.completion.total)")
    try require(saga.completion.passed == 0, "a fresh saga should have nothing passed")

    guard var flow = saga.currentFlow else {
        throw Failure(description: "no flow")
    }
    flow.startGame()
    flow.selectRank(0)
    flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 1, total: 10)
    saga.updateCurrentFlow(flow)
    try require(
        saga.completion.passed == 1,
        "passing one level gave \(saga.completion.passed)")
    print("PASS progress counts across the whole series")
}

do {
    try testIdentification()
    try testCanonOrder()
    try testChapterAdvance()
    try testStartAnywhere()
    try testCompletionCounts()
    print("Classic saga tests passed.")
} catch {
    FileHandle.standardError.write(Data("Saga tests failed: \(error)\n".utf8))
    exit(1)
}
