import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
import LemmingsMobileCore

struct MobileExtraSkillTests {
    @Test func classicChargeRetainsAttemptLimitAcrossCheckpointAndRewind() throws {
        let initial = try classic()
        func make() -> ClassicMobileSession {
            .init(simulation: initial, levelIdentifier: "bonus/classic", levelIndex: 0)
        }
        let game = make()
        for _ in 0..<3 { game.tick() }
        let choice = try #require(game.extraSkillChoices.first { $0.skillID == "builder" })
        #expect(!game.extraSkillChoices.contains { $0.skillID == "digger" })
        #expect(game.grantExtraSkill(choice))
        #expect(game.snapshot.skills[choice.control].count == 2)
        #expect(game.assignedSkillCount == 0)
        let restored = make()
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.snapshot == game.snapshot)
        #expect(restored.rewind(seconds: 2 / restored.ticksPerSecond))
        #expect(restored.snapshot.skills[choice.control].count == 1)
        #expect(restored.bonusSkillID == "builder")
        #expect(restored.extraSkillChoices.isEmpty)
        #expect(!restored.grantExtraSkill(choice))
        let beforeWallet = make()
        #expect(beforeWallet.retainExtraSkillUse("builder"))
        #expect(beforeWallet.snapshot.skills[choice.control].count == 1)
        #expect(beforeWallet.extraSkillChoices.isEmpty)
        #expect(!beforeWallet.retainExtraSkillUse("digger"))
    }

    @Test func tribesChargeReplaysAndRetainsAttemptLimitBeforeGrant() throws {
        let initial = try tribes()
        func make() -> Lemmings2MobileSession {
            .init(runtime: initial, engineFingerprint: "l2-fixture", levelIdentifier: "bonus/l2",
                levelIndex: 0, levelFingerprint: "bonus-l2")
        }
        let game = make()
        for _ in 0..<3 { game.tick() }
        let choice = try #require(game.extraSkillChoices.first)
        #expect(game.grantExtraSkill(choice))
        #expect(game.snapshot.skills[0].count == 2)
        #expect(game.assignedSkills.isEmpty)
        let restored = make()
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.snapshot == game.snapshot)
        #expect(restored.actionCapture()?.commands.last?.action == "bonusSkill")
        #expect(restored.rewind(seconds: 2 / restored.ticksPerSecond))
        #expect(restored.snapshot.skills[0].count == 1)
        #expect(restored.bonusSkillID == "jumper")
        #expect(restored.extraSkillChoices.isEmpty)
        let beforeGrant = make()
        try beforeGrant.restoreCheckpointPayload(restored.checkpointPayload())
        #expect(beforeGrant.extraSkillChoices.isEmpty)
        #expect(beforeGrant.bonusSkillID == "jumper")
        let beforeWallet = make()
        #expect(beforeWallet.retainExtraSkillUse("jumper"))
        #expect(beforeWallet.snapshot.skills[0].count == 1)
        #expect(beforeWallet.extraSkillChoices.isEmpty)
    }

    @Test func chroniclesChargeUsesExistingHeldToolAndRetainsAttemptLimit() throws {
        let initial = try chronicles()
        func make() -> Lemmings3MobileSession {
            .init(runtime: initial, engineFingerprint: "l3-fixture", levelIdentifier: "bonus/l3",
                levelIndex: 0, levelFingerprint: "bonus-l3")
        }
        let game = make()
        #expect(game.extraSkillChoices.isEmpty)
        for _ in 0..<3 { game.tick() }
        let choice = try #require(game.extraSkillChoices.first)
        #expect(choice.skillID == "bricks")
        #expect(game.existingLevelSkills == ["bricks"])
        let count = try #require(game.skillCursorRemaining(control: choice.control, target: choice.target))
        #expect(game.grantExtraSkill(choice))
        #expect(game.skillCursorRemaining(control: choice.control, target: choice.target) == count + 1)
        #expect(game.assignedSkillCount == 0)
        let restored = make()
        try restored.restoreCheckpointPayload(game.checkpointPayload())
        #expect(restored.skillCursorRemaining(control: choice.control, target: choice.target) == count + 1)
        #expect(restored.actionCapture()?.commands.last?.action == "bonusTool")
        #expect(restored.rewind(seconds: 3 / restored.ticksPerSecond))
        #expect(restored.bonusSkillID == "bricks")
        #expect(restored.extraSkillChoices.isEmpty)
        let beforeGrant = make()
        try beforeGrant.restoreCheckpointPayload(restored.checkpointPayload())
        #expect(beforeGrant.bonusSkillID == "bricks")
        #expect(beforeGrant.extraSkillChoices.isEmpty)
        let beforeWallet = make()
        #expect(beforeWallet.retainExtraSkillUse("bricks"))
        #expect(beforeWallet.extraSkillChoices.isEmpty)
    }

    @Test @MainActor func resultTagsBonusConditionsSeparatelyFromRewind() throws {
        let game = ClassicMobileSession(simulation: try classic(), levelIdentifier: "bonus/classic", levelIndex: 0)
        let choice = try #require(game.extraSkillChoices.first)
        #expect(game.grantExtraSkill(choice))
        let conditions = TrolleyConditions(gameID: "classic", packID: "fixture", levelID: "1", levelFingerprint: "fixture",
            rulesetVersion: "fixture", physicsMode: "fixture", population: 2, rescueRequirement: 1,
            startingSkills: ["builder": 1], timeLimitSeconds: 60)
        let level = ArcadeLevel(id: "fixture", title: "Fixture", game: "Classic", rules: "fixture", total: 2,
            required: 1, conditions: conditions)
        let run = MobileGameResult.capture(id: UUID(), profileID: "PLA", level: level, session: game)
        #expect(run.usedBonusSkill)
        #expect(!run.assisted)
        #expect(!run.earnsConsumableRewards)
        #expect(run.level.boardID != level.boardID)
        #expect(run.level.conditions?.startingSkills["builder"] == 2)
    }

    @Test func checkpointKeepsSpendingEvidenceAndReadsEarlierSaves() throws {
        let runID = UUID()
        let conditions = TrolleyConditions(gameID: "classic", packID: "fixture", levelID: "1", levelFingerprint: "fixture",
            rulesetVersion: "fixture", physicsMode: "fixture", population: 2, rescueRequirement: 1,
            startingSkills: ["builder": 1], timeLimitSeconds: 60)
        let start = TrolleyStart(id: runID, profileID: "PLA", conditions: conditions,
            date: Date(timeIntervalSince1970: 2_000), kind: .restartDuringPlay)
        let use = ExtraSkillUse(attemptID: runID, skill: "builder", originalConditions: conditions, start: start)
        var envelope = MobileCheckpointEnvelope(runID: runID, engine: "classic-dos", engineFingerprint: "fixture",
            levelIdentifier: "fixture/1", levelIndex: 0, levelFingerprint: "fixture", tick: 3,
            selectedControl: 4, camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data([1]),
            owner: "PLA", extraSkillUse: use)
        let encoded = try JSONEncoder().encode(envelope.validated())
        let restored = try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: encoded).validated()
        #expect(restored.extraSkillUse == use)
        #expect(restored.owner == "PLA")
        var earlier = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        earlier.removeValue(forKey: "extraSkillUse")
        let earlierData = try JSONSerialization.data(withJSONObject: earlier)
        let earlierEnvelope = try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: earlierData).validated()
        #expect(earlierEnvelope.extraSkillUse == nil)
        envelope.extraSkillUse = .init(attemptID: UUID(), skill: "builder", originalConditions: conditions)
        var rejected = false
        do { _ = try envelope.validated() }
        catch { rejected = error as? MobileCheckpointError == .invalid }
        #expect(rejected)
    }

    private func classic() throws -> ClassicDOSSimulation {
        let width = 160, height = 80
        var solid = [UInt8](repeating: 0, count: width * height)
        for y in 50..<height { for x in 0..<width { solid[y * width + x] = 1 } }
        let terrain = try ClassicDOSTerrain(width: width, height: height, solidMask: Data(solid),
            steelMask: Data(repeating: 0, count: solid.count))
        return try ClassicDOSSimulation(terrain: terrain, configuration: .init(totalLemmings: 2,
            requiredToSave: 1, timeLimitTicks: 1_000, initialReleaseRate: 50,
            entrances: [.init(x: 20, y: 20)], initialSkills: [.builder: 1], maximumX: width - 1, maximumY: height - 1))
    }

    private func tribes() throws -> Lemmings2Runtime {
        let width = 120, height = 80
        var pixels = [UInt8](repeating: 0, count: width * height)
        var solid = [Bool](repeating: false, count: width * height)
        for y in 60..<height { for x in 0..<width { pixels[y * width + x] = 6; solid[y * width + x] = true } }
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame)
        return try Lemmings2Runtime(configuration: .init(width: width, height: height, pixels: pixels, solid: solid,
            palette: [UInt8](repeating: 255, count: 1_024), entrance: .init(x: 20, y: 45, width: 1, height: 1),
            exits: [.init(x: 100, y: 50, width: 16, height: 16)], skills: [.jumper], supplies: [1], total: 2,
            timeLimit: 120, releaseInterval: 20, terrainMasks: masks, firstReleaseTick: 1))
    }

    private func chronicles() throws -> Lemmings3Runtime {
        let width = 128, height = 64
        var attributes = [UInt16](repeating: 0x1000, count: width * height)
        for y in 48..<height { for x in 0..<width { attributes[y * width + x] = 0x20 } }
        return try Lemmings3Runtime(configuration: .init(width: width, height: height, attributes: attributes,
            entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 20,
            releaseDelay: 1_000, pickups: [.init(id: 0, tool: .bricks, x: 20, y: 48)],
            extras: [.init(x: 20, y: 48, direction: 1)]))
    }
}
