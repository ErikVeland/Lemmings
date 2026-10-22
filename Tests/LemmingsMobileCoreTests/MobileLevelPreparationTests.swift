import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

@Suite struct MobileLevelPreparationTests {
    @MainActor @Test func libraryOpeningRunsOffUIThread() async throws {
        let loader = MobileLibraryLoader()
        let opened = try await loader.open {
            #expect(!Thread.isMainThread)
            return PreparationLibrary()
        }
        #expect(opened.library?.levels.count == 4)
    }

    @Test func cancelledLibraryOpeningDoesNotTransferStaleContent() async throws {
        let gate = PreparationGate()
        let loader = MobileLibraryLoader()
        let task = Task {
            try await loader.open {
                gate.block()
                return PreparationLibrary()
            }
        }
        await gate.waitUntilEntered()
        task.cancel()
        gate.release.signal()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func cancelledPreviewDoesNotCacheItsSessionOrDelayQueuedPlay() async throws {
        let gate = PreparationGate()
        let loader = MobileMenuPreviewLoader { PreparationLibrary(onLoad: { index in
            if index == 0 { gate.block() }
        }) }
        let obsolete = Task { try await loader.load(0) }
        await gate.waitUntilEntered()
        let neighbour = Task { try await loader.load(1) }
        obsolete.cancel()
        neighbour.cancel()
        gate.release.signal()
        await #expect(throws: CancellationError.self) { try await obsolete.value }
        await #expect(throws: CancellationError.self) { try await neighbour.value }
        let playing = try await loader.prepare(1)
        #expect((playing.content.session as? PreparationSession)?.serial == 2)
    }

    @Test func previewTransfersPreparedSessionOnceAndRetryStartsFresh() async throws {
        let loader = MobileMenuPreviewLoader { PreparationLibrary() }
        let preview = try await loader.load(0)
        let first = try await loader.prepare(0)
        #expect(preview.snapshot.tick == 0)
        #expect((first.content.session as? PreparationSession)?.serial == 1)
        first.content.session.tick()
        let retry = try await loader.prepare(0)
        #expect((retry.content.session as? PreparationSession)?.serial == 2)
        #expect(retry.content.session.snapshot.tick == 0)
        #expect(first.content.session !== retry.content.session)
        #expect((first.content.session as? PreparationSession)?.preparedOffMain == true)
    }

    @Test func boundedPreviewCacheAndMemoryWarningReleasePreparedSessions() async throws {
        let loader = MobileMenuPreviewLoader { PreparationLibrary() }
        for index in 0..<4 { _ = try await loader.load(index) }
        let evicted = try await loader.prepare(0)
        #expect((evicted.content.session as? PreparationSession)?.serial == 5)
        let retained = try await loader.prepare(3)
        #expect((retained.content.session as? PreparationSession)?.serial == 4)
        await loader.releaseCaches()
        let released = try await loader.prepare(2)
        #expect((released.content.session as? PreparationSession)?.serial == 6)
    }

    @Test func previewsRenderSelectedArtworkAndRefreshWithoutReplacingPreparedRun() async throws {
        let loader = MobileMenuPreviewLoader { PreparationLibrary() }
        var settings = ClassicSettings()
        var frames = Set<Data>()
        for source in [ClassicGraphicsSource.amiga, .macintosh, .macintoshMonochrome, .dosVGA, .amiga] {
            settings.graphics = source
            let preview = try await loader.load(0, settings: settings)
            #expect(preview.frame.rgba.first == PreparationSession.artworkPixel(source))
            #expect(preview.snapshot.tick == 0)
            #expect(try await loader.load(0, settings: settings).frame == preview.frame)
            frames.insert(preview.frame.rgba)
        }
        #expect(frames.count == 4)
        let prepared = try await loader.prepare(0, settings: settings)
        #expect((prepared.content.session as? PreparationSession)?.serial == 1)
        #expect((prepared.content.session as? PreparationSession)?.preparedOffMain == true)
    }

    @Test func nativePreviewCropKeepsTheSameLevelCoordinates() throws {
        let session = PreparationSession(index: 0, serial: 1)
        let frame = try MobilePixelFrame(width: 3200, height: 320, rgba: Data(repeating: 0, count: 3200 * 320 * 4))
        let preview = MobileMenuPreview(frame: frame, origin: .init(x: 100, y: 0),
                                        snapshot: session.snapshot, renderScale: 2)
        #expect(preview.sourceRect == .init(x: 200, y: 0, width: 640, height: 320))
        let edge = MobileMenuPreview(frame: frame, origin: .init(x: 2000, y: 0),
                                     snapshot: session.snapshot, renderScale: 2)
        #expect(edge.sourceRect == .init(x: 2560, y: 0, width: 640, height: 320))
    }

    @Test func tallPreviewUsesOpeningViewAndClampsBothEdges() throws {
        let frame = try MobilePixelFrame(width: 1000, height: 800, rgba: Data(repeating: 0, count: 1000 * 800 * 4))
        #expect(MobileMenuPreview.sourceRect(frame: frame, origin: .init(x: 100, y: 150), renderScale: 2)
            == .init(x: 200, y: 300, width: 640, height: 320))
        #expect(MobileMenuPreview.sourceRect(frame: frame, origin: .init(x: -100, y: -150), renderScale: 2)
            == .init(x: 0, y: 0, width: 640, height: 320))
        #expect(MobileMenuPreview.sourceRect(frame: frame, origin: .init(x: 1000, y: 800), renderScale: 2)
            == .init(x: 360, y: 480, width: 640, height: 320))
        let small = try MobilePixelFrame(width: 100, height: 80, rgba: Data(repeating: 0, count: 100 * 80 * 4))
        #expect(MobileMenuPreview.sourceRect(frame: small, origin: .init(x: 50, y: 50), renderScale: 1)
            == .init(x: 0, y: 0, width: 100, height: 80))
    }

    @Test func savedRunRestoresOnWorkerAndRejectsChangedData() async throws {
        let loader = MobileMenuPreviewLoader { PreparationLibrary() }
        let checkpoint = MobileCheckpointEnvelope(runID: UUID(), engine: "fixture", engineFingerprint: "engine",
            levelIdentifier: "level/0", levelIndex: 0, levelFingerprint: "revision",
            tick: 9, selectedControl: 0, camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data([9]))
        let restored = try await loader.prepare(0, checkpoint: checkpoint)
        #expect(restored.content.session.snapshot.tick == 9)
        #expect((restored.content.session as? PreparationSession)?.restoredOffMain == true)
        await #expect(throws: MobileSessionError.changedLevel) { try await loader.prepare(1, checkpoint: checkpoint) }
        let unrelated = try await loader.prepare(1, checkpoint: checkpoint, allowUnrelatedCheckpoint: true)
        #expect(unrelated.content.session.snapshot.tick == 0)
    }
}

