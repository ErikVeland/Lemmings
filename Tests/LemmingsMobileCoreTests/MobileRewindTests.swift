import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileRewindTests {
    @Test func slicedClassicSeeksPreserveSameTickCommandsAndCancelWithoutMutation() throws {
        let game = session(try fixture())
        for _ in 0..<60 { game.tick() }
        let actor = try #require(game.targetCandidates(for: 0).first).id
        #expect(game.assign(control: 0, to: actor))
        #expect(game.assign(control: 1, to: actor))
        let expected = ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation)
        for _ in 0..<65 { game.tick() }
        let original = ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation)
        let cancelled = try #require(game.prepareSeek(to: 20))
        _ = try cancelled.advance(seconds: 0)
        cancelled.cancel()
        #expect(throws: CancellationError.self) { try cancelled.advance() }
        #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == original)
        let document = try #require(try game.replayDocument())
        let operation = try #require(game.prepareSeek(to: 60, backwardSteps: 3))
        while try !operation.advance(seconds: 0) {
            #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == original)
        }
        #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == expected)
        #expect(game.rewindCount == 3)
        #expect(game.usedRewind)
        let review = try #require(try game.makeReplaySession(document: document))
        for _ in 0..<100 { review.tick() }
        let replaySeek = try #require(review.prepareSeek(to: 60))
        while try !replaySeek.advance(seconds: 0) {}
        let restored = try #require(review as? ClassicMobileSession)
        #expect(ClassicDOSReplayRecorder.stateHash(of: restored.finalSimulation) == expected)
        #expect(review.replaySkillUses == [.init(tick: 60, name: "Climber"), .init(tick: 60, name: "Floater")])
    }

    @Test func pointerProbesMatchAssignmentsWithoutChangingTheRun() throws {
        var simulation = try fixture()
        for _ in 0..<70 { simulation.tick() }
        let id = try #require(simulation.lemmings.first).id
        for skill in ClassicSkill.allCases { _ = simulation.assign(skill, to: id) }
        for _ in 0..<50 {
            let before = ClassicDOSReplayRecorder.stateHash(of: simulation)
            for skill in ClassicSkill.allCases {
                let results = simulation.assignmentResults(for: skill)
                for (index, lemming) in simulation.lemmings.enumerated() {
                    let result = simulation.assignmentResult(skill, to: lemming.id)
                    #expect(results[index] == result)
                    var probe = simulation
                    #expect(result == probe.assign(skill, to: lemming.id))
                }
            }
            #expect(simulation.assignmentResult(.builder, to: -1) == .noSuchLemming)
            #expect(ClassicDOSReplayRecorder.stateHash(of: simulation) == before)
            simulation.tick()
        }
    }

    @Test func backgroundCheckpointKeepsTheCapturedDiggerState() async throws {
        let initial = try fixture()
        let game = session(initial)
        for _ in 0..<120 where !game.targetCandidates(for: 7).contains(where: { $0.assignment == .eligible }) {
            game.tick()
        }
        let target = try #require(game.targetCandidates(for: 7).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 7, to: target.id))
        let expected = game.snapshot
        let state = ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation)
        let captured = game.prepareCheckpointPayload()
        let encoding = Task.detached { try captured.encode() }
        for _ in 0..<30 { game.tick() }
        #expect(game.snapshot.tick > expected.tick)
        #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) != state)
        let restored = session(initial)
        try restored.restoreCheckpointPayload(try await encoding.value)
        #expect(restored.snapshot == expected)
        #expect(ClassicDOSReplayRecorder.stateHash(of: restored.finalSimulation) == state)
        #expect(restored.stepBackward())
    }
    @Test func sparseOlderHistoryReconstructsExactLongRunStates() throws {
        var terrain = try NeoLemmixTerrain(width: 4096, height: 64)
        for x in 0..<4096 { terrain.setSolid(true, x: x, y: 48) }
        let initial = try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 1, requiredToSave: 1, spawnInterval: 30, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 30, y: 48))], skills: [.builder: .infinite]))
        let game = NeoLemmixMobileSession(simulation: initial, controls: [.builder], engineFingerprint: "history",
            levelIdentifier: "history", levelIndex: 0, levelFingerprint: "history")
        var expected: [Int: MobileGameSnapshot] = [:]
        let targets: Set<Int> = [101, 700, 1400, 1900]
        for tick in 1...2200 {
            game.tick()
            if targets.contains(tick) { expected[tick] = game.snapshot }
        }
        #expect(game.snapshot.tick == 2200)
        for target in targets.sorted(by: >) {
            let distance = game.snapshot.tick - target
            #expect(game.rewind(seconds: Double(distance) / game.ticksPerSecond))
            #expect(game.snapshot == expected[target])
            let independent = NeoLemmixMobileSession(simulation: initial, controls: [.builder], engineFingerprint: "history",
                levelIdentifier: "history", levelIndex: 0, levelFingerprint: "history")
            for _ in 0..<target { independent.tick() }
            #expect(try game.actionCapture()?.final.hash() == independent.actionCapture()?.final.hash())
        }
    }

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

    @Test func replayHistoryShowsOnlySuccessfulUsesAndFollowsSeeking() throws {
        let game = session(try fixture())
        for _ in 0..<60 { game.tick() }
        let ids = game.targetCandidates(for: 0).map(\.id)
        #expect(ids.count >= 2)
        #expect(game.assign(control: 0, to: ids[0]))
        #expect(!game.assign(control: 0, to: ids[0]))
        game.tick()
        #expect(game.assign(control: 1, to: ids[0]))
        game.tick()
        #expect(game.assign(control: 0, to: ids[1]))
        game.tick()
        #expect(game.assign(control: 1, to: ids[1]))
        game.tick()
        #expect(game.replaySkillUses.isEmpty)
        let document = try #require(try game.replayDocument())
        let review = try #require(try game.makeReplaySession(document: document))
        for _ in 0..<game.snapshot.tick { review.tick() }
        #expect(review.replaySkillUses == [.init(tick: 61, name: "Floater"), .init(tick: 62, name: "Climber"), .init(tick: 63, name: "Floater")])
        #expect(review.rewind(seconds: 4 / review.ticksPerSecond))
        #expect(review.replaySkillUses == [.init(tick: 60, name: "Climber")])
        #expect(!review.assign(control: 1, to: ids[0]))
        let unchanged = try JSONDecoder().decode(ClassicDOSReplay.self, from: #require(try game.replayDocument()))
        #expect(unchanged == (try JSONDecoder().decode(ClassicDOSReplay.self, from: document)))
    }

    @Test func replayHistoryIncludesLegacyScheduledAssignments() throws {
        let initial = try fixture()
        let game = session(initial)
        for _ in 0..<60 { game.tick() }
        let id = try #require(game.targetCandidates(for: 0).first).id
        let replay = ClassicDOSReplay(rank: "", number: 1, title: "Legacy",
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial), events: [
                .init(tick: 60, action: .assign(lemmingID: id, skill: .climber)),
                .init(tick: 61, action: .assign(lemmingID: id, skill: .climber), afterTick: true),
                .init(tick: 62, action: .assign(lemmingID: id, skill: .floater), afterTick: true)])
        let review = try #require(try game.makeReplaySession(document: JSONEncoder().encode(replay)))
        for _ in 0..<64 { review.tick() }
        #expect(review.replaySkillUses == [.init(tick: 60, name: "Climber"), .init(tick: 62, name: "Floater")])
        #expect(review.rewind(seconds: 3 / review.ticksPerSecond))
        #expect(review.replaySkillUses == [.init(tick: 60, name: "Climber")])
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
            triggers: winning ? [exit] : [], initialSkills: [.climber: 5, .floater: 5, .digger: 5],
            maximumX: width - 1, maximumY: height - 1))
    }
}
