import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

@MainActor struct PlatformParityClosureTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private func neo() throws -> NeoLemmixMobileSession {
        var terrain = try NeoLemmixTerrain(width: 160, height: 64)
        for x in 0..<160 { terrain.setSolid(true, x: x, y: 40) }
        let simulation = try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 3, requiredToSave: 1, spawnInterval: 30, entrances: [.init(id: 0, position: .init(x: 12, y: 40))],
            preplacedLemmings: [.init(position: .init(x: 40, y: 40))], skills: [.builder: .finite(3)]))
        return .init(simulation: simulation, controls: [.builder], engineFingerprint: "neo-fixture",
            levelIdentifier: "neo-fixture", levelIndex: 0, levelFingerprint: "neo-fixture")
    }

    @Test func earlyNeoNukeCompletesWithoutInventingUnreleasedDeaths() throws {
        let game = try neo()
        let before = game.snapshot
        #expect(game.beginEndRun())
        for _ in 0..<200 where !game.snapshot.isComplete { game.tick() }
        #expect(game.snapshot.isComplete)
        #expect(game.snapshot.released == before.released)
        #expect(game.lostLemmingCount == 1)
        let captured = try #require(game.actionCapture())
        var replay = captured.initial
        for tick in 0...captured.final.tick {
            for command in captured.commands where command.tick == tick { try replay.apply(command) }
            if tick < captured.final.tick { replay.step() }
        }
        #expect(try replay.hash() == captured.final.hash())
    }

    @Test func neoBonusChargeSurvivesCheckpointAndRewindWithoutAnotherGrant() throws {
        let game = try neo()
        game.tick()
        let choice = try #require(game.extraSkillChoices.first)
        #expect(game.grantExtraSkill(choice))
        #expect(game.snapshot.skills[0].count == 4)
        let restored = try neo()
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.snapshot == game.snapshot)
        #expect(restored.bonusSkillID == "builder")
        #expect(restored.stepBackward())
        #expect(restored.snapshot.skills[0].count == 3)
        #expect(restored.extraSkillChoices.isEmpty)
        #expect(!restored.grantExtraSkill(choice))
    }

    @Test func allNonClassicSessionsReviewExactInputsAndKeepPlaybackReadOnly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let l2 = try Lemmings2MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let l3 = try Lemmings3MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        let games: [any MobileGameSession] = [try l2.loadLevel(at: 0).session, try l3.loadLevel(at: 0).session, try neo()]
        for game in games {
            var assigned = false
            for _ in 0..<300 where !assigned {
                game.tick()
                for control in game.snapshot.skills.indices where !assigned {
                    if let target = game.targetCandidates(for: control).first(where: { $0.assignment == .eligible }) {
                        assigned = game.assign(control: control, to: target.id)
                    }
                }
            }
            #expect(assigned)
            if let tribes = game as? Lemmings2MobileSession {
                tribes.setAim(at: .init(x: 100, y: 40), held: true)
                tribes.setFan(at: .init(x: 90, y: 30), active: true)
                game.tick()
                tribes.releasePointerInput()
            }
            let checkpoint = try game.checkpointPayload()
            let start = game.snapshot.tick
            for _ in 0..<10 { game.tick() }
            let partial = try #require(try game.replayDocument())
            let review = try #require(try game.makeReplaySession(document: partial))
            #expect(review.isReadOnly)
            #expect(review.seekReplay(to: start))
            #expect(review.replaySkillUses.count > 0)
            #expect(!review.assign(control: 0, to: 0))
            #expect(!review.beginEndRun())
            #expect(review.seekReplay(to: try #require(review.replayEndTick)))
            #expect(review.snapshot == game.snapshot || review.snapshot.isComplete)
            #expect(review.seekReplay(to: 0))
            try game.restoreCheckpointPayload(checkpoint)
            #expect(game.beginEndRun())
            for _ in 0..<3000 where !game.snapshot.isComplete { game.tick() }
            #expect(game.snapshot.isComplete)
            let end = game.snapshot
            let full = try #require(try game.replayDocument())
            let player = try #require(try game.makeReplaySession(document: full))
            #expect(player.seekReplay(to: end.tick))
            #expect(player.snapshot.saved == end.saved)
            #expect(player.snapshot.didWin == end.didWin)
            #expect(!player.stepForward())
            #expect(player.stepBackward())
            #expect(player.seekReplay(to: end.tick))
            #expect(game.snapshot == end)
        }
    }
}
