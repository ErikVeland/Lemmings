import Foundation
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit
import Testing

@MainActor struct ArchivedJourneyBackupTests {
    @Test func portableBackupReopensArchivedJourneyAndOwnedCheckpoint() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("first/Ultimate Lemmings")
        let destination = root.appendingPathComponent("second/Ultimate Lemmings")
        let suite = "backup-test-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        func storage(_ root: URL, _ profile: String) -> MobileStorage {
            MobileStorage(directory: root.appendingPathComponent("Mobile").appendingPathComponent(profile))
        }
        func checkpoints(_ root: URL) -> MobileCheckpointStore {
            MobileCheckpointStore(url: MobileContentStore(root: root.appendingPathComponent("iOS")).checkpointURL)
        }
        var profiles = MobileProfiles()
        let host = profiles.activeID
        let added = profiles.add(name: "UVA")
        let guest = try #require(added)
        try storage(source, "_players").save(profiles, name: "players")
        var seats = MobileHotSeatStore()
        seats.policy = .atFirstFail
        let started = seats.start(roster: .init(host: host, players: [guest]))
        var seat = try #require(started)
        seat.pass(to: guest)
        seats.update(seat)
        seats.endSession()
        try seats.save(to: storage(source, "_players"))

        let entries = try (1...2).map { index in
            try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fixture", levelID: "level-\(index)"),
                catalogueRevision: "1", sourceRevision: "1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Lesson \(index)", levelNumberSnapshot: index)
        }
        var learning = MobileLearningState()
        try learning.start(entries, name: LearningJourney.title, poolID: LearningJourney.version)
        learning.record(won: true)
        let advanced = learning.advance()
        #expect(advanced)
        let journey = try #require(learning.run)
        try learning.start(entries, name: "Other queue", poolID: "other", playlistID: UUID())
        try storage(source, seat.scope).save(learning, name: "learning")

        var solid = Data(repeating: 0, count: 160 * 80)
        solid.replaceSubrange(50 * 160..<solid.count, with: Data(repeating: 1, count: 30 * 160))
        let terrain = try ClassicDOSTerrain(width: 160, height: 80, solidMask: solid,
            steelMask: Data(repeating: 0, count: solid.count))
        let initial = try ClassicDOSSimulation(terrain: terrain, configuration: .init(totalLemmings: 5,
            requiredToSave: 1, timeLimitTicks: 1_000, initialReleaseRate: 50, entrances: [.init(x: 20, y: 20)],
            initialSkills: [.climber: 5], maximumX: 159, maximumY: 79))
        func session() -> ClassicMobileSession {
            ClassicMobileSession(simulation: initial, levelIdentifier: journey.currentEntry.identity.levelID,
                levelIndex: journey.currentIndex)
        }
        let original = session()
        for _ in 0..<45 { original.tick() }
        func checkpoint(owner: String, scope: String?, context: MobileCheckpointEnvelope.JourneyContext,
                        date: Date) throws -> MobileCheckpointEnvelope {
            try MobileCheckpointEnvelope(runID: UUID(), engine: original.engineIdentifier,
                engineFingerprint: original.engineFingerprint, levelIdentifier: original.levelIdentifier,
                levelIndex: original.levelIndex, levelFingerprint: original.levelFingerprint, tick: original.snapshot.tick,
                selectedControl: 0, camera: .init(origin: .init(x: 8, y: 4), zoom: 2),
                payload: original.checkpointPayload(), savedAt: date, scope: scope, owner: owner,
                journeyContext: context)
        }
        let saved = try checkpoint(owner: guest, scope: seat.scope,
            context: .init(runID: journey.id, position: journey.currentIndex), date: Date())
        let sourceCheckpoints = checkpoints(source)
        try await sourceCheckpoints.save(saved)
        let solo = try checkpoint(owner: host, scope: nil, context: .init(), date: saved.savedAt.addingTimeInterval(1))
        try await sourceCheckpoints.save(solo)

        let archive = try TVSaveBackup.capture(root: source, preferences: [:])
        let transfer = root.appendingPathComponent("journey.lemmingstv")
        try archive.encoded().write(to: transfer)
        let incoming = try TVSaveBackup.decode(Data(contentsOf: transfer))
        defaults.set(try JSONEncoder().encode(MobileProfiles()), forKey: "tv.mobile.players.players")
        defaults.set(try JSONEncoder().encode(MobileHotSeatStore()), forKey: "tv.mobile.players.hotseat")
        try incoming.restore(root: destination, defaults: defaults)
        let players = try #require(storage(destination, "_players").load(MobileProfiles.self, name: "players"))
        #expect(players == profiles)
        var recoveredSeats = MobileHotSeatStore.load(from: storage(destination, "_players"))
        #expect(try JSONDecoder().decode(MobileProfiles.self, from: #require(defaults.data(forKey: "tv.mobile.players.players"))) == profiles)
        #expect(try JSONDecoder().decode(MobileHotSeatStore.self, from: #require(defaults.data(forKey: "tv.mobile.players.hotseat"))) == seats)
        #expect(recoveredSeats.current == nil)
        let resumed = recoveredSeats.resume(id: seat.id)
        #expect(resumed?.players == [host, guest] && resumed?.turn == guest && resumed?.policy == .atFirstFail)
        try recoveredSeats.save(to: storage(destination, "_players"))
        let reopenedSeats = MobileHotSeatStore.load(from: storage(destination, "_players"))
        let resume = try #require(MobileLearningResume.find(owner: host, seats: reopenedSeats,
            storage: { storage(destination, $0) }))
        #expect(resume.seat == seat && resume.state.run == journey && resume.state.progress == learning.progress)
        let recovered = try #require(await checkpoints(destination).load(owner: host, scope: resume.scope))
        #expect(recovered == saved)
        #expect(recovered.matchesJourney(runID: journey.id, position: 1, levelIdentifier: original.levelIdentifier))
        let game = session()
        #expect(game.engineFingerprint == recovered.engineFingerprint && game.levelFingerprint == recovered.levelFingerprint)
        try game.restoreCheckpointPayload(recovered.payload)
        #expect(game.snapshot == original.snapshot && game.snapshot.tick == 45)
    }
}
