import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileLearningTests {
    @Test func selectedSyncedJourneyResolvesBeforeAnyLocalLearningFileExists() throws {
        let temporary = try AppStorage.temporary(named: "cloud-only-journey")
        defer { temporary.removeTemporaryFiles() }
        func files(_ scope: String) -> MobileStorage {
            .init(directory: temporary.applicationSupport.appendingPathComponent(scope))
        }
        for engine in [LevelSourceEngine.classic, .lemmings2, .lemmings3, .neolemmix] {
            let entry = try LevelPlaylistEntry(identity: .init(engine: engine, packID: "fixture", levelID: "saved"),
                catalogueRevision: "v1", sourceRevision: "v1", packNameSnapshot: "Fixture",
                levelNameSnapshot: "Saved level", levelNumberSnapshot: 1)
            let run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
                pool: .init(id: LearningJourney.version, summary: LearningJourney.title), entries: [entry])
            let snapshot = JourneySessionSnapshot(run: run)
            var seats = MobileHotSeatStore()
            let started = seats.start(roster: .init(host: "ekv", players: ["uva"]))
            var seat = try #require(started)
            seat.pass(to: "uva"); seats.update(seat)
            try seats.save(to: files("_players"))
            let reopened = MobileHotSeatStore.load(from: files("_players"))
            let found = try #require(MobileLearningResume.find(owner: "uva", seats: reopened, storage: files,
                snapshot: { $0 == seat.id ? snapshot : nil }))
            #expect(found.state.run == run)
            #expect(found.seat?.id == seat.id && found.seat?.turn == "uva")
            #expect(files(seat.scope).load(MobileLearningState.self, name: "learning") == nil)
            #expect(reopened == seats)
            let completed = JourneySessionSnapshot(run: nil, updatedAt: snapshot.updatedAt.addingTimeInterval(1))
            #expect(MobileLearningResume.find(owner: "uva", seats: reopened, storage: files,
                snapshot: { $0 == seat.id ? completed : nil }) == nil)
            seats.endSession()
            #expect(MobileLearningResume.find(owner: "ekv", seats: seats, storage: files,
                snapshot: { $0 == seat.id ? snapshot : nil }) == nil)
        }
    }

    @Test func legacyArchivedQueueResumesWithoutRevivingACompletedJourney() throws {
        let journey = try #require(LearningJourneyLibrary.journey(storage: AppStorage(applicationSupport: root,
            resources: root.appendingPathComponent("Resources"), defaults: .standard)))
        var state = MobileLearningState()
        try state.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        state.advance()
        let saved = try #require(state.run)
        try state.start(Array(journey.lessons.prefix(2).map(\.entry)), name: "Other", poolID: "other", playlistID: UUID())
        let other = state.run
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "journeySession")
        let legacy = try JSONDecoder().decode(MobileLearningState.self, from: JSONSerialization.data(withJSONObject: json))
        state = legacy; state.resumeJourney()
        #expect(state.run == saved)
        #expect(state.savedRuns.contains { $0 == other })
        state = legacy; state.journeySession = .init(run: nil); state.resumeJourney()
        #expect(state.run == other)
    }

    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private var ports: URL {
        ProcessInfo.processInfo.environment["LEMMINGS_TEST_BUNDLED_RESOURCES"].map {
            URL(fileURLWithPath: $0).appendingPathComponent("Ports")
        } ?? root.appendingPathComponent("Sources/Ports")
    }
    @Test func syncedJourneyKeepsItsQueueAndDoesNotReplaceAnUnrelatedRun() throws {
        let temporary = try AppStorage.temporary(named: "synced-journey-state")
        defer { temporary.removeTemporaryFiles() }
        let journey = try #require(LearningJourneyLibrary.journey(storage: AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)))
        var source = MobileLearningState()
        try source.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        source.advance(); source.refreshJourneySession()
        let snapshot = try #require(source.journeySession)
        var target = MobileLearningState(); target.importJourneySession(snapshot)
        #expect(target.run == source.run)
        let old = JourneySessionSnapshot(run: nil, updatedAt: snapshot.updatedAt.addingTimeInterval(-1))
        target.importJourneySession(old)
        #expect(target.run == source.run)
        var unrelated = MobileLearningState()
        try unrelated.start(Array(journey.lessons.prefix(2).map(\.entry)), name: "Other", poolID: "progression-test", playlistID: UUID())
        let original = unrelated.run
        unrelated.importJourneySession(snapshot)
        #expect(unrelated.run == original)
        unrelated.refreshJourneySession()
        #expect(unrelated.journeySession == snapshot)
        unrelated.advance()
        unrelated.advance()
        unrelated.refreshJourneySession()
        #expect(unrelated.journeySession == snapshot, "Completing another route must not delete the journey")
        unrelated.resumeJourney()
        #expect(unrelated.run == source.run)

        var switching = target
        try switching.start(Array(journey.lessons.prefix(2).map(\.entry)), name: "Other", poolID: "other", playlistID: UUID())
        let other = switching.run
        switching.refreshJourneySession()
        switching.resumeJourney()
        #expect(switching.run == source.run)
        #expect(switching.savedRuns.contains { $0 == other })
        let reopened = try JSONDecoder().decode(MobileLearningState.self, from: JSONEncoder().encode(switching))
        #expect(reopened == switching)
    }
    @Test func oldTVJourneyDefersQuickyWithoutChangingVisitsProgressOrHotSeatTurn() throws {
        let temporary = try AppStorage.temporary(named: "tv-journey-wall")
        defer { temporary.removeTemporaryFiles() }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        // The actual learning-23 opening bundled in the older TV generation.
        let oldIDs = ["0:Fun:1:9:1", "Ji Hoon Heaven 1.DAT#5", "1:Fun:2:9:5", "2:Fun:3:9:6",
            "3:Fun:4:9:2", "4:Fun:5:9:3", "5:Fun:6:9:4", "6:Fun:7:9:7", "4:Tame:5:10:4",
            "13:Tame:14:11:5", "3:Tame:4:10:3", "10:Fun:11:4:2", "21:Fun:22:1:3", "20:Fun:21:8:4",
            "34:Tricky:5:3:1", "51:Tricky:22:0:6", "42:Mega Drive Sunsoft:13:0:42", "lm_set08.dat#5",
            "40:Wild:1:9:2", "47:Tricky:18:9:5", "45:Wild:6:7:5"]
        let opening = try oldIDs.map { id in try #require(journey.lessons.first { $0.entry.identity.levelID == id }?.entry) }
        let past = Set(opening.map(\.identity))
        let entries = opening + journey.lessons.map(\.entry).filter { !past.contains($0.identity) }
        var state = MobileLearningState()
        state.run = try LevelSequenceRun(source: .playlist(LearningJourney.playlistID),
            pool: .init(id: "learning-23", summary: LearningJourney.title), entries: entries, currentIndex: 20)
        state.progress.record(opening[0].identity, won: true)
        state.record(won: false)
        let original = state
        var seats = MobileHotSeatStore()
        let started = seats.start(roster: .init(host: "host", players: ["guest"]))
        var seat = try #require(started)
        seat.pass(to: "guest"); seats.update(seat)
        func files(_ scope: String) -> MobileStorage {
            .init(directory: temporary.applicationSupport.appendingPathComponent(scope))
        }
        try files(seat.scope).save(state, name: "learning")
        state = try #require(files(seat.scope).load(MobileLearningState.self, name: "learning"))
        state.run = try journey.migrating(try #require(state.run))
        try files(seat.scope).save(state, name: "learning")
        let restored = try #require(MobileLearningResume.find(owner: "host", seats: seats, storage: files))
        #expect(restored.seat == seat && restored.seat?.turn == "guest")
        #expect(restored.state.progress == original.progress)
        #expect(restored.state.run?.id == original.run?.id)
        #expect(restored.state.run?.currentIndex == 20)
        #expect(Array(try #require(restored.state.run).entries.prefix(20)) == Array(entries.prefix(20)))
        // The revised opening's beginner lessons do not return after this run's frontier.
        #expect(restored.state.run?.currentEntry == journey.lessons[54].entry)
        #expect(!(try #require(restored.state.run).entries.dropFirst(20)
            .contains { $0.levelNameSnapshot == "Intsy-Wintsy...Lemming?" }))
        #expect(try #require(restored.state.run).entries.dropFirst(20).lastIndex { $0.identity == opening[20].identity }! > 80)
    }
    @Test func oldMobileJourneyDropsVersusLevelsAndKeepsItsRunIdentity() throws {
        let journey = try #require(LearningJourneyLibrary.journey(storage: AppStorage(applicationSupport: root, resources: root.appendingPathComponent("Resources"), defaults: .standard)))
        let solo = journey.lessons[0].entry
        let versus = try LevelPlaylistEntry(identity: .init(engine: .classic, packID: "fan:lldb-404", levelID: "Genesis 2P 1.dat#0"),
            catalogueRevision: "test", sourceRevision: "v1", packNameSnapshot: "Genesis 2P", levelNameSnapshot: "There can be only one", levelNumberSnapshot: 1)
        var old = MobileLearningState()
        old.run = try LevelSequenceRun(source: .playlist(UUID()), pool: .init(id: "progression-4", summary: "Solo"), entries: [versus, solo])
        let restored = try JSONDecoder().decode(MobileLearningState.self, from: JSONEncoder().encode(old))
        #expect(restored.run?.id == old.run?.id && restored.run?.currentEntry == solo)
        #expect(restored.run?.entries.count == 1 && restored.progress == old.progress)
    }

    @Test func curatedJourneyStartsWithoutScanningFuturePacks() throws {
        let resources = root.appendingPathComponent("Resources")
        let temporary = try AppStorage.temporary(named: "journey")
        defer { temporary.removeTemporaryFiles() }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport, resources: resources, defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        let catalogue = MobileCatalogue(portsRoot: ports,
            fanFolders: [URL(fileURLWithPath: "/nonexistent-future-packs")])
        let library = MobileJourneyLibrary(entries: journey.lessons.map(\.entry), name: LearningJourney.title, catalogue: catalogue)
        #expect(library.levels.count == journey.lessons.count)
        let content = try library.loadLevel(at: 0)
        #expect(content.summary.title == "Just dig!")
        #expect(content.summary.origin == .official)
        #expect(!content.summary.packName.isEmpty)
        let fanIndex = try #require(journey.lessons.firstIndex { $0.entry.identity.packID.hasPrefix("fan:") })
        #expect(library.levels[fanIndex].origin == .fanMade)
        #expect(content.session.snapshot.tick == 0)
        #expect(content.session.snapshot.total == 10)
        #expect(content.session.snapshot.required == 1)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["LEMMINGS_TEST_BUNDLED_RESOURCES"] != nil,
        "Requires exact bundled game data through LEMMINGS_TEST_BUNDLED_RESOURCES"))
    func seasonalJourneyEntriesResolveTheirExactSourceWithoutStartingPlay() throws {
        let journey = try #require(LearningJourneyLibrary.journey(storage: AppStorage(
            applicationSupport: root, resources: root.appendingPathComponent("Resources"), defaults: .standard)))
        let catalogue = MobileCatalogue(portsRoot: ports, fanFolders: [])
        let library = MobileJourneyLibrary(entries: journey.lessons.map(\.entry), name: LearningJourney.title, catalogue: catalogue)
        var resolved = 0
        for (index, lesson) in journey.lessons.enumerated() where LearningJourney.isOfficialSeasonal(lesson.entry) {
            let source = try library.origin(of: index)
            #expect(source.pack == "release/" + String(lesson.entry.identity.packID.split(separator: "-")[0]))
            let content = try library.loadLevel(at: index)
            #expect(content.summary.title == lesson.entry.levelNameSnapshot)
            #expect(content.session.engineIdentifier == "classic-dos")
            #expect(content.session.snapshot.tick == 0)
            #expect(try library.checkpointLevelIdentifier(at: index) == content.session.levelIdentifier)
            resolved += 1
        }
        #expect(resolved == 70)
    }
    @Test func selectingJourneyLevelPreservesQueueAndRecordsTheSelectedLesson() throws {
        let temporary = try AppStorage.temporary(named: "journey-select")
        defer { temporary.removeTemporaryFiles() }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        var learning = MobileLearningState()
        try learning.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        let original = try #require(learning.run)
        try learning.select(2)
        #expect(learning.run?.id == original.id)
        #expect(learning.run?.entries == original.entries)
        #expect(learning.run?.currentIndex == 2)
        learning.record(won: true)
        #expect(learning.progress.solvedCount(in: journey) == 1)
        try learning.select(0)
        let advanced = learning.advance()
        #expect(advanced)
        #expect(learning.run?.currentIndex == 1)
        let beforeInvalid = learning
        #expect(throws: (any Error).self) { try learning.select(99) }
        #expect(learning == beforeInvalid)
    }

    @Test func storedQueueKeepsOwnerScopePositionAndDeferrals() throws {
        let resources = root.appendingPathComponent("Resources")
        let temporary = try AppStorage.temporary(named: "journey-save")
        defer { temporary.removeTemporaryFiles() }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport, resources: resources, defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        var learning = MobileLearningState()
        try learning.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        learning.record(won: false)
        let advanced = learning.advance()
        #expect(advanced)
        let files = MobileStorage(directory: temporary.applicationSupport.appendingPathComponent("hotseat.123"))
        try files.save(learning, name: "learning")
        let restored = try #require(files.load(MobileLearningState.self, name: "learning"))
        #expect(restored.run?.id == learning.run?.id)
        #expect(restored.run?.currentIndex == 1)
        #expect(restored.progress.revisit(in: journey).map(\.identity) == [journey.lessons[0].entry.identity])
        #expect(restored.progress.solvedCount(in: journey) == 0)
        #expect(MobileStorage(directory: temporary.applicationSupport.appendingPathComponent("solo")).load(MobileLearningState.self, name: "learning") == nil)
    }
    @Test func resumeFindsArchivedJourneyAndPreservesItsTurnAndQueue() throws {
        let temporary = try AppStorage.temporary(named: "journey-resume")
        defer { temporary.removeTemporaryFiles() }
        func files(_ scope: String) -> MobileStorage {
            MobileStorage(directory: temporary.applicationSupport.appendingPathComponent(scope))
        }
        let resources = root.appendingPathComponent("Resources")
        let storage = AppStorage(applicationSupport: temporary.applicationSupport, resources: resources, defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        var state = MobileLearningState()
        try state.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        state.record(won: false); state.advance()
        var seats = MobileHotSeatStore()
        let started = seats.start(roster: .init(host: "host", players: ["guest"]))
        var archived = try #require(started)
        archived.pass(to: "guest"); seats.update(archived)
        try files(archived.scope).save(state, name: "learning")
        seats.endSession()
        _ = seats.start(roster: .init(host: "host", players: ["other"]))
        let original = seats
        let found = try #require(MobileLearningResume.find(owner: "host", seats: seats, storage: files, currentSessionOnly: false))
        #expect(found.state == state)
        #expect(found.seat == archived)
        #expect(found.seat?.turn == "guest")
        #expect(found.scope == archived.scope)
        #expect(found.resumeTitle == "Resume journey")
        #expect(seats == original)
        #expect(MobileLearningResume.find(owner: "guest", seats: seats, storage: files, currentSessionOnly: false)?.seat == archived)
        try files("host").save(state, name: "learning")
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files, currentSessionOnly: false)?.seat == nil)
        try files(try #require(seats.current).scope).save(state, name: "learning")
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files, currentSessionOnly: false)?.seat == seats.current)
    }
    @Test func progressionRecallUsesItsSavedScopeNameAndPosition() throws {
        let temporary = try AppStorage.temporary(named: "progression-resume")
        defer { temporary.removeTemporaryFiles() }
        func files(_ scope: String) -> MobileStorage {
            MobileStorage(directory: temporary.applicationSupport.appendingPathComponent(scope))
        }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        var solo = MobileLearningState(), shared = MobileLearningState()
        try solo.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        try shared.start(Array(journey.lessons.prefix(4).map(\.entry)), name: "Easy to hard", poolID: "progression-v1", playlistID: UUID())
        shared.advance(); shared.advance()
        var seats = MobileHotSeatStore()
        let started = seats.start(roster: .init(host: "eri", players: ["uva"]))
        let seat = try #require(started)
        try files("eri").save(solo, name: "learning")
        try files(seat.scope).save(shared, name: "learning")
        #expect(MobileLearningResume.find(owner: "eri", seats: seats, storage: files) == nil)
        let restored = try #require(MobileLearningResume.find(owner: "eri", seats: seats, storage: files, journeyOnly: false))
        #expect(restored.seat == seat && restored.state == shared)
        #expect(restored.state.run?.pool.summary == "Easy to hard")
        #expect(restored.state.run?.currentIndex == 2)
        #expect(restored.resumeTitle == "Resume Easy to hard  3/4")
        seats.endSession()
        #expect(MobileLearningResume.find(owner: "eri", seats: seats, storage: files, journeyOnly: false)?.seat == nil)
        #expect(MobileLearningResume.find(owner: "uva", seats: seats, storage: files, journeyOnly: false) == nil)
    }
    @Test func homeAndJourneyStayInTheSelectedSession() throws {
        let temporary = try AppStorage.temporary(named: "home-seat-resume")
        defer { temporary.removeTemporaryFiles() }
        func files(_ scope: String) -> MobileStorage {
            MobileStorage(directory: temporary.applicationSupport.appendingPathComponent(scope))
        }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport,
            resources: root.appendingPathComponent("Resources"), defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        var state = MobileLearningState()
        try state.start(Array(journey.lessons.prefix(3).map(\.entry)), name: LearningJourney.title, poolID: journey.version)
        try files("host").save(state, name: "learning")
        var seats = MobileHotSeatStore()
        let started = seats.start(roster: .init(host: "host", players: ["guest"]))
        let selected = try #require(started)
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files,
            journeyOnly: false, currentSessionOnly: true) == nil)
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files) == nil)
        try files(selected.scope).save(state, name: "learning")
        let found = try #require(MobileLearningResume.find(owner: "host", seats: seats, storage: files,
            journeyOnly: false, currentSessionOnly: true))
        #expect(found.seat == selected && found.state == state)
        _ = seats.start(roster: .init(host: "host", players: ["other"]))
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files,
            journeyOnly: false, currentSessionOnly: true) == nil)
        seats.endSession()
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files,
            journeyOnly: false, currentSessionOnly: true)?.seat == nil)
    }
    @Test func pythonStagingUsesMacSourceRevision() throws {
        let temporary = try AppStorage.temporary(named: "revision")
        defer { temporary.removeTemporaryFiles() }
        try Data([1, 2, 3]).write(to: temporary.resources.appendingPathComponent("LEVEL000.DAT"))
        try FileManager.default.createDirectory(at: temporary.resources.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try Data([4, 5]).write(to: temporary.resources.appendingPathComponent("nested/GROUND.DAT"))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-c", "import sys; sys.path.insert(0, sys.argv[1]); import ports; from pathlib import Path; print(ports.directory_revision(Path(sys.argv[2])))", root.appendingPathComponent("Tools/IOSBeta").path, temporary.resources.path]
        let output = Pipe(); process.standardOutput = output
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let actual = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(actual == ClassicSourceRevision.directory(temporary.resources))
    }
}
