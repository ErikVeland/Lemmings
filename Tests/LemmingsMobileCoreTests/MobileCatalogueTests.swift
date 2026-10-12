import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileCatalogueTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let ports = root.appendingPathComponent(".build/ios-ports")
    private static let packs = root.appendingPathComponent("Content/LevelPacks")

    @Test func listsEveryFamilyWithTheRightCounts() throws {
        try #require(FileManager.default.fileExists(atPath: Self.ports.path),
                     "Run Tools/IOSBeta/ports.py --destination .build/ios-ports first.")
        let catalogue = MobileCatalogue(portsRoot: Self.ports, fanFolders: [Self.packs])
        #expect(catalogue.families == [.classic, .ohNo, .holiday, .ohYes, .fan])
        #expect(catalogue.packs(in: .holiday).map(\.title) == [
            "Xmas Lemmings 1991", "Xmas Lemmings 1992", "Holiday Lemmings 1993", "Holiday Lemmings 1994"])
        #expect(catalogue.packs(in: .fan).count > 500)
        #expect(catalogue.pack(forLevelIdentifier: "lemmings-LEVEL-120/Fun/1")?.id == "release/lemmings")
        #expect(catalogue.pack(forLevelIdentifier: "ohYesMoreLemmings-OHYES-60/Mega Drive Sunsoft/3")?.id
                == "release/ohYesMoreLemmings")
        let fan = try #require(catalogue.packs(in: .fan).first)
        #expect(catalogue.pack(forLevelIdentifier: "fan/\(fan.id)/abc/x.dat#1")?.id == fan.id)
    }

    @Test func everyOfficialLevelLoadsRendersAndTicks() throws {
        try #require(FileManager.default.fileExists(atPath: Self.ports.path))
        let catalogue = MobileCatalogue(portsRoot: Self.ports, fanFolders: [])
        var total = 0
        for family in [MobileFamily.classic, .ohNo, .holiday, .ohYes] {
            for pack in catalogue.packs(in: family) {
                let library = try catalogue.library(for: pack)
                if let expected = pack.levelCount { #expect(library.levels.count == expected, "\(pack.title)") }
                for summary in library.levels {
                    let content = try library.loadLevel(at: summary.index)
                    let frame = try content.session.render(highlight: nil)
                    #expect(frame.width > 0 && frame.height > 0, "\(pack.title) \(summary.number)")
                    content.session.tick()
                    // A saved run must find its pack again from the level identity.
                    #expect(catalogue.pack(forLevelIdentifier: content.session.levelIdentifier)?.id == pack.id,
                            "\(pack.title) \(content.session.levelIdentifier)")
                    total += 1
                }
            }
        }
        #expect(total == 120 + 100 + 4 + 4 + 32 + 32 + 60)
    }
}

struct MobileMusicAssignmentTests {
    @Test func tunesFollowTheReleaseAndLevelTitle() {
        let classic = MobileMusicAssignment.tune(identifier: "lemmings-LEVEL-120/Fun/1", index: 0, title: "Just dig!")
        #expect(classic == .init(folder: "lemmings_music_mod", track: "cancan", game: "classic"))
        #expect(MobileMusicAssignment.tune(identifier: "lemmings-LEVEL-120/Fun/2", index: 1, title: "Only floaters").track == "lemming1")
        let ohNo = MobileMusicAssignment.tune(identifier: "ohNoMoreLemmings-DLVEL-100/Tame/1", index: 0, title: "x")
        #expect(ohNo == .init(folder: "oh_no_more_lemmings_music_mod", track: "tune1", game: "ohno"))
        for key in ["xmasLemmings1991", "holidayLemmings1994"] {
            let holiday = MobileMusicAssignment.tune(identifier: key + "-LEVEL-4/All/1", index: 4, title: "x")
            #expect(holiday.folder == "holiday_lemmings_music_mod" && holiday.game == "holiday" && holiday.track == "kw")
        }
        // A fan pack borrows the original rotation, and a special title overrides it.
        #expect(MobileMusicAssignment.tune(identifier: "fan/lldb-1/abc/x.dat#0", index: 2, title: "Hello").game == "classic")
        #expect(MobileMusicAssignment.tune(identifier: "lemmings-LEVEL-120/Mayhem/30", index: 29, title: "The Awesome").track == "awesome")
    }
}

