import Foundation
import Testing
@testable import NxlvKit

struct LevelPlaylistTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        _ number: Int,
        engine: LevelSourceEngine = .classic,
        pack: String = "pack"
    ) throws -> LevelPlaylistEntry {
        try LevelPlaylistEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!,
            identity: .init(
                engine: engine,
                packID: pack,
                levelID: String(format: "level-%02d", number)),
            catalogueRevision: "catalogue-1",
            sourceRevision: "source-\(number)",
            packNameSnapshot: "Pack \(pack)",
            levelNameSnapshot: "Level \(number)",
            levelNumberSnapshot: number)
    }

    @Test func manualPlaylistKeepsAUniqueOrderedSet() throws {
        let first = try entry(1)
        let second = try entry(2)
        let third = try entry(3)
        var playlist = try LevelPlaylist(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "  Favourites  ",
            entries: [first, second],
            createdAt: date)

        #expect(playlist.name == "Favourites")
        try playlist.add(third, at: 1, updatedAt: date.addingTimeInterval(1))
        #expect(playlist.entries.map(\.identity.levelID) == ["level-01", "level-03", "level-02"])
        #expect(try playlist.move(
            id: first.id, to: 2, updatedAt: date.addingTimeInterval(2)))
        #expect(playlist.entries.map(\.identity.levelID) == ["level-03", "level-02", "level-01"])
        #expect(try playlist.rename(
            "Hard ones", updatedAt: date.addingTimeInterval(3)))
        #expect(try playlist.remove(
            id: second.id, updatedAt: date.addingTimeInterval(4)) == second)
        #expect(playlist.name == "Hard ones")
        #expect(playlist.entries == [third, first])

        #expect(throws: LevelPlaylistError.duplicateEntry) {
            try playlist.add(first, updatedAt: date.addingTimeInterval(5))
        }
        let differentLevel = try entry(4)
        let duplicateID = try LevelPlaylistEntry(
            id: first.id,
            identity: differentLevel.identity,
            catalogueRevision: differentLevel.catalogueRevision,
            sourceRevision: differentLevel.sourceRevision,
            packNameSnapshot: differentLevel.packNameSnapshot,
            levelNameSnapshot: differentLevel.levelNameSnapshot,
            levelNumberSnapshot: differentLevel.levelNumberSnapshot)
        #expect(throws: LevelPlaylistError.duplicateEntry) {
            try playlist.add(duplicateID, updatedAt: date.addingTimeInterval(5))
        }
        let roundTrip = try JSONDecoder().decode(
            LevelPlaylist.self,
            from: JSONEncoder().encode(playlist))
        #expect(roundTrip == playlist)
        #expect(throws: LevelPlaylistError.invalidIndex) {
            try playlist.move(
                id: first.id, to: 2, updatedAt: date.addingTimeInterval(5))
        }
    }

    @Test func playlistAndDisplaySnapshotsRoundTrip() throws {
        let original = try LevelPlaylist(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "My route",
            entries: [try entry(1), try entry(2, engine: .lemmings2, pack: "beach")],
            createdAt: date,
            updatedAt: date.addingTimeInterval(10))

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(LevelPlaylist.self, from: data)

        #expect(restored == original)
        #expect(restored.entries[1].packNameSnapshot == "Pack beach")
        #expect(restored.entries[1].levelNameSnapshot == "Level 2")
        #expect(restored.entries[1].catalogueRevision == "catalogue-1")
        #expect(restored.entries[1].sourceRevision == "source-2")
    }

    @Test func malformedSavedValuesAreRejected() throws {
        #expect(throws: LevelPlaylistError.invalidEntry) {
            try LevelPlaylistEntry(
                identity: .init(engine: .classic, packID: "pack", levelID: "level"),
                catalogueRevision: "catalogue",
                sourceRevision: "",
                packNameSnapshot: "Pack",
                levelNameSnapshot: "Level",
                levelNumberSnapshot: 1)
        }
        #expect(throws: LevelPlaylistError.invalidName) {
            try LevelPlaylist(name: "   ", createdAt: date)
        }
        #expect(throws: LevelPlaylistError.invalidPool) {
            try LevelPool(id: "", summary: "All levels")
        }

        let valid = try LevelPlaylist(name: "Valid", entries: [try entry(1)], createdAt: date)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        let encodedEntries = try #require(object["entries"] as? [Any])
        object["entries"] = encodedEntries + encodedEntries
        let duplicateData = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: LevelPlaylistError.invalidEntry) {
            try JSONDecoder().decode(LevelPlaylist.self, from: duplicateData)
        }
    }

    @Test func shuffleUsesOneStableCanonicalOrder() throws {
        let candidates = try (1...12).reversed().map { try entry($0) }
        let algorithm = LevelShuffleAlgorithm.splitMix64FisherYatesV1
        let first = try algorithm.ordered(candidates, seed: 0x1234_5678_9ABC_DEF0)
        let second = try algorithm.ordered(
            Array(candidates.reversed()), seed: 0x1234_5678_9ABC_DEF0)

        #expect(first.map(\.identity.levelID) == second.map(\.identity.levelID))
        #expect(first.map(\.identity.levelID) == [
            "level-05", "level-12", "level-02", "level-06", "level-03", "level-08",
            "level-11", "level-07", "level-01", "level-04", "level-10", "level-09",
        ])
        #expect(Set(first.map(\.identity)).count == candidates.count)
    }

    @Test func randomTenAndFullShuffleNeverRepeat() throws {
        let pool = try LevelPool(
            id: "fan:all-playable",
            summary: "All playable fan levels")
        let candidates = try (1...14).map { try entry($0) }
        let random = try LevelSequenceRun.randomTen(
            from: candidates,
            pool: pool,
            seed: 44,
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            createdAt: date)
        let shuffled = try LevelSequenceRun.fullShuffle(
            from: candidates,
            pool: pool,
            seed: 44,
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            createdAt: date)

        #expect(random.entries.count == 10)
        #expect(Set(random.entries.map(\.identity)).count == 10)
        #expect(random.source == .randomTen)
        #expect(random.seed == 44)
        #expect(random.algorithm == .splitMix64FisherYatesV1)
        #expect(shuffled.entries.count == candidates.count)
        #expect(Set(shuffled.entries.map(\.identity)).count == candidates.count)
        #expect(shuffled.source == .shuffleAll)

        let small = try LevelSequenceRun.randomTen(
            from: Array(candidates.prefix(4)), pool: pool, seed: 44, createdAt: date)
        #expect(small.entries.count == 4)
        #expect(Set(small.entries.map(\.identity)).count == 4)
    }

    @Test func randomTenCanCreateAnEditablePlaylist() throws {
        let candidates = try (1...14).map { try entry($0) }
        let first = try LevelPlaylist.randomTen(
            name: "Random 10", candidates: candidates, seed: 99, createdAt: date)
        let second = try LevelPlaylist.randomTen(
            name: "Random 10", candidates: Array(candidates.reversed()),
            seed: 99, createdAt: date)

        #expect(first.entries.count == 10)
        #expect(first.entries.map(\.identity) == second.entries.map(\.identity))
        #expect(Set(first.entries.map(\.identity)).count == 10)
    }

    @Test func activeRunRetainsItsSnapshotAndPosition() throws {
        let pool = try LevelPool(id: "playlist:test", summary: "Test playlist")
        let first = try entry(1)
        let second = try entry(2)
        var playlist = try LevelPlaylist(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: "Test",
            entries: [first, second],
            createdAt: date)
        var run = try LevelSequenceRun.playlist(
            playlist,
            pool: pool,
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
            createdAt: date)

        try playlist.add(try entry(3), updatedAt: date.addingTimeInterval(1))
        #expect(run.entries == [first, second])
        #expect(run.currentEntry == first)
        let didAdvance = run.advance()
        #expect(didAdvance)
        #expect(run.currentEntry == second)
        #expect(run.isAtEnd)
        let didAdvancePastEnd = run.advance()
        #expect(!didAdvancePastEnd)

        let restored = try JSONDecoder().decode(
            LevelSequenceRun.self,
            from: JSONEncoder().encode(run))
        #expect(restored == run)
        #expect(restored.pool == pool)
        #expect(restored.source == .playlist(playlist.id))
    }

    @Test func generatedSequencesRejectEmptyAndDuplicatePools() throws {
        let pool = try LevelPool(id: "fan:pack", summary: "One fan pack")
        #expect(throws: LevelPlaylistError.emptyPool) {
            try LevelSequenceRun.fullShuffle(
                from: [], pool: pool, seed: 1, createdAt: date)
        }
        let candidate = try entry(1)
        #expect(throws: LevelPlaylistError.duplicateEntry) {
            try LevelSequenceRun.randomTen(
                from: [candidate, candidate], pool: pool, seed: 1, createdAt: date)
        }
    }
}
