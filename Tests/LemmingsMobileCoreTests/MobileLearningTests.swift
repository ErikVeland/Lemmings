import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileLearningTests {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    @Test func curatedJourneyStartsWithoutScanningFuturePacks() throws {
        let resources = root.appendingPathComponent("Resources")
        let temporary = try AppStorage.temporary(named: "journey")
        defer { temporary.removeTemporaryFiles() }
        let storage = AppStorage(applicationSupport: temporary.applicationSupport, resources: resources, defaults: temporary.defaults)
        let journey = try #require(LearningJourneyLibrary.journey(storage: storage))
        let catalogue = MobileCatalogue(portsRoot: root.appendingPathComponent("Sources/Ports"),
            fanFolders: [URL(fileURLWithPath: "/nonexistent-future-packs")])
        let library = MobileJourneyLibrary(entries: journey.lessons.map(\.entry), name: LearningJourney.title, catalogue: catalogue)
        #expect(library.levels.count == journey.lessons.count)
        let content = try library.loadLevel(at: 0)
        #expect(content.summary.title == "Just dig!")
        #expect(content.session.snapshot.tick == 0)
        #expect(content.session.snapshot.total == 10)
        #expect(content.session.snapshot.required == 1)
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
        let found = try #require(MobileLearningResume.find(owner: "host", seats: seats, storage: files))
        #expect(found.state == state)
        #expect(found.seat == archived)
        #expect(found.seat?.turn == "guest")
        #expect(found.scope == archived.scope)
        #expect(found.resumeTitle == "Resume journey run  2/3")
        #expect(seats == original)
        #expect(MobileLearningResume.find(owner: "guest", seats: seats, storage: files)?.seat == archived)
        try files("host").save(state, name: "learning")
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files)?.seat == nil)
        try files(try #require(seats.current).scope).save(state, name: "learning")
        #expect(MobileLearningResume.find(owner: "host", seats: seats, storage: files)?.seat == seats.current)
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
        #expect(MobileLearningResume.find(owner: "eri", seats: seats, storage: files)?.state == solo)
        let restored = try #require(MobileLearningResume.find(owner: "eri", seats: seats, storage: files, journeyOnly: false))
        #expect(restored.seat == seat && restored.state == shared)
        #expect(restored.state.run?.pool.summary == "Easy to hard")
        #expect(restored.state.run?.currentIndex == 2)
        #expect(restored.resumeTitle == "Resume Easy to hard  3/4")
        seats.endSession()
        #expect(MobileLearningResume.find(owner: "eri", seats: seats, storage: files, journeyOnly: false)?.seat == nil)
        #expect(MobileLearningResume.find(owner: "uva", seats: seats, storage: files, journeyOnly: false)?.seat == seat)
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
