import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

@MainActor struct MobileWorkerSessionTests {
    private let width = 160
    private let height = 80

    @Test func classicCrowdTargetsAndAssignsBasherToTheExistingDigger() throws {
        let game = try classicSession()
        for _ in 0..<150 where game.targetCandidates(for: 7).filter({ $0.assignment == .eligible }).count < 2 {
            game.tick()
        }
        let walking = game.targetCandidates(for: 7).filter { $0.assignment == .eligible }
        let digger = try #require(walking.first)
        let walker = try #require(walking.dropFirst().first)
        #expect(game.assign(control: 0, to: walker.id))
        #expect(game.assign(control: 7, to: digger.id))
        let candidates = game.targetCandidates(for: 5)
        #expect(candidates.first(where: { $0.id == digger.id })?.isPerformingSkill == true)
        #expect(candidates.first(where: { $0.id == walker.id })?.isPerformingSkill == false)
        let viewport = MobileViewport(levelSize: game.levelSize,
            viewSize: .init(width: Double(width), height: Double(height)), zoom: 1)
        let before = game.snapshot
        let selected = try #require(MobileTargetSelector.select(candidates: candidates,
            touch: viewport.viewPoint(fromLevel: walker.point), viewport: viewport,
            preference: game.targetPreference(for: 5, settings: .init()), favourActiveWorkers: true))
        #expect(selected.id == digger.id && selected.state == .eligible)
        #expect(game.snapshot == before)
        #expect(game.assign(control: 5, to: selected.id))
        #expect(game.finalSimulation.lemmings.first(where: { $0.id == digger.id })?.action == .bashing)
        #expect(game.finalSimulation.lemmings.first(where: { $0.id == walker.id })?.action == .walking)
    }

    @Test func nativeSkillOrderControlsBuilderAndBombPreferences() throws {
        let classic = try classicSession()
        let l2 = try l2Session()
        let neo = try neoSession()
        var settings = ClassicSettings()
        settings.favorBuilders = true
        settings.favorBombBlockers = true
        for (game, builder, bomber) in [
            (classic as any MobileGameSession, 4, 2),
            (l2 as any MobileGameSession, 4, 3),
            (neo as any MobileGameSession, 2, 0)
        ] {
            #expect(game.targetPreference(for: builder, settings: settings) == .builder)
            #expect(game.targetPreference(for: bomber, settings: settings) == .bombBlocker)
            #expect(game.targetPreference(for: -1, settings: settings) == .assignable)
        }
        settings.favorBuilders = false
        settings.favorBombBlockers = false
        #expect(classic.targetPreference(for: 4, settings: settings) == .assignable)
        #expect(l2.targetPreference(for: 4, settings: settings) == .assignable)
        #expect(l2.targetPreference(for: 3, settings: settings) == .assignable)
        #expect(neo.targetPreference(for: 2, settings: settings) == .assignable)
        #expect(neo.targetPreference(for: 0, settings: settings) == .assignable)
    }

    @Test func completedClassicBridgeRetainsPriorityThroughWalkingAndRestoresItsCheckpoint() throws {
        let game = try classicSession()
        for _ in 0..<150 where !game.targetCandidates(for: 4).contains(where: { $0.assignment == .eligible }) {
            game.tick()
        }
        let builder = try #require(game.targetCandidates(for: 4).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 0, to: builder.id))
        #expect(game.assign(control: 4, to: builder.id))
        for _ in 0..<400 where game.finalSimulation.lemmings.first(where: { $0.id == builder.id })?.action != .walking {
            game.tick()
        }
        let walking = try #require(game.finalSimulation.lemmings.first(where: { $0.id == builder.id }))
        #expect(walking.action == .walking && walking.hasClimber && walking.hasSkillTargetPriority)
        #expect(game.targetCandidates(for: 5).first(where: { $0.id == builder.id })?.isPerformingSkill == true)
        let checkpoint = try game.checkpointPayload()
        for _ in 0..<80 where game.finalSimulation.lemmings.first(where: { $0.id == builder.id })?.action != .falling {
            game.tick()
        }
        let falling = try #require(game.finalSimulation.lemmings.first(where: { $0.id == builder.id }))
        #expect(falling.action == .falling && !falling.hasSkillTargetPriority)
        #expect(game.targetCandidates(for: 5).first(where: { $0.id == builder.id })?.isPerformingSkill == false)
        for _ in 0..<80 where game.finalSimulation.lemmings.first(where: { $0.id == builder.id })?.action != .walking {
            game.tick()
        }
        let landed = try #require(game.finalSimulation.lemmings.first(where: { $0.id == builder.id }))
        #expect(landed.action == .walking && landed.hasClimber && !landed.hasSkillTargetPriority)
        try game.restoreCheckpointPayload(checkpoint)
        let restored = try #require(game.finalSimulation.lemmings.first(where: { $0.id == builder.id }))
        #expect(restored.action == .walking && restored.hasSkillTargetPriority)
        #expect(game.targetCandidates(for: 5).first(where: { $0.id == builder.id })?.isPerformingSkill == true)
    }

    @Test func l2CandidatesDistinguishActiveDiggersAndBombableBlockers() throws {
        let game = try l2Session()
        for _ in 0..<150 where !game.targetCandidates(for: 0).contains(where: { $0.assignment == .eligible }) {
            game.tick()
        }
        let digger = try #require(game.targetCandidates(for: 0).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 0, to: digger.id))
        let target = try #require(game.targetCandidates(for: 1).first(where: { $0.id == digger.id }))
        #expect(target.isPerformingSkill && !target.isBuilding && !target.isBombBlocker)
        #expect(target.assignment == .eligible)
        #expect(game.assign(control: 2, to: digger.id))
        let blocker = try #require(game.targetCandidates(for: 3).first(where: { $0.id == digger.id }))
        #expect(blocker.isPerformingSkill && blocker.isBlocking && blocker.isBombBlocker)
        #expect(blocker.assignment == .eligible)
        #expect(game.targetCandidates(for: 4).first(where: { $0.id == digger.id })?.isBombBlocker == false)
    }

    @Test func neoCandidatesUseNativeShimmyingRatherThanItsWalkingSpriteFallback() throws {
        let game = try neoSession()
        let candidates = game.targetCandidates(for: 0)
        let shimmier = try #require(candidates.first(where: { $0.id == 0 }))
        let walkingClimber = try #require(candidates.first(where: { $0.id == 1 }))
        #expect(shimmier.isPerformingSkill && !shimmier.isBuilding)
        #expect(!walkingClimber.isPerformingSkill)
        let viewport = MobileViewport(levelSize: game.levelSize,
            viewSize: .init(width: Double(width), height: Double(height)), zoom: 1)
        #expect(MobileTargetSelector.select(candidates: candidates,
            touch: viewport.viewPoint(fromLevel: walkingClimber.point), viewport: viewport,
            favourActiveWorkers: true, input: .precision)?.id == shimmier.id)
    }

    @Test func l3BlockersAreActiveWorkersWithoutBecomingBombCarriers() throws {
        let game = try l3Session()
        for _ in 0..<150 where !game.targetCandidates(for: 1).contains(where: { $0.assignment == .eligible }) {
            game.tick()
        }
        let target = try #require(game.targetCandidates(for: 1).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 1, to: target.id))
        let blocker = try #require(game.targetCandidates(for: 0).first(where: { $0.id == target.id }))
        #expect(blocker.isPerformingSkill && blocker.isBlocking && !blocker.isBombBlocker)
        #expect(blocker.assignment == .eligible)
        #expect(game.targetPreference(for: 3, settings: .init()) == .toolUser)
        #expect(game.targetPreference(for: 4, settings: .init()) == .toolHolder)
        #expect(game.targetPreference(for: 0, settings: .init()) == .assignable)
    }

    private var solid: [UInt8] {
        (0..<(width * height)).map { $0 / width >= 60 ? 1 : 0 }
    }

    private func classicSession() throws -> ClassicMobileSession {
        func mask(_ height: Int) throws -> ClassicDOSMask {
            try .init(width: 16, height: height, pixels: Data(repeating: 0, count: 16 * height))
        }
        let masks = try ClassicDOSDestructionMaskSet(explosion: mask(22),
            bashRight: (0..<4).map { _ in try mask(10) }, bashLeft: (0..<4).map { _ in try mask(10) },
            mineRight: (0..<2).map { _ in try mask(13) }, mineLeft: (0..<2).map { _ in try mask(13) })
        let simulation = try ClassicDOSSimulation(terrain: .init(width: width, height: height,
            solidMask: Data(solid), steelMask: Data(repeating: 0, count: solid.count)),
            configuration: .init(totalLemmings: 3, requiredToSave: 1, timeLimitTicks: 2_000,
                initialReleaseRate: 99, entrances: [.init(x: 40, y: 40)],
                initialSkills: [.climber: 4, .bomber: 4, .builder: 4, .basher: 4, .digger: 4],
                maximumX: width - 1, maximumY: height - 1), destructionMasks: masks)
        return .init(simulation: simulation, levelIdentifier: "worker-fixture", levelIndex: 0)
    }

    private func l2Session() throws -> Lemmings2MobileSession {
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame)
        let runtime = try Lemmings2Runtime(configuration: .init(width: width, height: height,
            pixels: solid, solid: solid.map { $0 != 0 }, palette: [UInt8](repeating: 255, count: 1_024),
            entrance: .init(x: 40, y: 40, width: 1, height: 1), exits: [.init(x: 140, y: 50, width: 16, height: 16)],
            skills: [.digger, .basher, .blocker, .bomber, .builder], supplies: [4, 4, 4, 4, 4],
            total: 3, timeLimit: 120, releaseInterval: 1, terrainMasks: masks, firstReleaseTick: 1))
        return .init(runtime: runtime, engineFingerprint: "l2", levelIdentifier: "worker-fixture",
            levelIndex: 0, levelFingerprint: "l2")
    }

    private func neoSession() throws -> NeoLemmixMobileSession {
        var terrain = try NeoLemmixTerrain(width: width, height: height)
        for y in 60..<height { for x in 0..<width { terrain.setSolid(true, x: x, y: y) } }
        terrain.setSolid(true, x: 40, y: 51)
        let simulation = try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 2, requiredToSave: 1, spawnInterval: 30, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 40, y: 60), traits: [.shimmier]),
                               .init(position: .init(x: 44, y: 60), traits: [.climber])],
            skills: [.bomber: .finite(4), .basher: .finite(4), .builder: .finite(4)]))
        return .init(simulation: simulation, controls: [.bomber, .basher, .builder], engineFingerprint: "neo",
            levelIdentifier: "worker-fixture", levelIndex: 0, levelFingerprint: "neo")
    }

    private func l3Session() throws -> Lemmings3MobileSession {
        let runtime = try Lemmings3Runtime(configuration: .init(width: width, height: height,
            attributes: solid.map { $0 == 0 ? UInt16(0x1000) : UInt16(0x20) },
            entrance: .init(x: 40, y: 40), exits: [.init(x: 140, y: 58)],
            total: 3, releaseInterval: 1, releaseDelay: 0))
        return .init(runtime: runtime, engineFingerprint: "l3", levelIdentifier: "worker-fixture",
            levelIndex: 0, levelFingerprint: "l3")
    }
}
