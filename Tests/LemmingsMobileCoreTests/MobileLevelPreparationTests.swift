import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

@Suite(.serialized) struct MobileLevelPreparationTests {
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
        let task = Task.detached {
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
        let obsolete = Task.detached { try await loader.load(0) }
        await gate.waitUntilEntered()
        let neighbour = Task.detached { try await loader.load(1) }
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
    let release = DispatchSemaphore(value: 0)
    func block() {
        lock.withLock { entered = true }
        // Bound a failed test without leaving its content worker stuck.
        _ = release.wait(timeout: .now() + 5)
    }
    func waitUntilEntered() async {
        while !lock.withLock({ entered }) { await Task.yield() }
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
    init(index: Int, serial: Int) { levelIndex = index; self.serial = serial }
    var snapshot: MobileGameSnapshot {
        .init(tick: tickCount, released: 0, total: 10, saved: 0, required: 5, remainingSeconds: nil,
              releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: [])
    }
    func tick() { tickCount += 1 }
    func applySettings(_ settings: ClassicSettings) { preparedOffMain = !Thread.isMainThread }
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    func assign(control: Int, to target: Int) -> Bool { false }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 8, height: 8, rgba: Data(repeating: 0, count: 8 * 8 * 4))
    }
    func checkpointPayload() throws -> Data { Data([UInt8(tickCount)]) }
    func restoreCheckpointPayload(_ data: Data) throws { tickCount = Int(data[0]); restoredOffMain = !Thread.isMainThread }
}
