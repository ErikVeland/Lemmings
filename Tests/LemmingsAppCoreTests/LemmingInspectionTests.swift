import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor struct LemmingInspectionTests {
    @Test func permanentSkillsRemainMilestonesAfterReturningToWalking() throws {
        for initial in try starts().prefix(2) {
            var current = initial
            for _ in 0..<20 { current.step() }
            var commands: [LeaderboardActionReplay.Command] = []
            let expected: [String]
            switch current {
            case .classic(var game):
                // The Classic hatch opens later than the sequel hatch.
                while game.lemmings.first?.action != .walking && game.tickCount < 200 { _ = game.tick() }
                let id = try #require(game.lemmings.first?.id)
                for skill in [ClassicSkill.climber, .floater] {
                    let result = game.assign(skill, to: id)
                    #expect(result == .assigned)
                    commands.append(.init(tick: game.tickCount, action: "assign", lemming: id,
                        skill: try #require(ClassicSkill.allCases.firstIndex(of: skill))))
                }
                #expect(game.lemmings[0].hasClimber && game.lemmings[0].hasFloater)
                current = .classic(game)
                expected = ["Became a Climber", "Became a Floater"]
            case .lemmings2(var game):
                while game.lemmings.first?.state != .walking && game.tick < 200 { game.step() }
                let id = try #require(game.lemmings.first?.id)
                for skill in [Lemmings2Runtime.Skill.climber, .rockClimber, .floater, .parachuter] {
                    let slot = try #require(game.configuration.skills.firstIndex(of: skill))
                    let accepted = game.assign(slot: slot, to: id)
                    #expect(accepted)
                    commands.append(.init(tick: game.tick, action: "assign", lemming: id, skill: slot))
                }
                #expect(game.lemmings[0].climber && game.lemmings[0].parachuter)
                current = .lemmings2(game)
                expected = ["Became a Climber", "Became a Rock Climber", "Became a Floater", "Became a Parachuter"]
            default: continue
            }
            for _ in 0..<3 { current.step() }
            let snapshot = try LemmingInspection(initial: initial, current: current, commands: commands)
            let actor = try #require(snapshot.individuals.first)
            #expect(actor.status == "Walking")
            #expect(actor.actions.map(\.title) == expected)
            #expect(actor.actions.allSatisfy { $0.ticksSinceUse == 3 })
            #expect(snapshot.lines(for: 0).contains { $0.contains("Became a Climber: 3 ticks ago") })
            let rewound = try LemmingInspection(initial: initial, current: initial, commands: commands)
            #expect(rewound.individuals.allSatisfy { $0.actions.isEmpty })
        }
    }

    @Test func skillAgesUseExactSimulationTicksAndFollowRewindAcrossAllThreeEngines() throws {
        for initial in try starts() {
            var current = initial
            for _ in 0..<80 { current.step() }
            let id = try #require(try LemmingInspection(initial: initial, current: current, commands: []).individuals.first?.id)
            let end = current.tick
            let commands = (0...2).map { age in
                LeaderboardActionReplay.Command(tick: end - 2 + age,
                    action: initial.engine == "lemmings3" ? "walker" : "assign", lemming: id, skill: 0)
            }
            let snapshot = try LemmingInspection(initial: initial, current: current, commands: commands)
            let actions = try #require(snapshot.individuals.first { $0.id == id }?.actions)
            #expect(actions.map(\.ticksSinceUse) == [2, 1, 0])
            #expect(actions[0].text.contains("2 ticks ago"))
            #expect(actions[1].text.contains("1 tick ago"))
            #expect(actions[2].text.contains("0 ticks ago"))
            #expect(actions.allSatisfy { $0.text.contains($0.title) })
            var earlier = initial
            for _ in 0..<(end - 1) { earlier.step() }
            let rewound = try LemmingInspection(initial: initial, current: earlier, commands: commands)
            #expect(rewound.individuals.first { $0.id == id }?.actions.map(\.ticksSinceUse) == [1, 0])
        }
    }

    @Test func l3ToolNamesComeFromRecordedEquipmentAndLegacyInputsRemainReadable() throws {
        let initial = try starts()[2]
        var current = initial
        for _ in 0..<20 { current.step() }
        let id = try #require(try LemmingInspection(initial: initial, current: current, commands: []).individuals.first?.id)
        let recorded = L3RunRecovery.Input(tick: current.tick - 1, action: "use", lemming: id,
            direction: "up", tool: Lemmings3Runtime.Tool.bricks.rawValue)
        let restored = try JSONDecoder().decode(L3RunRecovery.Input.self, from: JSONEncoder().encode(recorded))
        #expect(restored.tool == Lemmings3Runtime.Tool.bricks.rawValue)
        let legacy = try JSONDecoder().decode(L3RunRecovery.Input.self,
            from: Data(#"{"tick":0,"action":"use","lemming":0,"direction":"up"}"#.utf8))
        #expect(legacy.tool == nil)
        let snapshot = try LemmingInspection(initial: initial, current: current,
            commands: [.l3(legacy), .l3(restored)])
        #expect(snapshot.individuals.first?.actions.last?.title == "Bricks")
        #expect(snapshot.individuals.first?.actions.last?.ticksSinceUse == 1)
        #expect(snapshot.individuals.first?.actions.first?.title == "Used a tool")
    }

    @Test func stableIdentityAndReadOnlyInspectionAcrossThreeEngines() throws {
        for initial in try starts() {
            var current = initial
            for _ in 0..<80 { current.step() }
            let before = try current.hash()
            let first = try LemmingInspection(initial: initial, current: current, commands: [])
            let retry = try LemmingInspection(initial: initial, current: current, commands: [])
            #expect(!first.individuals.isEmpty)
            #expect(first.individuals == retry.individuals)
            #expect(try current.hash() == before)
            #expect(first.individuals.allSatisfy { !$0.name.isEmpty && !$0.want.isEmpty && !$0.preference.isEmpty })
            let names = Dictionary(uniqueKeysWithValues: first.individuals.map { ($0.id, $0.name) })
            current.step()
            let later = try LemmingInspection(initial: initial, current: current, commands: [])
            for actor in later.individuals where names[actor.id] != nil {
                #expect(actor.name == names[actor.id])
            }
        }
    }

    @Test func currentBranchExcludesFutureAndGlobalActions() throws {
        for initial in try starts() {
            var current = initial
            for _ in 0..<80 { current.step() }
            let id = try #require(try LemmingInspection(initial: initial, current: current, commands: []).individuals.first?.id)
            let isL3 = initial.engine == "lemmings3"
            let actionTick = max(0, current.tick - 1)
            let commands: [LeaderboardActionReplay.Command] = [
                .init(tick: actionTick, action: isL3 ? "walker" : "assign", lemming: id, skill: 0),
                .init(tick: current.tick + 1, action: isL3 ? "blocker" : "assign", lemming: id, skill: 0),
                .init(tick: actionTick, action: "nuke"),
                .init(tick: actionTick, action: "fan", x: 10, y: 10),
                .init(tick: actionTick, action: "assign", lemming: id, skill: -1)
            ]
            let inspected = try LemmingInspection(initial: initial, current: current, commands: commands)
            let actor = try #require(inspected.individuals.first { $0.id == id })
            #expect(actor.actions.count == 1)
            #expect(actor.actions.first?.tick == actionTick)
            #expect(actor.actions.first?.title.isEmpty == false)
            var earlier = initial
            for _ in 0..<max(0, actionTick - 1) { earlier.step() }
            let rewound = try LemmingInspection(initial: initial, current: earlier, commands: commands)
            #expect(rewound.individuals.allSatisfy { $0.actions.isEmpty })
        }
    }

    @Test func actionPagesReachEntireHistoryAndEmptyHatchesRemainEmpty() throws {
        let initial = try starts()[0]
        let empty = try LemmingInspection(initial: initial, current: initial, commands: [])
        #expect(empty.individuals.isEmpty)
        #expect(empty.lines(for: 0).count == 1)
        var current = initial
        for _ in 0..<80 { current.step() }
        let id = try #require(try LemmingInspection(initial: initial, current: current, commands: []).individuals.first?.id)
        let commands = (60..<73).map { LeaderboardActionReplay.Command(tick: $0, action: "assign", lemming: id, skill: 0) }
        let snapshot = try LemmingInspection(initial: initial, current: current, commands: commands)
        let individual = try #require(snapshot.individuals.first)
        #expect(individual.actions.count == 13)
        #expect(LemmingInspection.lastHistoryPage(for: individual) == 2)
        #expect(snapshot.lines(for: 0).count == 9)
        #expect(snapshot.lines(for: 0, historyPage: 2).count == 7)
        #expect(snapshot.lines(for: 0, historyPage: Int.max) == snapshot.lines(for: 0, historyPage: 2))
    }

    private func starts() throws -> [ActionReplayState] {
        let width = 512, height = 96
        var solid = Data(repeating: 0, count: width * height)
        for x in 0..<width { solid[48 * width + x] = 1 }
        let classic = try ClassicDOSSimulation(terrain: .init(width: width, height: height, solidMask: solid,
            steelMask: Data(repeating: 0, count: solid.count)), configuration: .init(totalLemmings: 3,
                requiredToSave: 1, timeLimitTicks: 1_000, initialReleaseRate: 50,
                entrances: [.init(x: 100, y: 30)], initialSkills: [.climber: 20, .floater: 20], maximumX: width - 1, maximumY: height - 1))
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame)
        var floor = [Bool](repeating: false, count: 9_600)
        for x in 0..<120 { floor[60 * 120 + x] = true }
        let l2 = try Lemmings2Runtime(configuration: .init(width: 120, height: 80,
            pixels: [UInt8](repeating: 0, count: 9_600), solid: floor,
            palette: [UInt8](repeating: 255, count: 1_024), entrance: .init(x: 20, y: 45, width: 1, height: 1),
            exits: [.init(x: 100, y: 50, width: 16, height: 16)],
            skills: [.jumper, .climber, .rockClimber, .floater, .parachuter], supplies: [20, 20, 20, 20, 20],
            total: 2, timeLimit: 120, releaseInterval: 20, terrainMasks: masks, firstReleaseTick: 1))
        var attributes = [UInt16](repeating: 0, count: 128 * 64)
        for y in 48..<64 { for x in 0..<128 { attributes[y * 128 + x] = 0x20 } }
        let l3 = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: attributes, entrance: .init(x: 20, y: 30), exits: [.init(x: 110, y: 46)],
            total: 2, releaseInterval: 20, releaseDelay: 0))
        return [.classic(classic), .lemmings2(l2), .lemmings3(l3)]
    }
}
