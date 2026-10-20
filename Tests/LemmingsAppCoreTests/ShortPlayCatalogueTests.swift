import CryptoKit
import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

struct ShortPlayCatalogueTests {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private func entries(_ sequence: ShortPlaySequence) throws -> [LevelPlaylistEntry] {
        try sequence.levels.enumerated().map { index, level in
            try .init(identity: level.identity, catalogueRevision: "test", sourceRevision: level.sourceRevision ?? "current-native-source",
                packNameSnapshot: sequence.title, levelNameSnapshot: "Level \(index + 1)", levelNumberSnapshot: index + 1)
        }
    }

    @Test func openingsPinExactWinningFixturesAndNeverClaimASequelCurriculum() throws {
        #expect(ShortPlayCatalogue.sequences.map(\.engine) == [.classic, .lemmings2, .lemmings3])
        for sequence in ShortPlayCatalogue.sequences {
            #expect(sequence.levels.count == 5)
            #expect(!sequence.poolID.hasPrefix("learning-"))
            for (index, level) in sequence.levels.enumerated() {
                let data = try Data(contentsOf: root.appendingPathComponent(level.fixture))
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                #expect(digest == level.witnessSHA256)
                let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
                if sequence.engine == .classic {
                    let expected = try #require(fixture["expected"] as? [String: Any])
                    #expect(expected["didWin"] as? Bool == true)
                    #expect(level.identity.levelID.hasPrefix("\(index):Fun:\(index + 1):"))
                    #expect(level.sourceRevision?.count == 64)
                } else {
                    #expect(fixture["levelSHA256"] as? String == level.levelSHA256)
                    #expect(level.identity.levelID == "\(index):\(level.levelSHA256!)")
                }
            }
        }
        let l2 = try #require(ShortPlayCatalogue.sequence(id: "lemmings2"))
        var survivors = 60
        for index in 0..<5 {
            let fixturePath = index < 2 ? l2.levels[index].fixture
                : String(format: "Tests/Lemmings2CompletionTests/Chains/classic-%02d.json", index + 1)
            let data = try Data(contentsOf: root.appendingPathComponent(fixturePath))
            let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(fixture["population"] as? Int == survivors)
            #expect(fixture["levelSHA256"] as? String == l2.levels[index].levelSHA256)
            survivors = try #require(fixture["expectedSaved"] as? Int)
            #expect(survivors > 0)
        }
    }

    @Test func lockedEligibilityRequiresEveryExactEntryAndTheOpeningOrder() throws {
        for sequence in ShortPlayCatalogue.sequences where sequence.supportsCarriedSequence {
            let entries = try entries(sequence)
            let playlist = try LevelPlaylist(name: sequence.title, entries: entries)
            let run = try sequence.run(playlist: playlist)
            #expect(entries.allSatisfy { ShortPlayCatalogue.permitsLocked($0, in: run) })
            let arbitrary = try LevelSequenceRun.playlist(playlist, pool: .init(id: "manual", summary: "Manual"))
            #expect(!ShortPlayCatalogue.permitsLocked(entries[0], in: arbitrary))
            let reordered = try LevelSequenceRun(source: run.source, pool: run.pool, entries: Array(entries.reversed()))
            #expect(!ShortPlayCatalogue.permitsLocked(entries[0], in: reordered))
            let shuffled = try LevelSequenceRun(source: run.source, pool: run.pool, entries: entries,
                seed: 1, algorithm: .splitMix64FisherYatesV1)
            #expect(!ShortPlayCatalogue.permitsLocked(entries[0], in: shuffled))
            #expect(sequence.entries(resolving: { identity in
                identity == entries[0].identity ? nil : entries.first { $0.identity == identity }
            }) == nil)
        }
        let classic = try #require(ShortPlayCatalogue.sequence(id: "classic"))
        let changed = try entries(classic).map { entry in
            try LevelPlaylistEntry(identity: entry.identity, catalogueRevision: entry.catalogueRevision,
                sourceRevision: "changed", packNameSnapshot: entry.packNameSnapshot,
                levelNameSnapshot: entry.levelNameSnapshot, levelNumberSnapshot: entry.levelNumberSnapshot)
        }
        #expect(!classic.matches(changed))
        let l3 = try #require(ShortPlayCatalogue.sequence(id: "lemmings3"))
        #expect(!l3.supportsCarriedSequence)
        #expect(throws: LevelPlaylistError.invalidSequence) {
            try l3.run(playlist: LevelPlaylist(name: l3.title, entries: entries(l3)))
        }
    }

    @Test @MainActor func savedOpeningRetainsJourneyOwnershipAndSeparateCarryOver() throws {
        let storage = try AppStorage.temporary(named: "short-play")
        defer { storage.removeTemporaryFiles() }
        let store = try LevelPlaylistStore(profileID: "owner", storage: storage)
        let sequence = try #require(ShortPlayCatalogue.sequence(id: "lemmings2"))
        let playlist = try LevelPlaylist(name: sequence.title, entries: entries(sequence))
        let journey = try LevelPlaylist(id: LearningJourney.playlistID, name: "Journey", entries: [playlist.entries[0]])
        try store.add(journey)
        let journeyRun = try LevelSequenceRun.playlist(journey, pool: .init(id: "learning-test", summary: "Journey"))
        try store.startRun(journeyRun, hotSeatID: "original-seat", l2Progress: ["original": Data([1])])
        try store.add(playlist)
        let run = try sequence.run(playlist: playlist)
        try store.startRun(run, hotSeatID: "short-seat", l2Progress: ["short": Data([2])])
        #expect(store.resumableRun(id: journeyRun.id)?.hotSeatID == "original-seat")
        #expect(store.resumableRun(id: journeyRun.id)?.l2Progress == ["original": Data([1])])
        #expect(store.activeRunHotSeatID == "short-seat")
        #expect(store.activeRunL2Progress == ["short": Data([2])])
        #expect(store.learningProgress.completed.isEmpty)
        #expect(try store.advanceActiveRun())
        let reopened = try LevelPlaylistStore(profileID: "owner", storage: storage)
        #expect(reopened.activeRun?.currentIndex == 1)
        #expect(reopened.activeRunHotSeatID == "short-seat")
        #expect(reopened.activeRunL2Progress == ["short": Data([2])])
        #expect(reopened.resumableRun(id: journeyRun.id)?.run == journeyRun)
    }
}
