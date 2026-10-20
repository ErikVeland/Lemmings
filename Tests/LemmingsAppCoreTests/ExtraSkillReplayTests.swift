import Foundation
import Testing
import LemmingsAppCore
import NxlvKit

struct ExtraSkillReplayTests {
    private func classic() throws -> ClassicDOSSimulation {
        let terrain = try ClassicDOSTerrain(width: 96, height: 64,
            solidMask: Data(repeating: 0, count: 96 * 64), steelMask: Data(repeating: 0, count: 96 * 64))
        return try .init(terrain: terrain, configuration: .init(totalLemmings: 1, requiredToSave: 1,
            timeLimitTicks: 20, initialReleaseRate: 50, entrances: [.init(x: 20, y: 10)],
            initialSkills: [.climber: 1, .floater: 1], maximumX: 95, maximumY: 63))
    }

    private func conditions() -> TrolleyConditions {
        .init(gameID: "lemmings", packID: "bonus-replay", levelID: "fixture", levelFingerprint: "fixture",
            rulesetVersion: "fixture", physicsMode: "fixture", population: 1, rescueRequirement: 1,
            startingSkills: ["climber": 1, "floater": 1], timeLimitSeconds: 20)
    }

    private func run(_ conditions: TrolleyConditions) -> ArcadeRun {
        .init(profileID: ArcadeProfile.legacyID,
            level: .init(id: "fixture", title: "Fixture", game: "lemmings", rules: "fixture",
                total: 1, required: 1, conditions: conditions),
            saved: 0, didWin: false, skills: [:], seconds: 20.0 / 17,
            telemetry: .init(released: 0))
    }

    @Test(.enabled(if: !RunRecovery.bundledEngine.isEmpty, "Requires the bundled engine fingerprint"))
    func classicBonusReplaysAndHostedAdapterKeepTheGrant() throws {
        let initial = try classic()
        var final = initial
        let granted = final.grantBonusSkill(.climber)
        #expect(granted)
        while !final.isComplete { final.tick() }
        let bonus = try #require(conditions().addingBonusSkill("climber"))
        let command = try LeaderboardActionReplay.Command.classic(.init(tick: 0,
            action: .bonusSkill(.climber), afterTick: true))
        let replay = try LeaderboardActionReplay.capture(run: run(bonus), initial: .classic(initial),
            final: .classic(final), commands: [command])
        var checked = try replay.checked(initial: .classic(initial))
        try checked.seek(to: replay.ticks)
        #expect(try checked.state.hash() == ActionReplayState.classic(final).hash())
        let hosted = try JSONDecoder().decode(ClassicDOSReplay.self,
            from: replay.classicReplay(initial: initial, title: "Fixture"))
        let outcome = try ClassicDOSReplayPlayer.run(hosted, simulation: initial)
        #expect(outcome.stateHash == ClassicDOSReplayRecorder.stateHash(of: final))
    }

