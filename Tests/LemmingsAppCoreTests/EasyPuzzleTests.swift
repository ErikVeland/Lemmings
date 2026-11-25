import Foundation
import NxlvKit
import XCTest
@testable import LemmingsAppCore

final class EasyPuzzleTests: XCTestCase {
    func testSelectionKeepsFamiliarSkillsAndVariesPacks() throws {
        let familiar = try puzzle("1", pack: "pack-a", score: 100, skills: ["builder"])
        let samePack = try puzzle("2", pack: "pack-a", score: 99, skills: ["builder"])
        let newPack = try puzzle("3", pack: "pack-b", score: 105, skills: ["builder"])
        let won = try puzzle("4", pack: "pack-c", score: 80, skills: ["builder"])
        let dismissed = try puzzle("5", pack: "pack-d", score: 70, skills: ["builder"])
        let unrelated = try puzzle("6", pack: "pack-e", score: 90, skills: ["miner"])
        let pool = [familiar, samePack, newPack, won, dismissed, unrelated]
        let order = EasyPuzzleCatalogue.queue(from: pool, familiarSkills: ["builder"],
            excluding: [won.entry.identity, dismissed.entry.identity], seed: 42)
        XCTAssertEqual(Set(order.map(\.identity)), Set([familiar, samePack, newPack, unrelated].map(\.entry.identity)))
        XCTAssertNotEqual(order[0].identity.packID, order[1].identity.packID)
        XCTAssertNotEqual(order.first, unrelated.entry)
        XCTAssertEqual(order, EasyPuzzleCatalogue.queue(from: Array(pool.reversed()), familiarSkills: ["builder"],
            excluding: [won.entry.identity, dismissed.entry.identity], seed: 42))
    }

    @MainActor func testBreakWinSurvivesReopenAndPreservesJourney() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("playlists.json")
        let store = try LevelPlaylistStore(file: file)
        let journeyEntry = try puzzle("1", pack: "campaign", score: 120).entry
        let easy = try puzzle("2", pack: "fan:lldb-9", score: 75).entry
        let following = try puzzle("3", pack: "campaign", score: 160).entry
        let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: "Journey", entries: [journeyEntry, easy, following])
        try store.add(playlist)
        let journey = try LevelSequenceRun.playlist(playlist, pool: LevelPool(id: LearningJourney.version, summary: "Journey"))
        try store.startRun(journey, hotSeatID: "pair")
        let detour = try EasyPuzzleCatalogue.run(entries: [easy])
        try store.startRun(detour, hotSeatID: "pair")
        try store.recordLearningWin(runID: detour.id, level: easy.identity)
        let reopened = try LevelPlaylistStore(file: file)
        XCTAssertEqual(reopened.resumableLearningJourney(hotSeatID: "pair")?.run, journey)
        XCTAssertEqual(reopened.learningProgress(hotSeatID: "pair").completed, [easy.identity])
        XCTAssertEqual(reopened.completedLearningEntries(hotSeatID: "pair"), [easy])
        XCTAssertTrue(reopened.learningProgress.completed.isEmpty)
        try reopened.resumeRun(id: journey.id)
        XCTAssertTrue(try reopened.advanceLearningJourney(runID: journey.id, won: true))
        XCTAssertEqual(reopened.activeRun?.currentEntry, following)
    }

    @MainActor func testBreakWinKeepsSourceCreditAfterRepeatedCrossDeviceImport() throws {
        let first = try AppStorage.temporary(named: "easy-source")
        defer { first.removeTemporaryFiles() }
        let second = try AppStorage.temporary(named: "easy-destination")
        defer { second.removeTemporaryFiles() }
        let easy = try puzzle("2", pack: "fan:lldb-9", score: 75).entry
        var progress = LearningJourneyProgress()
        progress.record(easy.identity, won: true)
        try GameProgressPreferences.saveLearning(progress, profileID: "host", sessionID: "pair",
            entries: [easy], defaults: first.defaults)
        let outgoing = GameProgressPreferences.capture(defaults: first.defaults, profileID: "host",
            profileIDs: ["host", "guest"], sessionID: "pair")
        for _ in 0..<2 {
            try outgoing.apply(defaults: second.defaults, profileID: "host", sessionID: "pair")
        }
        XCTAssertEqual(GameProgressPreferences.fanLevels(profileID: "host", sessionID: "pair", defaults: second.defaults),
            ["v2|catalogue:lldb-9|Puzzle 2"])
        XCTAssertEqual(JourneyCompletionSummary.count(profileID: "host", hotSeatID: "pair",
            learning: progress, entries: [easy], defaults: second.defaults), 1)
        XCTAssertTrue(GameProgressPreferences.learning(profileID: "host", defaults: second.defaults).completed.isEmpty)
    }

    private func puzzle(_ number: String, pack: String, score: Int,
                        skills: [String] = ["builder"]) throws -> EasyPuzzleCatalogue.Puzzle {
        let entry = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: pack, levelID: "levels.dat#" + number),
            catalogueRevision: "test", sourceRevision: "test", packNameSnapshot: pack, levelNameSnapshot: "Puzzle " + number,
            levelNumberSnapshot: Int(number)!)
        return .init(entry: entry, score: score, skills: skills)
    }
}
