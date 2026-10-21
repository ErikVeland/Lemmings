import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct RecoveryPerformanceTests {
    private enum Failure: Error { case mainThread, timeout }
    private func checkpoint(tick: Int = 0) -> RunRecovery {
        .init(engine: "test", profileID: "owner", runID: UUID(), dataSetID: "lemmings", levelIndex: 0,
              levelFingerprint: "level", initialStateHash: "initial", tick: tick, events: [], stateHash: "",
              usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0, savedAt: Date(timeIntervalSinceReferenceDate: Double(tick)))
    }

    @Test func deferredHashUsesImmutableClassicAndSequelStates() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let level = try ClassicDataSet.detect(directory: directory).campaign.levels[0].level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
        var classic = try ClassicDOSSimulation(level: level, renderedLevel: scene,
            mainDATAssets: ClassicMainDATAssets.load(from: directory))
        var l2 = try lemmings2()
        var l3 = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0x1000, count: 128 * 64), entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 2, releaseInterval: 20, releaseDelay: 0))
        let capturedClassic = classic, capturedL2 = l2, capturedL3 = l3
        let builders: [@Sendable () throws -> String] = [
            { ClassicDOSReplayRecorder.stateHash(of: capturedClassic) },
            { try L2RunRecovery.stateHash(capturedL2) },
            { L3RunRecovery.stateHash(capturedL3) }
        ]
        let expected = try builders.map { try $0() }
        let storage = try AppStorage.temporary(named: "deferred-hashes")
        defer { storage.removeTemporaryFiles() }
        let store = RunRecoveryStore(directory: storage.applicationSupport)
        let gate = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        let values = builders.map { _ in checkpoint() }
        for (index, builder) in builders.enumerated() {
            store.save(values[index], prepareStateHash: {
                guard !Thread.isMainThread else { throw Failure.mainThread }
                if index == 0 {
                    entered.signal()
                    guard gate.wait(timeout: .now() + 10) == .success else { throw Failure.timeout }
                }
                return try builder()
            }) { _ in }
        }
        defer { gate.signal() }
        try #require(entered.wait(timeout: .now() + 10) == .success)
        for _ in 0..<10 { _ = classic.tick(); l2.step(); l3.step() }
        #expect(ClassicDOSReplayRecorder.stateHash(of: classic) != expected[0])
        #expect(try L2RunRecovery.stateHash(l2) != expected[1])
        #expect(L3RunRecovery.stateHash(l3) != expected[2])
        gate.signal()
        try store.checkSaveSucceeded()
        for (index, value) in values.enumerated() {
            let saved = try RunRecoveryFile(url: storage.applicationSupport.appendingPathComponent(value.runID.uuidString + ".json")).load()
            #expect(saved?.stateHash == expected[index])
            #expect(saved?.tick == value.tick && saved?.profileID == "owner")
        }
    }

    @Test func lemmings3RecoveryHashIncludesMolePatrolPhase() throws {
        let ground = [UInt16](repeating: 0x20, count: 64 * 48)
        let ready = Lemmings3Runtime.Creature(id: 1, kind: .mole, x: 32, y: 40)
        var patrolling = ready
        patrolling.molePatrolTick = 3
        func game(_ creature: Lemmings3Runtime.Creature) throws -> Lemmings3Runtime {
            try Lemmings3Runtime(configuration: .init(width: 64, height: 48, attributes: ground,
                entrance: .init(x: 4, y: 40), exits: [.init(x: 56, y: 40)], total: 1,
                releaseInterval: 1, releaseDelay: 1000, creatures: [creature]))
        }
        #expect(L3RunRecovery.stateHash(try game(ready)) != L3RunRecovery.stateHash(try game(patrolling)))
    }

    @Test func busyAutosavesCoalesceAndSessionSaveRemainsOrdered() throws {
        let storage = try AppStorage.temporary(named: "coalesced-recovery")
        defer { storage.removeTemporaryFiles() }
        let store = RunRecoveryStore(directory: storage.applicationSupport)
        let first = checkpoint(), skipped = checkpoint(tick: 1), latest = checkpoint(tick: 2)
        let gate = DispatchSemaphore(value: 0), entered = DispatchSemaphore(value: 0)
        store.save(first, coalescing: true, prepareStateHash: {
            entered.signal()
            guard gate.wait(timeout: .now() + 10) == .success else { throw Failure.timeout }
            return "first"
        }) { _ in }
        defer { gate.signal() }
        try #require(entered.wait(timeout: .now() + 10) == .success)
        store.save(skipped, coalescing: true, prepareStateHash: { "skipped" }) { _ in }
        store.save(latest, prepareStateHash: { "latest" }) { _ in }
        gate.signal()
        try store.checkSaveSucceeded()
        #expect(!FileManager.default.fileExists(atPath: storage.applicationSupport.appendingPathComponent(skipped.runID.uuidString + ".json").path))
        #expect(try store.latest(profileID: "owner")?.stateHash == "latest")
        try store.clear(latest.runID)
        #expect(try store.latest(profileID: "owner")?.stateHash == "first")
    }

    @Test func failedHashPreservesCheckpointAndAllowsRetry() throws {
        let storage = try AppStorage.temporary(named: "failed-recovery-hash")
        defer { storage.removeTemporaryFiles() }
        let store = RunRecoveryStore(directory: storage.applicationSupport)
        var value = checkpoint()
        value.stateHash = "original"
        store.save(value, immediately: true) { _ in }
        store.save(value, coalescing: true, prepareStateHash: { throw Failure.timeout }) { _ in }
        #expect(throws: Failure.self) { try store.checkSaveSucceeded() }
        #expect(try store.latest(profileID: "owner")?.stateHash == "original")
        store.save(value, coalescing: true, prepareStateHash: { "retried" }) { _ in }
        try store.checkSaveSucceeded()
        #expect(try store.latest(profileID: "owner")?.stateHash == "retried")
    }

    private func lemmings2() throws -> Lemmings2Runtime {
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame)
        return try Lemmings2Runtime(configuration: .init(width: 120, height: 80,
            pixels: [UInt8](repeating: 0, count: 9_600), solid: [Bool](repeating: false, count: 9_600),
            palette: [UInt8](repeating: 255, count: 1_024), entrance: .init(x: 20, y: 45, width: 1, height: 1),
            exits: [.init(x: 100, y: 50, width: 16, height: 16)], skills: [.jumper], supplies: [3],
            total: 2, timeLimit: 120, releaseInterval: 20, terrainMasks: masks, firstReleaseTick: 1))
    }
}
