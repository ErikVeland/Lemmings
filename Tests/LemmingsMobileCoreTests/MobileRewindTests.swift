import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileRewindTests {
    private struct LegacyCheckpoint: Codable {
        var version = 1
        let initialStateHash: String
        let simulation: ClassicDOSSimulation
        let beforeEndRun: ClassicDOSSimulation?
    }

    @Test func oldCheckpointRestoresAfterRewindChange() throws {
        let initial = try fixture()
        var previousBuild = initial
        for _ in 0..<60 { previousBuild.tick() }
        let id = try #require(previousBuild.lemmings.first).id
        #expect(previousBuild.assign(.climber, to: id) == .assigned)
        let stored = try JSONEncoder().encode(LegacyCheckpoint(
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial),
            simulation: previousBuild, beforeEndRun: nil))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try stored.write(to: file)
        let restored = session(initial)
        try restored.restoreCheckpointPayload(Data(contentsOf: file))
        let current = try decodeSimulation(restored)
        #expect(current.tickCount == previousBuild.tickCount)
        #expect(current.lemmings == previousBuild.lemmings)
        #expect(ClassicDOSReplayRecorder.stateHash(of: current) == ClassicDOSReplayRecorder.stateHash(of: previousBuild))
        #expect(!restored.stepBackward())
        restored.tick()
        #expect(restored.stepBackward())
        #expect(try decodeSimulation(restored).lemmings == previousBuild.lemmings)
    }

    @Test func rewindThenAssignDropsTheFuture() throws {
        let game = session(try fixture())
        for _ in 0..<60 { game.tick() }
        let id = try #require(game.targetCandidates(for: 0).first).id
        #expect(game.assign(control: 0, to: id))
        for _ in 0..<10 { game.tick() }
        #expect(game.rewind(seconds: 11 / game.ticksPerSecond))
        #expect(game.assign(control: 1, to: id))
        let document = try #require(try game.replayDocument())
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: document)
        #expect(replay.events.count == 1)
        #expect(replay.events.first?.action == .assign(lemmingID: id, skill: .floater))
        #expect(game.usedRewind)
    }

    @Test func checkpointPreservesHistoryAndAbandonedFuture() throws {
        let initial = try fixture()
        let game = session(initial)
        for _ in 0..<60 { game.tick() }
        let id = try #require(game.targetCandidates(for: 0).first).id
        #expect(game.assign(control: 0, to: id))
        for _ in 0..<20 { game.tick() }
        let expected = try decodeSimulation(game)
        let restored = session(initial)
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.rewind(seconds: 2))
        for _ in 0..<Int(2 * restored.ticksPerSecond) { restored.tick() }
        #expect(ClassicDOSReplayRecorder.stateHash(of: try decodeSimulation(restored)) == ClassicDOSReplayRecorder.stateHash(of: expected))
        #expect(restored.rewind(seconds: 2))
        restored.resumeFromCurrentTick()
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: #require(try restored.replayDocument()))
        #expect(replay.events.isEmpty)
    }

    @Test func undoNukeIsAssistedAndPersistsUsage() throws {
        let initial = try fixture()
        let game = session(initial)
        for _ in 0..<60 { game.tick() }
        #expect(game.beginEndRun())
        #expect(game.undoEndRun())
        #expect(game.usedRewind)
        #expect(game.nukeCount == 1)
        #expect(game.undoCount == 1)
        let restored = session(initial)
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.usedRewind)
        #expect(restored.nukeCount == 1)
        #expect(restored.undoCount == 1)
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: #require(try restored.replayDocument()))
        #expect(!replay.events.contains { $0.action == .nuke })
    }

    @Test func winningReplayIsReadOnlyAndKeepsOutcome() throws {
        let game = session(try fixture(winning: true))
        for _ in 0..<1_000 where !game.snapshot.isComplete { game.tick() }
        #expect(game.snapshot.didWin)
        let document = try #require(try game.replayDocument())
        let review = try #require(try game.makeReplaySession(document: document))
        #expect(review.isReadOnly)
        #expect(!review.adjustReleaseRate(by: 1))
        #expect(!review.beginEndRun())
        #expect(!review.assign(control: 0, to: 0))
        for _ in 0..<1_000 where !review.snapshot.isComplete { review.tick() }
        #expect(review.snapshot.didWin)
        #expect(review.snapshot.saved == game.snapshot.saved)
        #expect(review.snapshot.tick == game.snapshot.tick)
        #expect(review.rewind(seconds: 2))
        for _ in 0..<1_000 where !review.snapshot.isComplete { review.tick() }
        #expect(review.snapshot == game.snapshot)
    }

    private func decodeSimulation(_ game: ClassicMobileSession) throws -> ClassicDOSSimulation {
        try JSONDecoder().decode(LegacyCheckpoint.self, from: game.checkpointPayload()).simulation
    }

    private func session(_ initial: ClassicDOSSimulation) -> ClassicMobileSession {
        ClassicMobileSession(simulation: initial, levelIdentifier: "fixture/1", levelIndex: 0)
    }

    private func fixture(winning: Bool = false) throws -> ClassicDOSSimulation {
        let width = 160, height = 80
        var solid = [UInt8](repeating: 0, count: width * height)
        for y in 50..<height { for x in 0..<width { solid[y * width + x] = 1 } }
        let terrain = try ClassicDOSTerrain(width: width, height: height, solidMask: Data(solid),
            steelMask: Data(repeating: 0, count: solid.count))
        let exit = ClassicDOSTrigger(id: 0, effect: .exit,
            bounds: ClassicDOSRect(x1: 30, y1: 40, x2: 40, y2: 55))
        return try ClassicDOSSimulation(terrain: terrain, configuration: ClassicDOSConfiguration(
            totalLemmings: winning ? 1 : 5, requiredToSave: 1, timeLimitTicks: 1_000,
            initialReleaseRate: 99, entrances: [.init(x: 20, y: 20)],
            triggers: winning ? [exit] : [], initialSkills: [.climber: 5, .floater: 5],
            maximumX: width - 1, maximumY: height - 1))
    }
}
