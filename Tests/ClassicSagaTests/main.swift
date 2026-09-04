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

    // Both festive demos are labelled 1991 by the archives, one as an
    // alternate, yet they hold different levels. Without the variant marker
    // they would claim the same chapter and one set would disappear.
    let plain = ClassicTitle.identify(
        levelPrefix: "LEVEL", levelCount: 4, folderName: "xmas_dos_XmasLemmingsV1.9")
    let alternate = ClassicTitle.identify(
        levelPrefix: "LEVEL", levelCount: 4, folderName: "xmas_dos_XmasLemmingsV1.9a1")
    try require(plain != nil, "the undated festive demo was not identified")
    try require(alternate != nil, "the alternate festive demo was not identified")
    try require(
        plain != alternate,
        "both festive demos claimed the same chapter, so one level set is lost")
    try require(
        ClassicTitle.identify(
            levelPrefix: "LEVEL", levelCount: 120, folderName: "Lemmings 2 - The Tribes")
            == .lemmings2TheTribes,
        "Lemmings 2 was not identified")
    try require(
        ClassicTitle.identify(
            levelPrefix: "LEVEL", levelCount: 90, folderName: "Lemmings Chronicles")
            == .lemmings3TheChronicles,
        "Lemmings 3 was not identified")
    print("PASS releases are told apart by prefix, level count and folder name")
}

private func testCanonOrder() throws {
    // Deliberately out of order, to prove the saga sorts them.
    let saga = ClassicSaga(chapters: [
        chapter(.holidayLemmings1994, levels: 4),
        chapter(.lemmings3TheChronicles, levels: 4),
        chapter(.xmasLemmings1992, levels: 2),
        chapter(.lemmings, levels: 4),
        chapter(.lemmings2TheTribes, levels: 4),
        chapter(.holidayLemmings1993, levels: 4),
        chapter(.ohNoMoreLemmings, levels: 4),
        chapter(.xmasLemmings1991, levels: 2),
    ])
    let order = saga.chapters.map(\.title)
    try require(
        order == [
            .lemmings, .xmasLemmings1991, .ohNoMoreLemmings,
            .xmasLemmings1992, .lemmings2TheTribes, .holidayLemmings1993,
            .lemmings3TheChronicles, .holidayLemmings1994,
        ],
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

private func testOrderedAchievements() throws {
    var progress = ClassicAchievementProgress()

    let jumped = progress.recordWin(title: .lemmings, levelIndex: 1, levelCount: 2)
    try require(
        jumped.map(\.id) == [.firstRescue],
        "a practice jump should only unlock the first-level achievement")
    try require(
        progress.orderedLevelsPassed(for: .lemmings) == 0,
        "a practice jump advanced ordered progress")

    _ = progress.recordWin(title: .lemmings, levelIndex: 0, levelCount: 2)
    let completed = progress.recordWin(title: .lemmings, levelIndex: 1, levelCount: 2)
    try require(
        completed.map(\.id) == [.lemmingsComplete],
        "passing a release in order did not unlock its achievement")
    print("PASS achievements require levels to be passed in order")
}

private func testMetaAchievements() throws {
    var progress = ClassicAchievementProgress()
    var lastEarned: [ClassicAchievement] = []
    for title in ClassicTitle.allCases {
        lastEarned = progress.recordWin(title: title, levelIndex: 0, levelCount: 1)
    }
    try require(
        progress.isUnlocked(.festiveComplete),
        "completing the four festive releases did not unlock their award")
    try require(
        progress.isUnlocked(.trilogyComplete),
        "completing Lemmings 1-3 did not unlock the trilogy award")
    try require(
        lastEarned.contains(where: { $0.id == .fullCanonComplete }),
        "completing every release did not unlock the full-canon award")
    print("PASS festive, trilogy and full-canon achievements unlock")
}

private func testFullCanonMustBeInOrder() throws {
    var progress = ClassicAchievementProgress()
    for title in ClassicTitle.allCases.reversed() {
        _ = progress.recordWin(title: title, levelIndex: 0, levelCount: 1)
    }
    try require(
        !progress.isUnlocked(.fullCanonComplete),
        "finishing releases out of order unlocked the full-canon award")
    print("PASS the full-canon achievement requires canon order")
}


private func testLaunchEntries() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 4),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    var entries = saga.launchEntries()
    try require(
        entries.count == 3, "expected the quest plus two titles, got \(entries.count)")
    try require(entries[0].mode == .fullQuest, "the quest should be offered first")
    try require(entries[0].total == 6, "the quest should span every level")
    try require(entries.allSatisfy { !$0.isStarted }, "a fresh saga shows nothing started")

    // Pass one level and the numbers should follow.
    guard var flow = saga.currentFlow else { throw Failure(description: "no flow") }
    flow.startGame(); flow.selectRank(0); flow.beginPlaying()
    flow.finishLevel(saved: 10, required: 1, total: 10)
    saga.updateCurrentFlow(flow)

    entries = saga.launchEntries()
    try require(entries[0].passed == 1, "the quest total did not follow a passed level")
    try require(entries[1].passed == 1, "the title total did not follow a passed level")
    try require(entries[1].percent == 25, "one of four should read 25 percent")
    print("PASS the launch screen offers the quest and each title with its progress")
}

private func testQuestResumesAtUnfinished() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 2),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    // Finish the first title outright.
    guard var flow = saga.currentFlow else { throw Failure(description: "no flow") }
    flow.startGame(); flow.selectRank(0)
    for _ in 0..<2 {
        flow.beginPlaying()
        flow.finishLevel(saved: 10, required: 1, total: 10)
        flow.acknowledgeResults()
    }
    saga.updateCurrentFlow(flow)

    saga.selectChapter(0)
    saga.start(.fullQuest)
    try require(
        saga.currentChapter?.title == .ohNoMoreLemmings,
        "the quest should resume at the first unfinished title")
    print("PASS the quest resumes rather than restarting")
}

private func testSingleTitleReturnsToLaunch() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 2),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    saga.start(.singleTitle(chapter: 0))
    let outcome = saga.finishChapter(mode: .singleTitle(chapter: 0))
    try require(
        outcome == .returnToLaunch,
        "finishing a single title should return to the launch screen")
    try require(
        saga.currentChapter?.title == .lemmings,
        "a single title should not move on to the next release")
    print("PASS a single title ends at the launch screen")
}

private func testQuestCarriesOnThenCompletes() throws {
    var saga = ClassicSaga(chapters: [
        chapter(.lemmings, levels: 2),
        chapter(.ohNoMoreLemmings, levels: 2),
    ])
    saga.start(.fullQuest)
    let first = saga.finishChapter(mode: .fullQuest)
    try require(
        first == .nextChapter(.ohNoMoreLemmings),
        "the quest should carry on to the next release, got \(first)")
    let second = saga.finishChapter(mode: .fullQuest)
    try require(second == .questComplete, "the quest should end after the last release")
    print("PASS the quest carries on between releases, then ends")
}

do {
    try testIdentification()
    try testCanonOrder()
    try testChapterAdvance()
    try testStartAnywhere()
    try testCompletionCounts()
    try testOrderedAchievements()
    try testMetaAchievements()
    try testFullCanonMustBeInOrder()
    try testLaunchEntries()
    try testQuestResumesAtUnfinished()
    try testSingleTitleReturnsToLaunch()
    try testQuestCarriesOnThenCompletes()
    print("Classic saga tests passed.")
} catch {
    FileHandle.standardError.write(Data("Saga tests failed: \(error)\n".utf8))
    exit(1)
}
