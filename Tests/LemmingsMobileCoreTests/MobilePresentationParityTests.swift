import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobilePresentationParityTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test func feedbackRespectsSelectionStyleReducedEffectsAndSimulationTime() throws {
        let frame = try MobilePixelFrame(width: 1, height: 1, rgba: Data([100, 220, 80, 255]))
        var feedback = MobileSpriteFeedback<Int>()
        feedback.provider = { _, id in
            .init(frame: frame, rect: .init(x: Double(id), y: 5, width: 1, height: 1), cacheKey: "fixture", time: nil)
        }
        feedback.selected = 7
        feedback.settings.lemmingSelectionStyle = .modern
        #expect(feedback.selection(in: 0, tick: 20, ticksPerSecond: 20)?.time == 1)
        feedback.settings.reduceMotion = true
        #expect(feedback.selection(in: 0, tick: 20, ticksPerSecond: 20)?.time == nil)
        feedback.settings.reduceMotion = false; feedback.settings.reduceFlashes = true
        #expect(feedback.selection(in: 0, tick: 20, ticksPerSecond: 20)?.time == nil)
        feedback.settings.lemmingSelectionStyle = .none
        #expect(feedback.selection(in: 0, tick: 20, ticksPerSecond: 20) == nil)
        feedback.assigned(to: 7, tick: 20)
        #expect(feedback.progress(at: 20, ticksPerSecond: 20) == 0)
        #expect(feedback.acknowledgement(in: 0, tick: 21, ticksPerSecond: 20)?.rect.x == 7)
        #expect(feedback.progress(at: 19, ticksPerSecond: 20) == nil)
        #expect(feedback.progress(at: 25, ticksPerSecond: 20) == nil)
        feedback.reset()
        #expect(feedback.acknowledgement(in: 0, tick: 20, ticksPerSecond: 20) == nil)
    }

    @Test @MainActor func nativeSequelLibrariesSupplyMasksAndAssignmentFeedback() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let storage = MobileStorage(directory: temporary)
        let libraries: [any MobileGameLibrary] = [
            try Lemmings2MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage),
        ]
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            var settings = ClassicSettings(); settings.lemmingSelectionStyle = .modern
            session.applySettings(settings)
            var choice: (Int, MobileTargetCandidate)?
            for _ in 0..<300 where choice == nil {
                session.tick()
                for control in session.snapshot.skills.indices where choice == nil {
                    if let target = session.targetCandidates(for: control).first(where: { $0.assignment == .eligible }) {
                        choice = (control, target)
                    }
                }
            }
            let (control, target) = try #require(choice)
            let before = try #require(try session.actionCapture()).final.hash()
            _ = try session.render(highlight: .init(id: target.id, point: target.point, state: target.assignment))
            let sprite = try #require(session.selectionSprite)
            #expect(sprite.frame.rgba.indices.contains { $0 % 4 == 3 && sprite.frame.rgba[$0] > 0 })
            #expect(sprite.rect == session.spriteHighlight(for: target.id)?.rect)
            #expect(try session.actionCapture()?.final.hash() == before)
            #expect(session.assign(control: control, to: target.id))
            #expect(session.assignmentProgress == 0)
            #expect(session.assignmentSprite != nil)
            _ = session.drainSoundCues(); _ = session.drainLemmings2SoundRequests()
            #expect(session.assignmentSprite != nil)
            let checkpoint = try session.checkpointPayload()
            try session.restoreCheckpointPayload(checkpoint)
            #expect(session.assignmentSprite == nil)
            #expect(session.selectionSprite == nil)
        }
    }

    @Test func neoCaptureReplaysRateChangesAtTheSameTickAndPreservesGhostScope() throws {
        var terrain = try NeoLemmixTerrain(width: 96, height: 40)
        for x in 0..<96 { terrain.setSolid(true, x: x, y: 24) }
        let initial = try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 2, requiredToSave: 1, spawnInterval: 30, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 20, y: 24)), .init(position: .init(x: 40, y: 24))],
            skills: [.blocker: .finite(2)]))
        let game = NeoLemmixMobileSession(simulation: initial, controls: [.blocker], engineFingerprint: "fixture",
            levelIdentifier: "neo", levelIndex: 0, levelFingerprint: "neo-fixture")
        #expect(game.actionReplayInitial != nil)
        #expect(game.adjustReleaseRate(by: 1))
        #expect(game.adjustReleaseRate(by: 2))
        game.tick()
        #expect(game.adjustReleaseRate(by: -1))
        game.tick()
        let target = try #require(game.targetCandidates(for: 0).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 0, to: target.id))
        for _ in 0..<5 { game.tick() }
        #expect(game.beginEndRun())
        for _ in 0..<500 where !game.snapshot.isComplete { game.tick() }
        #expect(game.snapshot.isComplete)
        let capture = try #require(game.actionCapture())
        var reconstruction = capture.initial
        for tick in 0...capture.final.tick {
            for command in capture.commands where command.tick == tick { try reconstruction.apply(command) }
            if tick < capture.final.tick { reconstruction.step() }
        }
        #expect(try reconstruction.hash() == capture.final.hash())
        let conditions = TrolleyConditions(gameID: "neolemmix", packID: "fixture", levelID: "1",
            levelFingerprint: "neo-fixture", rulesetVersion: "fixture", physicsMode: "fixture",
            population: capture.initial.population, rescueRequirement: 1, startingSkills: ["blocker": 2], timeLimitSeconds: nil)
        let level = ArcadeLevel(id: "neo", title: "Neo", game: "NeoLemmix", rules: "fixture",
            total: capture.initial.population, required: 1, conditions: conditions)
        let run = ArcadeRun(profileID: "first", level: level, saved: capture.final.saved,
            didWin: capture.final.didWin, skills: game.assignedSkills, seconds: Double(capture.final.tick) / game.ticksPerSecond)
        let replay = try LeaderboardActionReplay.capture(run: run, initial: capture.initial, final: capture.final, commands: capture.commands)
        var checked = try replay.checked(initial: capture.initial)
        try checked.seek(to: capture.final.tick)
        #expect(try checked.state.hash() == capture.final.hash())
        game.hotSeatGhosts = HotSeatGhostPlayback(attempts: [.init(playerID: "other", colour: .pink, replay: replay)], initial: capture.initial)
        #expect(game.hotSeatGhosts?.count == 1)
    }
}
