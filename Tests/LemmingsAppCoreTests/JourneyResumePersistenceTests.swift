import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct JourneyResumePersistenceTests {
    @Test func olderImportedJourneyMigratesBeforeHomeLooksUpItsArchivedSession() throws {
        let temporary = try AppStorage.temporary(named: "imported-journey-revision")
        defer { temporary.removeTemporaryFiles() }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let storage = AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        let store = try LevelPlaylistStore(file: storage.applicationSupport.appendingPathComponent("playlists.json"))
        try store.add(journey.playlist())
        let unrelated = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: LearningJourney.version, summary: LearningJourney.title), entries: Array(journey.lessons.prefix(2).map(\.entry)))
        try store.startRun(unrelated, hotSeatID: "another-seat")
        let old = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-23", summary: LearningJourney.title), entries: Array(journey.lessons.prefix(4).map(\.entry)), currentIndex: 1)
        let snapshot = JourneySessionSnapshot(run: old, l2Progress: ["carry": Data([3])])
        try store.importJourneySession(snapshot, hotSeatID: "ekv-uva")
        try store.migrateLearningJourney(journey)
        let saved = try #require(store.resumableLearningJourney(hotSeatID: "ekv-uva"))
        #expect(saved.run.id == old.id && saved.run.currentIndex == old.currentIndex)
        #expect(saved.run.pool.id == LearningJourney.version)
        #expect(saved.l2Progress == ["carry": Data([3])])
        #expect(store.activeRun == unrelated && store.activeRunHotSeatID == "another-seat")
        let reopened = try LevelPlaylistStore(file: store.file)
        #expect(reopened.resumableLearningJourney(hotSeatID: "ekv-uva")?.run == saved.run)
        try reopened.importJourneySession(snapshot, hotSeatID: "ekv-uva")
        #expect(reopened.resumableLearningJourney(hotSeatID: "ekv-uva")?.run == saved.run)
    }

    @Test func integrationBuildCannotResolveProductionSavePaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let plist = ["CFBundleIdentifier": "academy.glasscode.lemmings.integration-tests.resume"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: root.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: root))
        let storage = AppStorage.current(bundle: bundle)
        #expect(storage.isIntegrationTestBuild)
        #expect(storage.applicationSupport.path.contains("LemmingsIntegrationTests"))
        #expect(!storage.applicationSupport.path.contains("Library/Application Support"))
    }
    @Test func selectedSessionResumesAnArchivedQueueAfterReopen() throws {
        for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3, .neolemmix] {
            let storage = try AppStorage.temporary(named: "journey-resume")
            defer { storage.removeTemporaryFiles() }
            let file = storage.applicationSupport.appendingPathComponent("playlists.json")
            let store = try LevelPlaylistStore(file: file)
            let entry = try LevelPlaylistEntry(identity: .init(engine: engine, packID: "fixture", levelID: "one"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Saved level", levelNumberSnapshot: 1)
            let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: LearningJourney.title, entries: [entry])
            try store.add(playlist)
            let journey = try LevelSequenceRun.playlist(playlist, pool: .init(id: LearningJourney.version, summary: playlist.name))
            try store.startRun(journey, hotSeatID: "selected")
            let other = try LevelSequenceRun.playlist(playlist, pool: journey.pool)
            try store.startRun(other, hotSeatID: "other")
            let reopened = try LevelPlaylistStore(file: file)
            #expect(reopened.resumableRun(hotSeatID: "selected")?.run == journey)
            #expect(reopened.resumableRun(hotSeatID: nil) == nil)
            #expect(reopened.resumableRun(hotSeatID: "missing") == nil)
            #expect(reopened.activeRun == other)
            try reopened.resumeRun(id: journey.id)
            #expect(reopened.activeRunHotSeatID == "selected")
            #expect(reopened.resumableRun(hotSeatID: "other")?.run == other)
        }
    }

    @Test func unrelatedRunDoesNotPublishJourneyDeletion() throws {
        let storage = try AppStorage.temporary(named: "journey-retention")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("playlists.json")
        let store = try LevelPlaylistStore(file: file)
        let entry = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fixture", levelID: "one"),
            catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
            levelNameSnapshot: "Saved level", levelNumberSnapshot: 1)
        let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: LearningJourney.title, entries: [entry])
        try store.add(playlist)
        let journey = try LevelSequenceRun.playlist(playlist, pool: .init(id: LearningJourney.version, summary: playlist.name))
        try store.startRun(journey, hotSeatID: "shared", l2Progress: ["carry": Data([3])])
        let snapshot = try #require(store.journeySessions["shared"])
        let other = try LevelPlaylist(name: "Other", entries: [entry])
        try store.add(other)
        try store.startRun(.playlist(other, pool: .init(id: "other", summary: "Other")), hotSeatID: "shared")
        try store.ensureJourneySnapshots()
        #expect(store.journeySessions["shared"] == snapshot)
        let reopened = try LevelPlaylistStore(file: file)
        #expect(reopened.resumableLearningJourney(hotSeatID: "shared")?.run == journey)
        #expect(reopened.journeySessions["shared"] == snapshot)
        let destination = try LevelPlaylistStore(file: storage.applicationSupport.appendingPathComponent("other-device.json"))
        try destination.importJourneySession(snapshot, hotSeatID: "shared")
        #expect(destination.resumableRun(hotSeatID: "shared")?.run == journey)
        #expect(destination.activeRunL2Progress == ["carry": Data([3])])
        let replacement = try LevelSequenceRun.playlist(playlist, pool: journey.pool)
        try destination.startRun(replacement, hotSeatID: "shared")
        try destination.setActiveRun(nil)
        try destination.ensureJourneySnapshots()
        #expect(destination.journeySessions["shared"]?.run == nil)
        #expect(destination.resumableRun(hotSeatID: "shared") == nil)
        #expect(destination.resumableRun(id: journey.id)?.run == journey)
    }
}
