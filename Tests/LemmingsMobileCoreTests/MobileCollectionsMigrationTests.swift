import Foundation
import Testing
import LemmingsAppCore
import NxlvKit
@testable import LemmingsMobileCore

@MainActor struct MobileCollectionsMigrationTests {
    @Test func testMobileCollectionsMigrateToActiveProfile() throws {
        let storage = try AppStorage.temporary(named: "mobile-migration")
        defer { storage.removeTemporaryFiles() }
        let mobile = MobileStorage(directory: storage.applicationSupport.appendingPathComponent("Mobile/default"))
        let entries: [MobileFavourites.Entry] = [.init(pack: "release/lemmings", level: "0", title: "Just dig"),
                                               .init(pack: "fan/test", level: "rank/2", title: "A fan level")]
        storage.defaults.set(try JSONEncoder().encode(entries), forKey: MobileFavourites.defaultsKey)
        storage.defaults.set(try JSONEncoder().encode(entries.reversed().map { $0 }), forKey: MobileRecents.defaultsKey)
        var lists = MobilePlaylistStore()
        let createdID = lists.create(name: "My levels", entries: entries)
        let id = try #require(createdID)
        _ = lists.startRun(id, shuffle: true, seed: 1997)
        lists.advance(to: 1)
        let bytes = try JSONEncoder().encode(lists)
        storage.defaults.set(bytes, forKey: MobilePlaylistStore.defaultsKey)
        let bridge = try MobileCollectionsBridge(profileID: "default", appStorage: storage, mobileStorage: mobile)
        #expect(bridge.store.favourites.map(\.identity.levelID) == entries.map(\.level))
        #expect(bridge.store.recentlyPlayed.map(\.identity.levelID) == entries.reversed().map(\.level))
        #expect(bridge.store.playlists.first?.id == id)
        #expect(bridge.store.playlists.first?.entries.map(\.identity.levelID) == entries.map(\.level))
        #expect(bridge.playlists.run == lists.run)
        #expect(storage.defaults.data(forKey: MobilePlaylistStore.defaultsKey) == bytes)
        let runID = bridge.store.activeRun?.id
        try bridge.save(favourites: bridge.favourites, recents: bridge.recents, playlists: bridge.playlists)
        let reopened = try MobileCollectionsBridge(profileID: "default", appStorage: storage, mobileStorage: mobile)
        #expect(reopened.store.activeRun?.id == runID)
        #expect(reopened.playlists.run?.position == 1)
        let other = try MobileCollectionsBridge(profileID: "other", appStorage: storage,
            mobileStorage: .init(directory: storage.applicationSupport.appendingPathComponent("Mobile/other")))
        #expect(other.store.favourites.isEmpty && other.store.playlists.isEmpty)
    }

    @Test func soloAndSharedQueuesRecallTheirOwnOrderPositionAndSeed() throws {
        let storage = try AppStorage.temporary(named: "mobile-session-recall")
        defer { storage.removeTemporaryFiles() }
        let mobile = MobileStorage(directory: storage.applicationSupport.appendingPathComponent("Mobile/eri"))
        let bridge = try MobileCollectionsBridge(profileID: "eri", appStorage: storage, mobileStorage: mobile)
        let entries = (0..<4).map { MobileFavourites.Entry(pack: "release/lemmings", level: String($0), title: "Level \($0)") }
        var solo = MobilePlaylistStore()
        let created = solo.create(name: "My levels", entries: entries)
        let id = try #require(created)
        _ = solo.startRun(id, shuffle: true, seed: 1997); solo.advance(to: 2)
        try bridge.save(favourites: .init(), recents: .init(), playlists: solo)
        var shared = bridge.playlists(hotSeatID: "eri-vs-uva")
        #expect(shared.run == nil)
        _ = shared.startRun(id, shuffle: true, seed: 2026); shared.advance(to: 1)
        try bridge.save(favourites: bridge.favourites, recents: bridge.recents, playlists: shared, hotSeatID: "eri-vs-uva")
        let reopened = try MobileCollectionsBridge(profileID: "eri", appStorage: storage, mobileStorage: mobile)
        #expect(reopened.playlists(hotSeatID: nil).run == solo.run)
        #expect(reopened.playlists(hotSeatID: "eri-vs-uva").run == shared.run)
        #expect(reopened.playlists(hotSeatID: "other").run == nil)
        try reopened.save(favourites: reopened.favourites, recents: reopened.recents,
            playlists: reopened.playlists(hotSeatID: nil))
        #expect(reopened.playlists(hotSeatID: "eri-vs-uva").run == shared.run)
        #expect(reopened.store.savedRuns.count == 1)
        var finished = reopened.playlists(hotSeatID: "eri-vs-uva"); finished.endRun()
        try reopened.save(favourites: reopened.favourites, recents: reopened.recents, playlists: finished, hotSeatID: "eri-vs-uva")
        #expect(reopened.playlists(hotSeatID: nil).run == solo.run)
        #expect(reopened.playlists(hotSeatID: "eri-vs-uva").run == nil)
    }

    @Test func oldProfileDocumentKeepsItsIDAndDefaultPortrait() throws {
        let data = Data(#"{"players":[{"id":"default","name":"Player 1"},{"id":"same-initials","name":"Player 1"}],"activeID":"same-initials"}"#.utf8)
        let profiles = try JSONDecoder().decode(MobileProfiles.self, from: data)
        #expect(profiles.activeID == "same-initials")
        #expect(profiles.players.map(\.id) == ["default", "same-initials"])
        #expect(profiles.players.allSatisfy { $0.portrait == 0 })
    }
}
