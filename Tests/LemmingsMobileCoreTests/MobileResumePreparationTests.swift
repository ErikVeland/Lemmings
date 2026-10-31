import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileResumePreparationTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    private static let hasSequelLevels = ["Sources/Ports/Lemm2/LEVELS/LEVEL000.DAT", "Sources/Ports/LEM3CD/LEVELS/LEVEL001.DAT"]
        .allSatisfy { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }

    @MainActor @Test(.enabled(if: Self.hasSequelLevels), arguments: [false, true])
    func beachResumeRestoresTheExactAttempt(withCachedPreview: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storage = MobileStorage(directory: directory.appendingPathComponent("campaign"))
        let source = Self.root.appendingPathComponent("Sources/Ports/Lemm2")
        let loader = MobileMenuPreviewLoader { try Lemmings2MobileLibrary(directory: source, storage: storage) }
        let opened = try await loader.prepare(10)
        let session = opened.content.session
        #expect(opened.content.summary.title == "Quad Quirks on the Quay!")
        for _ in 0..<2000 { session.tick() }
        #expect(!session.snapshot.isComplete)
        let expected = try #require(try session.actionCapture()).final.hash()
        let checkpoint = MobileCheckpointEnvelope(runID: UUID(), engine: session.engineIdentifier,
            engineFingerprint: session.engineFingerprint, levelIdentifier: session.levelIdentifier,
            levelIndex: 10, levelFingerprint: session.levelFingerprint, tick: session.snapshot.tick,
            selectedControl: 2, camera: .init(origin: .init(x: 320, y: 0), zoom: 2),
            payload: try session.checkpointPayload(), scope: "hotseat:resume-fixture", owner: "resume-fixture")
        let file = directory.appendingPathComponent("reopened-checkpoint.json")
        try JSONEncoder().encode(checkpoint).write(to: file)
        let reopened = try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: Data(contentsOf: file))
        let fresh = MobileMenuPreviewLoader { try Lemmings2MobileLibrary(directory: source, storage: storage) }
        if withCachedPreview {
            let preview = try await fresh.load(10)
            #expect(preview.snapshot.tick == 0)
            #expect(preview.frame.width > 0 && preview.frame.height > 0)
        }
        let restored = try await fresh.prepare(10, checkpoint: reopened)
        #expect(restored.content.session.snapshot == session.snapshot)
        #expect(try restored.content.session.actionCapture()?.final.hash() == expected)
        #expect(reopened.runID == checkpoint.runID && reopened.owner == checkpoint.owner && reopened.scope == checkpoint.scope)
        #expect(reopened.camera == checkpoint.camera && reopened.selectedControl == 2)
        #expect(restored.content.session.stepBackward())
        restored.content.session.tick()
        #expect(try restored.content.session.actionCapture()?.final.hash() == expected)
    }

    @MainActor @Test(.enabled(if: Self.hasSequelLevels)) func cancelledNativeSequelRestoreDoesNotReplaceTheSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let libraries: [any MobileGameLibrary] = [
            try Lemmings2MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        ]
        for library in libraries {
            let session = try library.loadLevel(at: library is Lemmings2MobileLibrary ? 10 : 0).session
            for _ in 0..<80 { session.tick() }
            let payload = try session.checkpointPayload()
            session.tick()
            let before = session.snapshot
            let task = Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                try session.restoreCheckpointPayload(payload)
            }
            await #expect(throws: CancellationError.self) { try await task.value }
            #expect(session.snapshot == before)
            try session.restoreCheckpointPayload(payload)
            #expect(session.snapshot.tick == 80)
        }
    }
}
