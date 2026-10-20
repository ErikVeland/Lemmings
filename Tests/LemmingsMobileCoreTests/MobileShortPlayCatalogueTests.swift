import Foundation
import Testing
import LemmingsAppCore
import NxlvKit
@testable import LemmingsMobileCore

struct MobileShortPlayCatalogueTests {
    @Test @MainActor func pinnedSourcesSurvivePlaylistResumeAndRejectReplacementBytes() throws {
        let storage = try AppStorage.temporary(named: "short-play-source")
        defer { storage.removeTemporaryFiles() }
        let directory = storage.resources.appendingPathComponent("classic")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let level = directory.appendingPathComponent("LEVEL000.DAT")
        try Data("original level bytes".utf8).write(to: level)
        let fingerprint = try MobileContentFingerprint.digest(directory: directory)
        let entry = MobileFavourites.Entry(pack: "release/lemmings", level: "Fun/1", title: "Just dig!",
            sourceFingerprint: fingerprint)
        var playlists = MobilePlaylistStore()
        let created = playlists.create(name: "Classic opening", entries: [entry])
        let id = try #require(created)
        _ = playlists.startRun(id, shuffle: false)
        let encoded = try JSONEncoder().encode(playlists)
        let decoded = try JSONDecoder().decode(MobilePlaylistStore.self, from: encoded)
        #expect(decoded.run?.entries.first?.sourceFingerprint == fingerprint)
        let mobile = MobileStorage(directory: storage.applicationSupport.appendingPathComponent("mobile"))
        let bridge = try MobileCollectionsBridge(profileID: "owner", appStorage: storage, mobileStorage: mobile)
        try bridge.save(favourites: .init(), recents: .init(), playlists: decoded, hotSeatID: "family")
        let reopened = try MobileCollectionsBridge(profileID: "owner", appStorage: storage, mobileStorage: mobile)
        let resumed = try #require(reopened.playlists(hotSeatID: "family").run)
        #expect(resumed.entries.first?.sourceFingerprint == fingerprint)
        #expect(reopened.playlists(hotSeatID: nil).run == nil)
        #expect(MobileListLibrary.matchesSourceFingerprint(resumed.entries[0].sourceFingerprint, directory: directory))
        try Data("replacement level bytes".utf8).write(to: level)
        #expect(!MobileListLibrary.matchesSourceFingerprint(resumed.entries[0].sourceFingerprint, directory: directory))
        let legacy = try JSONDecoder().decode(MobileFavourites.Entry.self,
            from: Data(#"{"pack":"release/lemmings","level":"Fun/1","title":"Just dig!"}"#.utf8))
        #expect(legacy.sourceFingerprint == nil)
        #expect(MobileListLibrary.matchesSourceFingerprint(legacy.sourceFingerprint, directory: directory))
    }

    @Test func missingEvidenceOrDataNeverCreatesAnOpening() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let catalogue = MobileCatalogue(portsRoot: temporary)
        for sequence in ShortPlayCatalogue.sequences {
            #expect(throws: (any Error).self) {
                try MobileShortPlayCatalogue.entries(sequence: sequence, journey: nil, catalogue: catalogue)
            }
        }
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let data = try Data(contentsOf: resources.appendingPathComponent("Progression/learning.json"))
        let journey = try JSONDecoder().decode(LearningJourney.self, from: data)
        let classic = try #require(ShortPlayCatalogue.sequence(id: "classic"))
        #expect(throws: (any Error).self) {
            try MobileShortPlayCatalogue.entries(sequence: classic, journey: journey, catalogue: catalogue)
        }
        for sequence in ShortPlayCatalogue.sequences where sequence.engine != .classic {
            #expect(throws: MobileSessionError.journeyEngineUnavailable) {
                try MobileShortPlayCatalogue.entries(sequence: sequence, journey: journey, catalogue: catalogue)
            }
        }
    }
}
