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

    @Test func practiceRestoresTheExactPanelWithoutCampaignWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let source = try Lemmings2MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let skills: [Lemmings2Runtime.Skill] = [.roper, .floater, .climber, .digger, .basher, .builder, .runner, .jumper]
        for choice in 0..<4 {
            let library = try Lemmings2PracticeMobileLibrary(source: source, choice: choice, skills: skills)
            let game = try #require(try library.loadLevel(at: 0).session as? Lemmings2MobileSession)
            #expect(game.initialRuntime.configuration.isPractice)
            #expect(game.initialRuntime.configuration.skills == skills)
            for _ in 0..<100 { game.tick() }
            let payload = try game.checkpointPayload()
            let restored = try Lemmings2PracticeMobileLibrary.restoring(game.levelIdentifier, source: source).loadLevel(at: 0).session
            try restored.restoreCheckpointPayload(payload)
            #expect(restored.snapshot == game.snapshot)
            #expect(try restored.actionCapture()?.final.hash() == game.actionCapture()?.final.hash())
            #expect(game.beginEndRun())
            for _ in 0..<3000 where !game.snapshot.isComplete { game.tick() }
        }
        #expect(storage.load(Lemmings2Campaign.Progress.self, name: "lemmings2-campaign") == nil)
        #expect(throws: (any Error).self) { try source.loadPractice(at: 0, skills: Array(repeating: .builder, count: 8)) }
    }

    @Test func shortOpeningCarriesSurvivorsAndRestoresItsOwnQueue() throws {
        struct Witness: Decodable {
            struct Input: Decodable { let tick: Int, skill: Int, lemming: Int }
            let inputs: [Input]
        }
        let root = Self.root.appendingPathComponent("Sources/Ports/Lemm2")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let entries = try Lemmings2ShortPlayMobileLibrary.entries(directory: root)
        let library = try Lemmings2ShortPlayMobileLibrary(directory: root, storage: storage, entries: entries, name: "Opening")
        #expect(throws: (any Error).self) { try library.loadLevel(at: 1) }
        let game = try #require(try library.loadLevel(at: 0).session as? Lemmings2MobileSession)
        let witness = try JSONDecoder().decode(Witness.self, from: Data(contentsOf: Self.root.appendingPathComponent("Tests/Lemmings2CompletionTests/Fixtures/classic-01.json")))
        for _ in 0..<5000 where game.snapshot.saved == 0 && !game.snapshot.isComplete {
            for input in witness.inputs where input.tick == game.snapshot.tick {
                let slot = try #require(game.initialRuntime.configuration.skills.firstIndex { $0.rawValue == input.skill })
                #expect(game.assign(control: slot, to: input.lemming))
            }
            game.tick()
        }
        #expect(game.snapshot.saved > 0)
        #expect(game.beginEndRun())
        for _ in 0..<3000 where !game.snapshot.isComplete { game.tick() }
        #expect(game.snapshot.didWin)
        #expect(game.snapshot.saved < 60)
        #expect(throws: (any Error).self) {
            try library.record(game) { _ in throw MobileSessionError.invalidCheckpoint }
        }
        #expect(throws: (any Error).self) { try library.loadLevel(at: 1) }
        let progress = try #require(try library.record(game))
        let stored = try JSONDecoder().decode(Lemmings2Campaign.Progress.self, from: progress)
        #expect(stored.results[0]?.saved == game.snapshot.saved)
        let reopened = try Lemmings2ShortPlayMobileLibrary(directory: root, storage: storage, entries: entries, name: "Opening")
        let next = try reopened.loadLevel(at: 1).session
        #expect(next.snapshot.total == game.snapshot.saved)
        #expect(try reopened.loadLevel(at: 0).session.snapshot.total == 60)
        #expect(!Lemmings2ShortPlayMobileLibrary.matches(Array(entries.reversed())))
    }

    @Test func trailsAreBoundedFadeAndClearForReducedEffects() throws {
        let frame = try MobilePixelFrame(width: 1, height: 1, rgba: Data([10, 200, 40, 255]))
        func sprites(_ x: Int) -> [Int: MobileSpriteHighlight] {
            Dictionary(uniqueKeysWithValues: (0..<12).map { ($0, .init(frame: frame,
                rect: .init(x: Double(x + $0), y: 10, width: 1, height: 1), cacheKey: "one", time: nil)) })
        }
        var trails = MobileSpriteTrails()
        for tick in 0..<10 { trails.sample(sprites(tick), tick: tick, time: Double(tick) / 100, fast: true, enabled: true, budget: 20) }
        #expect(trails.echoes.count == 20)
        trails.sample(sprites(5), tick: 5, time: 0.1, fast: false, enabled: true, budget: 20)
        #expect(trails.echoes.contains { $0.rewind })
        trails.expire(at: 1)
        #expect(trails.echoes.isEmpty)
        trails.sample(sprites(6), tick: 6, time: 1.1, fast: true, enabled: false)
        trails.sample(sprites(7), tick: 7, time: 1.2, fast: true, enabled: true)
        #expect(trails.echoes.isEmpty)
    }

    @Test func originalMediaStreamsFramesWithoutGameState() throws {
        for engine in ["lemmings2", "lemmings3"] {
            let directory = Self.root.appendingPathComponent(engine == "lemmings2" ? "Sources/Ports/Lemm2" : "Sources/Ports/LEM3CD")
            for item in MobileOriginalMedia.Item.all(engine: engine) {
                let media = try MobileOriginalMedia(item: item, directory: directory)
                let initial = media.frameCount
                try media.advance(seconds: .infinity); try media.advance(seconds: -1)
                #expect(media.frameCount == initial)
                for _ in 0..<20 {
                    media.requestContinue(); try media.advance(seconds: 0.1)
                    _ = media.drainSounds()
                }
                #expect(media.frameCount > initial)
                #expect(media.frame.rgba.count == media.frame.width * media.frame.height * 4)
                media.discardElapsedTime()
                let count = media.frameCount
                try media.advance(seconds: 0)
                #expect(media.frameCount == count)
            }
        }
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
