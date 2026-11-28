import Foundation
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
import Testing

struct MobileJourneyAvailabilityTests {
    private func entry(engine: LevelSourceEngine = .classic, number: Int = 1) throws -> LevelPlaylistEntry {
        try LevelPlaylistEntry(
            identity: .init(engine: engine, packID: "lemmings-LEVEL-120",
                            levelID: "\(number - 1):Fun:\(number):9:\(number)"),
            catalogueRevision: "availability-test", sourceRevision: "fixture-revision",
            packNameSnapshot: "Classic Lemmings",
            levelNameSnapshot: number == 1 ? "Just dig!" : "Second lesson",
            levelNumberSnapshot: number)
    }

    @Test func metadataWithoutGameDataCannotPrepareABlankLevel() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let lesson = try entry()
        let catalogue = MobileCatalogue(portsRoot: root)
        #expect(MobileJourneyLibrary.sourcePack(for: lesson.identity, in: catalogue) == nil)
        let library = MobileJourneyLibrary(entries: [lesson], name: LearningJourney.title, catalogue: catalogue)
        #expect(library.levels.first?.title == "Just dig!")
        let loader = MobileMenuPreviewLoader {
            MobileJourneyLibrary(entries: [lesson], name: LearningJourney.title,
                                 catalogue: MobileCatalogue(portsRoot: root))
        }
        await #expect(throws: MobileSessionError.changedLevel) { try await loader.load(0) }
        await #expect(throws: MobileSessionError.changedLevel) { try await loader.prepare(0) }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test(arguments: [false, true])
    func incompleteReleaseCannotProduceOrCacheAPreview(withLevelFile: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let release = root.appendingPathComponent("lemmings_dos_1991-07-30")
        try FileManager.default.createDirectory(at: release, withIntermediateDirectories: true)
        if withLevelFile {
            try Data([0, 0, 0, 0]).write(to: release.appendingPathComponent("LEVEL000.DAT"))
        }
        let lesson = try entry()
        let loader = MobileMenuPreviewLoader {
            MobileJourneyLibrary(entries: [lesson], name: LearningJourney.title,
                                 catalogue: MobileCatalogue(portsRoot: root))
        }
        await #expect(throws: (any Error).self) { try await loader.load(0) }
        await #expect(throws: (any Error).self) { try await loader.prepare(0) }
    }

    @Test(arguments: [false, true])
    func failedCurrentEntryPreservesSavedJourneyAndHotSeat(withReleaseFolder: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let ports = root.appendingPathComponent("Ports")
        if withReleaseFolder {
            try FileManager.default.createDirectory(
                at: ports.appendingPathComponent("lemmings_dos_1991-07-30"), withIntermediateDirectories: true)
        }
        var state = MobileLearningState()
        try state.start([entry(), entry(number: 2)], name: LearningJourney.title, poolID: "learning-availability")
        state.record(won: true)
        try state.select(1)
        state.record(won: false)
        state.refreshJourneySession()
        var seats = MobileHotSeatStore()
        let started = seats.start(roster: .init(host: "host", players: ["guest"]))
        var seat = try #require(started)
        seat.pass(to: "guest")
        seats.update(seat)
        let originalSeats = seats
        let files = MobileStorage(directory: root.appendingPathComponent(seat.scope))
        try files.save(state, name: "learning")
        let savedFile = files.directory.appendingPathComponent("learning.json")
        let savedBytes = try Data(contentsOf: savedFile)
        let resume = try #require(MobileLearningResume.find(owner: "host", seats: seats,
            storage: { scope in MobileStorage(directory: root.appendingPathComponent(scope)) }))
        let run = try #require(resume.state.run)
        let loader = MobileMenuPreviewLoader {
            MobileJourneyLibrary(entries: run.entries, name: run.pool.summary,
                                 catalogue: MobileCatalogue(portsRoot: ports))
        }
        await #expect(throws: (any Error).self) { try await loader.load(run.currentIndex) }
        #expect(try Data(contentsOf: savedFile) == savedBytes)
        #expect(files.load(MobileLearningState.self, name: "learning") == state)
        #expect(resume.state == state)
        #expect(resume.seat == seat && resume.seat?.turn == "guest")
        #expect(seats == originalSeats)
    }

    @Test(arguments: [LevelSourceEngine.lemmings2, .lemmings3, .neolemmix])
    func unsupportedJourneyEnginesKeepTheirSpecificFailure(engine: LevelSourceEngine) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("lemmings_dos_1991-07-30"), withIntermediateDirectories: true)
        let lesson = try entry(engine: engine)
        let catalogue = MobileCatalogue(portsRoot: root)
        #expect(MobileJourneyLibrary.sourcePack(for: lesson.identity, in: catalogue) == nil)
        let loader = MobileMenuPreviewLoader {
            MobileJourneyLibrary(entries: [lesson], name: LearningJourney.title,
                                 catalogue: MobileCatalogue(portsRoot: root))
        }
        await #expect(throws: MobileSessionError.journeyEngineUnavailable) { try await loader.load(0) }
    }
}
