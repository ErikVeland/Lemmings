import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct JourneyResumePersistenceTests {
    @Test func playlistRecoveryRestoresLatestQueueAndPreservesDamage() throws {
        let storage = try AppStorage.temporary(named: "playlist-latest-recovery")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("playlists.json")
        let store = try LevelPlaylistStore(file: file)
        let entries = try (1...2).map {
            try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fixture", levelID: "\($0)"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Level \($0)", levelNumberSnapshot: $0)
        }
        let playlist = try LevelPlaylist(name: "Personal playlist", entries: entries)
        try store.add(playlist)
        let run = try LevelSequenceRun.playlist(playlist, pool: .init(id: "fixture", summary: playlist.name))
        try store.startRun(run, hotSeatID: "saved-seat")
        #expect(try store.advanceActiveRun())
        let damage = Data("broken".utf8)
        try damage.write(to: file, options: .atomic)
        let recovered = try LevelPlaylistStore(file: file)
        #expect(recovered.recovered)
        #expect(recovered.activeRun?.id == run.id)
        #expect(recovered.activeRun?.currentIndex == 1)
        #expect(recovered.activeRunHotSeatID == "saved-seat")
        let evidence = try FileManager.default.contentsOfDirectory(
            at: file.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let preserved = try #require(evidence.first { $0.lastPathComponent.hasPrefix("playlists.json.unreadable-") })
        #expect(try Data(contentsOf: preserved) == damage)
    }

    @Test func damagedPlaylistCopiesRecoverFromSyncedJourneyAfterReconnect() throws {
        let storage = try AppStorage.temporary(named: "playlist-sync-recovery")
        defer { storage.removeTemporaryFiles() }
        let profile = "test-profile"
        let seat = "saved-seat"
        let file = LevelPlaylistStore.fileURL(profileID: profile, storage: storage)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let copies = [file, file.appendingPathExtension("latest-backup"), file.appendingPathExtension("backup")]
        for (index, copy) in copies.enumerated() { try Data([UInt8(index)]).write(to: copy) }
        #expect(throws: (any Error).self) {
            try LevelPlaylistStore(profileID: profile, storage: storage, recoveryHotSeatIDs: [seat])
        }
        for (index, copy) in copies.enumerated() { #expect(try Data(contentsOf: copy) == Data([UInt8(index)])) }

        let entries = try (1...2).map {
            try LevelPlaylistEntry(identity: .init(engine: .lemmings2, packID: "fixture", levelID: "\($0)"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Level \($0)", levelNumberSnapshot: $0)
        }
        let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: LearningJourney.version, summary: LearningJourney.title), entries: entries, currentIndex: 1)
        let snapshot = JourneySessionSnapshot(run: run, l2Progress: ["carry": Data([3])])
        var learning = LearningJourneyProgress()
        learning.record(entries[0].identity, won: true)
        try GameProgressPreferences.saveLearning(learning, profileID: profile, sessionID: seat, defaults: storage.defaults)
        try GameProgressPreferences.saveJourneySession(snapshot, profileID: profile, sessionID: seat, defaults: storage.defaults)
        try GameProgressPreferences.saveJourneySession(snapshot, profileID: profile, sessionID: "unknown", defaults: storage.defaults)

        let repaired = try LevelPlaylistStore(profileID: profile, storage: storage, recoveryHotSeatIDs: [seat])
        #expect(repaired.recovered)
        #expect(repaired.journeySessions[seat] == snapshot)
        #expect(repaired.journeySessions["unknown"] == nil)
        #expect(repaired.learningProgress(hotSeatID: seat).completed == learning.completed)
        let reopened = try LevelPlaylistStore(file: file)
        let saved = try #require(reopened.resumableLearningJourney(hotSeatID: seat))
        #expect(saved.run == run)
        #expect(saved.l2Progress == snapshot.l2Progress)
        let evidence = try FileManager.default.contentsOfDirectory(
            at: file.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        #expect(evidence.filter { $0.lastPathComponent.contains(".unreadable-") }.count == copies.count)
        try Data("broken again".utf8).write(to: file, options: .atomic)
        try Data("broken mirror".utf8).write(to: copies[1], options: .atomic)
        let offline = try LevelPlaylistStore(file: file)
        #expect(offline.recovered)
        #expect(offline.resumableLearningJourney(hotSeatID: seat)?.run == run)
    }

    @Test(arguments: ["learning-30", "learning-31"])
    func importedJourneyResumesAfterTheEarlyTimingPuzzles(version: String) throws {
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
        let next = try #require(journey.lessons.first { $0.entry.identity.levelID == "68:Wicked:9:1:2" }?.entry)
        let finale = try #require(journey.lessons.first { $0.entry.identity.levelID == "32:Crazy:13:0:4" }?.entry)
        let retired = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: finale.identity.packID,
            levelID: "20:Crazy:1:0:1"), catalogueRevision: finale.catalogueRevision, sourceRevision: finale.sourceRevision,
            packNameSnapshot: finale.packNameSnapshot, levelNameSnapshot: "Quote: \"That`s a good level\"", levelNumberSnapshot: 21)
        var oldEntries = journey.lessons.map(\.entry).filter { $0.identity != finale.identity }
        oldEntries.insert(finale, at: 77)
        if version == "learning-30" { oldEntries.insert(retired, at: 77) }
        let old = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: version, summary: LearningJourney.title), entries: oldEntries, currentIndex: 77)
        let snapshot = JourneySessionSnapshot(run: old, l2Progress: ["carry": Data([3])])
        #expect(try store.importJourneySession(snapshot, hotSeatID: "ekv-uva"))
        try store.migrateLearningJourney(journey)
        let saved = try #require(store.resumableLearningJourney(hotSeatID: "ekv-uva"))
        #expect(saved.run.id == old.id && saved.run.currentIndex == old.currentIndex)
        #expect(saved.run.pool.id == LearningJourney.version)
        #expect(saved.run.currentEntry == next)
        #expect(saved.run.entries.last == finale)
        #expect(Array(saved.run.entries.prefix(77)) == Array(old.entries.prefix(77)))
        #expect(!saved.run.entries.contains { $0.identity == retired.identity })
        #expect(saved.l2Progress == ["carry": Data([3])])
        #expect(store.activeRun == unrelated && store.activeRunHotSeatID == "another-seat")
        let reopened = try LevelPlaylistStore(file: store.file)
        #expect(reopened.resumableLearningJourney(hotSeatID: "ekv-uva")?.run == saved.run)
        #expect(try !reopened.importJourneySession(snapshot, hotSeatID: "ekv-uva"))
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

    @Test(arguments: [false, true])
    func staleCloudScopeKeepsTheExistingJourneyOwner(archived: Bool) throws {
        let storage = try AppStorage.temporary(named: "journey-cloud-scope")
        defer { storage.removeTemporaryFiles() }
        let file = storage.applicationSupport.appendingPathComponent("playlists.json")
        let store = try LevelPlaylistStore(file: file)
        let entries = try (1...2).map { index in
            try LevelPlaylistEntry(identity: .init(engine: .lemmings2, packID: "fixture", levelID: "\(index)"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Level \(index)", levelNumberSnapshot: index)
        }
        let playlist = try LevelPlaylist(id: LearningJourney.playlistID, name: LearningJourney.title, entries: entries)
        try store.add(playlist)
        let pool = try LevelPool(id: LearningJourney.version, summary: playlist.name)
        let first = try LevelSequenceRun.playlist(playlist, pool: pool)
        let owner = "current-seat", alias = "former-seat"
        let checkpoint = ["carry": Data([3])]
        try store.startRun(first, hotSeatID: owner, l2Progress: checkpoint)
        #expect(try store.advanceActiveRun())
        if archived {
            try store.startRun(.playlist(playlist, pool: pool), hotSeatID: "another-seat")
        }
        let before = try Data(contentsOf: file)
        let stale = JourneySessionSnapshot(run: first, updatedAt: .distantFuture)
        #expect(try !store.importJourneySession(stale, hotSeatID: alias))
        #expect(try Data(contentsOf: file) == before)
        #expect(store.journeySessions[alias] == nil)

        let reopened = try LevelPlaylistStore(file: file)
        let saved = try #require(reopened.resumableLearningJourney(hotSeatID: owner))
        #expect(saved.run.id == first.id)
        #expect(saved.run.currentIndex == 1)
        #expect(saved.l2Progress == checkpoint)
        #expect(reopened.resumableLearningJourney(hotSeatID: alias) == nil)
    }
}