private final class PreparationLibrary: MobileGameLibrary {
    let displayName = "Fixture"
    let levels = (0..<4).map { MobileLevelSummary(index: $0, rank: "Fixture", number: $0 + 1, title: "Level") }
    private var serial = 0
    private let onLoad: @Sendable (Int) -> Void
    init(onLoad: @escaping @Sendable (Int) -> Void = { _ in }) { self.onLoad = onLoad }
    func loadLevel(at index: Int) throws -> MobileLevelContent {
        onLoad(index)
        serial += 1
        return .init(summary: levels[index], session: PreparationSession(index: index, serial: serial))
    }
}

private final class PreparationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    let release = DispatchSemaphore(value: 0)
    func block() {
        let ready = lock.withLock {
            entered = true
            let ready = waiters
            waiters.removeAll()
            return ready
        }
        for waiter in ready { waiter.resume() }
        // Allow the parent to run when the shared CI suite saturates its executor.
        #expect(release.wait(timeout: .now() + 30) == .success)
    }
    func waitUntilEntered() async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock {
                if entered { return true }
                waiters.append(continuation)
                return false
            }
            if ready { continuation.resume() }
        }
    }
}

private final class PreparationSession: MobileGameSession {
    let engineIdentifier = "fixture", engineFingerprint = "engine", levelFingerprint = "revision"
    let levelIndex: Int, serial: Int
    var levelIdentifier: String { "level/\(levelIndex)" }
    let levelSize = MobileSize(width: 8, height: 8)
    let ticksPerSecond = 17.0
    var tickCount = 0
    var preparedOffMain = false, restoredOffMain = false
    private var graphics = ClassicGraphicsSource.dosVGA
    static func artworkPixel(_ source: ClassicGraphicsSource) -> UInt8 {
        switch source {
        case .dosVGA: 1
        case .amiga: 2
        case .macintosh: 3
        case .macintoshMonochrome: 4
        default: 5
        }
    }
    init(index: Int, serial: Int) { levelIndex = index; self.serial = serial }
    var snapshot: MobileGameSnapshot {
        .init(tick: tickCount, released: 0, total: 10, saved: 0, required: 5, remainingSeconds: nil,
              releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: [])
    }
    func tick() { tickCount += 1 }
    func applySettings(_ settings: ClassicSettings) {
        preparedOffMain = !Thread.isMainThread
        graphics = settings.graphics
    }
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    func assign(control: Int, to target: Int) -> Bool { false }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 8, height: 8, rgba: Data(repeating: Self.artworkPixel(graphics), count: 8 * 8 * 4))
    }
    func checkpointPayload() throws -> Data { Data([UInt8(tickCount)]) }
    func restoreCheckpointPayload(_ data: Data) throws { tickCount = Int(data[0]); restoredOffMain = !Thread.isMainThread }
}
