import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

struct StarterPlaylistCatalogueTests {
    @Test func holidayFunCoversEachFirstRankInReleaseOrder() throws {
        let route = try #require(StarterPlaylistCatalogue.routes.first { $0.key == "holiday-fun" })
        let expected = [
            ("xmasLemmings1991-LEVEL-4", "Xmas", 4),
            ("xmasLemmings1992-LEVEL-4", "Xmas", 4),
            ("holidayLemmings1993-MACLEVL-32", "Flurry", 16),
            ("holidayLemmings1994-MACLEVL-32", "Frost", 16),
        ]
        let levels = route.identities[...]
        #expect(route.kind == .collection)
        #expect(levels.count == 40)
        var first = 0
        for (pack, rank, count) in expected {
            let identities = Array(levels.dropFirst(first).prefix(count))
            #expect(identities.map(\.packID) == Array(repeating: pack, count: count))
            #expect(identities.map { Array($0.levelID.split(separator: ":").dropFirst().prefix(2)).joined(separator: ":") }
                == (1...count).map { "\(rank):\($0)" })
            first += count
        }
        #expect(levels.first { $0.packID == "holidayLemmings1993-MACLEVL-32" }?.levelID == "0:Flurry:1:4:0")
        #expect(levels.last?.levelID == "15:Frost:16:1:7")
    }

    @Test func presetsResolveCompleteRoutesAndKeepTinyJourneysShort() throws {
        let routes = StarterPlaylistCatalogue.routes
        #expect(Set(routes.map(\.id)).count == routes.count)
        #expect(Set(routes.map(\.poolID)).count == routes.count)
        #expect(routes.count { $0.kind == .tinyJourney } >= 3)
        for route in routes {
            #expect(route.kind != .tinyJourney || (3...5).contains(route.identities.count))
            let entries = try entries(for: route)
            let missing = try #require(route.identities.last)
            #expect(route.playlist { $0 == missing ? nil : entries[$0] } == nil)
            let playlist = try #require(route.playlist { entries[$0] })
            #expect(playlist.id == route.id)
            #expect(playlist.entries.map(\.identity) == route.identities)
        }
    }

    @Test func lockedEligibilityRequiresTheBuiltInSnapshotAndOriginalOrder() throws {
        let route = try #require(StarterPlaylistCatalogue.routes.first { $0.key == "first-shift" })
        let entries = try entries(for: route)
        let playlist = try #require(route.playlist { entries[$0] })
        let run = try route.run(playlist: playlist)
        let entry = try #require(playlist.entries.last)
        #expect(StarterPlaylistCatalogue.permitsLocked(entry, in: run))

        let reversed = try LevelSequenceRun(source: run.source, pool: run.pool, entries: Array(run.entries.reversed()))
        #expect(!StarterPlaylistCatalogue.permitsLocked(entry, in: reversed))
        let wrongSource = try LevelSequenceRun(source: .playlist(UUID()), pool: run.pool, entries: run.entries)
        #expect(!StarterPlaylistCatalogue.permitsLocked(entry, in: wrongSource))
        let shuffled = try LevelSequenceRun.playlist(playlist, pool: run.pool, seed: 3)
        #expect(!StarterPlaylistCatalogue.permitsLocked(entry, in: shuffled))
    }

    @Test @MainActor func replayingPresetStoresOnePlaylistAndTwoIndependentRuns() throws {
        let storage = try AppStorage.temporary(named: "starter-playlist-runs")
        defer { storage.removeTemporaryFiles() }
        let store = try LevelPlaylistStore(profileID: "owner", storage: storage)
        let route = try #require(StarterPlaylistCatalogue.routes.first { $0.key == "first-shift" })
        let firstEntries = try entries(for: route)
        let firstPlaylist = try #require(route.playlist { firstEntries[$0] })
        let firstRun = try route.run(playlist: firstPlaylist)
        try store.startRun(firstRun, hotSeatID: "family", registering: firstPlaylist)
        #expect(try store.advanceActiveRun())
        let advancedFirst = try #require(store.activeRun)

        let secondEntries = try entries(for: route)
        let secondPlaylist = try #require(route.playlist { secondEntries[$0] })
        let secondRun = try route.run(playlist: secondPlaylist)
        try store.startRun(secondRun, hotSeatID: nil, registering: secondPlaylist)

        let reopened = try LevelPlaylistStore(profileID: "owner", storage: storage)
        #expect(reopened.playlists.map(\.id) == [route.id])
        #expect(reopened.selectedPlaylistID == nil)
        #expect(reopened.activeRun == secondRun)
        #expect(reopened.activeRunHotSeatID == nil)
        #expect(reopened.resumableRun(id: firstRun.id)?.run == advancedFirst)
        #expect(reopened.resumableRun(id: firstRun.id)?.hotSeatID == "family")
    }

    private func entries(for route: StarterPlaylistRoute) throws -> [LevelCatalogueIdentity: LevelPlaylistEntry] {
        try Dictionary(uniqueKeysWithValues: route.identities.enumerated().map { index, identity in
            (identity, try LevelPlaylistEntry(identity: identity, catalogueRevision: "catalogue", sourceRevision: "source",
                packNameSnapshot: identity.packID, levelNameSnapshot: "Puzzle \(index + 1)", levelNumberSnapshot: index + 1))
        })
    }
}