    @Test(.enabled(if: !RunRecovery.bundledEngine.isEmpty, "Requires the bundled engine fingerprint"))
    func replayBonusCommandsRequireMatchingProvenanceAndCannotRepeat() throws {
        let initial = try classic()
        var final = initial
        let granted = final.grantBonusSkill(.climber)
        #expect(granted)
        while !final.isComplete { final.tick() }
        let command = try LeaderboardActionReplay.Command.classic(.init(tick: 0,
            action: .bonusSkill(.climber), afterTick: true))
        #expect(throws: RunRecoveryError.self) {
            try LeaderboardActionReplay.capture(run: run(conditions()), initial: .classic(initial),
                final: .classic(final), commands: [command])
        }
        let mismatched = try #require(conditions().addingBonusSkill("floater"))
        let wrong = try LeaderboardActionReplay.capture(run: run(mismatched), initial: .classic(initial),
            final: .classic(final), commands: [command])
        #expect(throws: RunRecoveryError.self) { try wrong.checked(initial: .classic(initial)) }
        let bonus = try #require(conditions().addingBonusSkill("climber"))
        #expect(throws: RunRecoveryError.self) {
            try LeaderboardActionReplay.capture(run: run(bonus), initial: .classic(initial),
                final: .classic(final), commands: [command, command])
        }
        var branch = initial
        while !branch.isComplete { branch.tick() }
        let discarded = try LeaderboardActionReplay.capture(run: run(bonus), initial: .classic(initial),
            final: .classic(branch), commands: [])
        _ = try discarded.checked(initial: .classic(initial))
    }

    @Test func l3RecoveryAddsOneChargeAndChecksTheRecordedTool() throws {
        let width = 128, height = 64
        var attributes = [UInt16](repeating: 0x1000, count: width * height)
        for y in 48..<height { for x in 0..<width { attributes[y * width + x] = 0x20 } }
        let initial = try Lemmings3Runtime(configuration: .init(width: width, height: height,
            attributes: attributes, entrance: .init(x: 100, y: 40), exits: [.init(x: 110, y: 46)],
            total: 1, releaseInterval: 1000, releaseDelay: 1000,
            pickups: [.init(id: 0, tool: .bricks, x: 20, y: 48)], extras: [.init(x: 20, y: 47, direction: 1)]))
        let input = L3RunRecovery.Input(tick: 2, action: "bonusTool", lemming: 0, direction: nil,
            tool: Lemmings3Runtime.Tool.bricks.rawValue)
        let decoded = try JSONDecoder().decode(L3RunRecovery.Input.self, from: JSONEncoder().encode(input))
        let replayed = try L3RunRecovery.replay(initial: initial, inputs: [decoded], through: 2)
        #expect(replayed.lemmings[0].quantity == 9 && replayed.bonusTool == .bricks)
        var live = initial
        live.step(); live.step()
        let wrongTool = L3RunRecovery.apply(.init(tick: 2, action: "bonusTool", lemming: 0, direction: nil,
            tool: Lemmings3Runtime.Tool.grenade.rawValue), to: &live)
        #expect(!wrongTool && !live.bonusSkillUsed)
        let accepted = L3RunRecovery.apply(decoded, to: &live)
        #expect(accepted && L3RunRecovery.stateHash(live) == L3RunRecovery.stateHash(replayed))
        let duplicate = L3RunRecovery.apply(decoded, to: &live)
        #expect(!duplicate)
    }

    @Test func checkpointKeepsBonusSpendingAcrossBranchesAndRejectsMissingEvidence() throws {
        let initial = try classic(), id = UUID()
        var game = initial
        let granted = game.grantBonusSkill(.climber)
        #expect(granted)
        for _ in 0..<5 { game.tick() }
        let original = conditions()
        let use = ExtraSkillUse(attemptID: id, skill: "climber", originalConditions: original)
        var checkpoint = RunRecovery(engine: "fixture", profileID: ArcadeProfile.legacyID, runID: id,
            dataSetID: "lemmings", levelIndex: 0, levelFingerprint: original.levelFingerprint,
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial), tick: 5,
            events: [.init(tick: 0, action: .bonusSkill(.climber), afterTick: true)],
            stateHash: ClassicDOSReplayRecorder.stateHash(of: game), usedRewind: false,
            nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0,
            classicState: game, extraSkillUse: use)
        let decoded = try JSONDecoder().decode(RunRecovery.self, from: JSONEncoder().encode(checkpoint))
        #expect(try decoded.validated().extraSkillUse == use)
        checkpoint.extraSkillUse = nil
        #expect(throws: RunRecoveryError.self) { try checkpoint.validated() }
        checkpoint.extraSkillUse = .init(attemptID: UUID(), skill: "climber", originalConditions: original)
        #expect(throws: RunRecoveryError.self) { try checkpoint.validated() }
        checkpoint.extraSkillUse = .init(attemptID: id, skill: "floater", originalConditions: original)
        #expect(throws: RunRecoveryError.self) { try checkpoint.validated() }
        let branch = RunRecovery(engine: "fixture", profileID: ArcadeProfile.legacyID, runID: id,
            dataSetID: "lemmings", levelIndex: 0, levelFingerprint: original.levelFingerprint,
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial), tick: 0, events: [],
            stateHash: ClassicDOSReplayRecorder.stateHash(of: initial), usedRewind: true,
            nukeCount: 0, rewindCount: 1, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0,
            classicState: initial, extraSkillUse: use)
        #expect(try branch.validated().extraSkillUse == use)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(branch)) as! [String: Any]
        legacy.removeValue(forKey: "extraSkillUse")
        let old = try JSONDecoder().decode(RunRecovery.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(try old.validated().extraSkillUse == nil)
    }

    @Test func winningBonusReplayCannotBecomeAStandardVerifiedSolution() throws {
        let width = 128, height = 80
        var solid = Data(repeating: 0, count: width * height)
        for y in 50..<height { for x in 0..<width { solid[y * width + x] = 1 } }
        let initial = try ClassicDOSSimulation(terrain: .init(width: width, height: height,
            solidMask: solid, steelMask: Data(repeating: 0, count: solid.count)),
            configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: 300,
                initialReleaseRate: 50, entrances: [.init(x: 20, y: 20)],
                triggers: [.init(id: 0, effect: .exit, bounds: .init(x1: 0, y1: 40, x2: width, y2: 60))],
                initialSkills: [.climber: 1], maximumX: width - 1, maximumY: height - 1))
        func winningReplay(_ start: ClassicDOSSimulation, events: [ClassicDOSReplayEvent]) throws -> ClassicDOSReplay {
            let candidate = ClassicDOSReplay(rank: "Test", number: 1, title: "Winning bonus",
                initialStateHash: ClassicDOSReplayRecorder.stateHash(of: start), events: events)
            let outcome = try ClassicDOSReplayPlayer.run(candidate, simulation: start)
            #expect(outcome.didWin && outcome.saved == 1)
            return .init(rank: candidate.rank, number: candidate.number, title: candidate.title,
                initialStateHash: candidate.initialStateHash, events: events, expected: outcome)
        }
        let ordinary = try winningReplay(initial, events: [])
        #expect(VerifiedSolution.validate(ordinary, initial: initial) != nil)
        let bonus = try winningReplay(initial, events: [.init(tick: 0,
            action: .bonusSkill(.climber), afterTick: true)])
        let replayed = try ClassicDOSReplayPlayer.run(bonus, simulation: initial)
        #expect(replayed.didWin && replayed == bonus.expected)
        #expect(VerifiedSolution.validate(bonus, initial: initial) == nil)
        var grantedInitial = initial
        let granted = grantedInitial.grantBonusSkill(.climber)
        #expect(granted)
        let carried = try winningReplay(grantedInitial, events: [])
        #expect(VerifiedSolution.validate(carried, initial: grantedInitial) == nil)
    }
}