struct MobileFavouritesTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func storesToggleAndRoundTrips() throws {
        let storage = MobileStorage(directory: FileManager.default.temporaryDirectory.appendingPathComponent("fav-" + UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        var favourites = MobileFavourites.load(from: storage, legacy: false)
        #expect(favourites.entries.isEmpty)
        let added = favourites.toggle(pack: "release/lemmings", level: "Fun/1")
        let second = favourites.toggle(pack: "lldb-1", level: "a.dat#0")
        let removed = favourites.toggle(pack: "release/lemmings", level: "Fun/1")
        #expect(added && second && !removed)
        favourites.save(to: storage)
        let loaded = MobileFavourites.load(from: storage, legacy: false)
        #expect(loaded.entries == [.init(pack: "lldb-1", level: "a.dat#0")])
        #expect(loaded.contains(pack: "lldb-1", level: "a.dat#0"))
    }

    @Test func favouritesSpanPacksAndPlayInTheirOwnSession() throws {
        let ports = Self.root.appendingPathComponent(".build/ios-ports")
        try #require(FileManager.default.fileExists(atPath: ports.path))
        let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: [Self.root.appendingPathComponent("Content/LevelPacks")])
        let classic = try catalogue.library(for: try #require(catalogue.pack(id: "release/lemmings")))
        let fanPack = try #require(catalogue.packs(in: .fan).first)
        let fan = try catalogue.library(for: fanPack)
        var favourites = MobileFavourites()
        favourites.toggle(pack: "release/lemmings", level: classic.levelKey(at: 5))
        favourites.toggle(pack: fanPack.id, level: fan.levelKey(at: 1))
        favourites.toggle(pack: "release/missing", level: "x")   // a removed pack is skipped
        let library = MobileFavouritesLibrary(favourites: favourites, catalogue: catalogue)
        #expect(library.levels.count == 2)
        #expect(library.levels[0].title == classic.levels[5].title)
        #expect(library.levels[1].title == fan.levels[1].title)
        #expect(library.origin(of: 1)?.pack == fanPack.id && library.origin(of: 1)?.index == 1)
        for index in 0..<2 {
            let content = try library.loadLevel(at: index)
            _ = try content.session.render(highlight: nil)
            #expect(catalogue.pack(forLevelIdentifier: content.session.levelIdentifier) != nil)
        }
    }
}

struct MobilePlaylistTests {
    private func entry(_ n: Int) -> MobileFavourites.Entry { .init(pack: "p", level: "l\(n)") }

    @Test func recentsKeepFiftyDistinctNewestFirst() {
        var recents = MobileRecents()
        for n in 0..<60 { recents.record(entry(n)) }
        #expect(recents.entries.count == 50 && recents.entries.first == entry(59) && recents.entries.last == entry(10))
        recents.record(entry(30))   // a replay moves to the front
        #expect(recents.entries.first == entry(30) && recents.entries.count == 50
                && recents.entries.filter { $0 == entry(30) }.count == 1)
    }

    @Test func editingKeepsOrderAndRejectsDuplicates() throws {
        var store = MobilePlaylistStore()
        let created = store.create(name: "  ")
        let id = try #require(created)
        #expect(store.playlist(id)?.name == "Playlist")
        let first = store.add(entry(1), to: id), second = store.add(entry(2), to: id)
        let third = store.add(entry(3), to: id), duplicate = store.add(entry(2), to: id)
        #expect(first && second && third && !duplicate)
        store.move(at: 2, by: -2, in: id)
        #expect(store.playlist(id)?.entries == [entry(3), entry(1), entry(2)])
        store.move(at: 0, by: -5, in: id)   // stops at the end
        #expect(store.playlist(id)?.entries.first == entry(3))
        store.remove(at: 1, from: id)
        #expect(store.playlist(id)?.entries == [entry(3), entry(2)])
        store.rename(id, to: "Hard ones")
        #expect(store.playlist(id)?.name == "Hard ones")
        store.delete(id)
        #expect(store.playlists.isEmpty)
    }

    @Test func shuffleIsAPermutationThatRepeatsForASeed() {
        let pool = (0..<40).map(entry)
        let a = MobilePlaylistStore.shuffled(pool, seed: 7), b = MobilePlaylistStore.shuffled(pool, seed: 7)
        let c = MobilePlaylistStore.shuffled(pool, seed: 8)
        #expect(a == b && a != c && a != pool && Set(a) == Set(pool) && a.count == pool.count)
        let ten = MobilePlaylistStore.random(10, from: pool, seed: 3)
        #expect(ten.count == 10 && Set(ten).count == 10 && ten == MobilePlaylistStore.random(10, from: pool, seed: 3))
        #expect(MobilePlaylistStore.random(10, from: Array(pool.prefix(4)), seed: 3).count == 4)
    }

    @Test func runsPersistWithTheirFixedOrder() throws {
        let storage = MobileStorage(directory: FileManager.default.temporaryDirectory.appendingPathComponent("pl-" + UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        var store = MobilePlaylistStore()
        let created = store.create(name: "Run", entries: (0..<6).map(entry))
        let id = try #require(created)
        let started = store.startRun(id, shuffle: true, seed: 42)
        let run = try #require(started)
        #expect(run.entries == MobilePlaylistStore.shuffled((0..<6).map(entry), seed: 42))
        store.advance(to: 3)
        store.save(to: storage)
        let loaded = MobilePlaylistStore.load(from: storage, legacy: false)
        #expect(loaded.run?.position == 3 && loaded.run?.entries == run.entries && loaded.playlists.count == 1)
        var ended = loaded
        ended.advance(to: 99)   // past the end finishes the run
        #expect(ended.run == nil)
        var empty = MobilePlaylistStore()
        let blankID = empty.create(name: "Empty")
        let blank = try #require(blankID)
        let none = empty.startRun(blank, shuffle: false)
        #expect(none == nil)
        // Deleting the playlist removes its saved run.
        var removing = loaded
        removing.delete(id)
        #expect(removing.run == nil && removing.playlists.isEmpty)
    }
}


struct MobileStorageTests {
    private struct Doc: Codable, Equatable { var value: Int }

    private func makeStorage() -> MobileStorage {
        MobileStorage(directory: FileManager.default.temporaryDirectory.appendingPathComponent("store-" + UUID().uuidString))
    }

    @Test func fallsBackToTheBackupAndKeepsTheDamagedFile() throws {
        let storage = makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        try storage.save(Doc(value: 1), name: "doc")
        try storage.save(Doc(value: 2), name: "doc")      // the first copy becomes the backup
        #expect(storage.load(Doc.self, name: "doc") == Doc(value: 2))
        try Data("{broken".utf8).write(to: storage.directory.appendingPathComponent("doc.json"))
        #expect(storage.load(Doc.self, name: "doc") == Doc(value: 1))
        let kept = try FileManager.default.contentsOfDirectory(atPath: storage.directory.path)
        #expect(kept.contains { $0.hasPrefix("doc.invalid-") })
        // A damaged file never overwrites the last good backup.
        try Data("{broken".utf8).write(to: storage.directory.appendingPathComponent("doc.json"))
        try storage.save(Doc(value: 3), name: "doc")
        let backup = try Data(contentsOf: storage.directory.appendingPathComponent("doc.json.bak"))
        #expect(try JSONDecoder().decode(Doc.self, from: backup) == Doc(value: 1))
    }

    @Test func importsOlderDefaultsOnce() throws {
        let storage = makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        let defaults = try #require(UserDefaults(suiteName: "store-test-" + UUID().uuidString))
        defaults.set(try JSONEncoder().encode(Doc(value: 9)), forKey: "legacy")
        #expect(storage.loadMigrating(Doc.self, name: "doc", defaults: defaults, legacyKey: "legacy") == Doc(value: 9))
        #expect(defaults.data(forKey: "legacy") == nil)
        #expect(storage.load(Doc.self, name: "doc") == Doc(value: 9))
    }

    @Test func profilesKeepTheirOwnKeysAndAlwaysHaveOne() {
        var profiles = MobileProfiles()
        #expect(profiles.suffix == "" && profiles.active.name == "Player 1")
        let added = profiles.add(name: "  ", id: "abc")
        #expect(added == "abc")
        profiles.select("abc")
        #expect(profiles.suffix == ".abc" && profiles.active.name == "Player")
        profiles.rename("abc", to: "Sam")
        #expect(profiles.active.name == "Sam")
        profiles.delete("abc")
        #expect(profiles.players.count == 1 && profiles.activeID == MobileProfiles.defaultID)
        profiles.delete(MobileProfiles.defaultID)   // the last player stays
        #expect(profiles.players.count == 1)
    }
}

struct MobileShuffleAllTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func theFanPoolListsEveryLevelOnceAndPlaysLazily() throws {
        let ports = Self.root.appendingPathComponent(".build/ios-ports")
        try #require(FileManager.default.fileExists(atPath: ports.path))
        let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: [Self.root.appendingPathComponent("Content/LevelPacks")])
        let pool = catalogue.fanPool()
        #expect(pool.packs == catalogue.packs(in: .fan).count && pool.entries.count == 6_020)
        #expect(Set(pool.entries).count == pool.entries.count)
        var store = MobilePlaylistStore()
        let started = store.startShuffleAll(pool.entries, seed: 5)
        let run = try #require(started)
        #expect(run.playlist == nil && run.entries.count == 6_020 && Set(run.entries) == Set(pool.entries))
        // The lazy library opens no pack until a level is played.
        let library = MobileListLibrary(entries: Array(run.entries.prefix(300)), name: "Shuffle all", catalogue: catalogue, lazy: true)
        #expect(library.levels.count == 300 && library.levels.allSatisfy { !$0.title.isEmpty })
        let content = try library.loadLevel(at: 7)
        _ = try content.session.render(highlight: nil)
        #expect(library.origin(of: 7) != nil)
    }
}
