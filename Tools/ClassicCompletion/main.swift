import CryptoKit
import Foundation
import NxlvKit

// Proves three things the project could not previously show:
//   1. The engine can actually complete an official level.
//   2. A recorded replay reproduces its result exactly.
//   3. A replay survives a JSON round trip unchanged.

private struct ReplayFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw ReplayFailure(description: message()) }
}

private struct Content {
    let campaign: ClassicCampaign
    let assets: ClassicMainDATAssets
    let grounds: [Int: ClassicGroundSet]
    let specials: [Int: ClassicSpecialGraphic]

    init(directory: URL) throws {
        if ProcessInfo.processInfo.environment["CLASSIC_COMPLETION_FAMILY"] == "1" {
            let dataSet = try ClassicDataSet.detect(directory: directory)
            campaign = dataSet.campaign
        } else {
            campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
        }
        assets = try ClassicMainDATAssets.load(from: directory)
        var grounds: [Int: ClassicGroundSet] = [:]
        for style in Set(campaign.levels.map { $0.level.groundStyle }) {
            grounds[style] = try ClassicGroundSet.load(style: style, from: directory)
        }
        self.grounds = grounds
        var specials: [Int: ClassicSpecialGraphic] = [:]
        for index in Set(campaign.levels.map { $0.level.specialStyle }).filter({ $0 != 0 }) {
            specials[index] = try ClassicSpecialGraphic.load(index: index - 1, from: directory)
        }
        self.specials = specials
    }

    func simulation(at index: Int) throws -> (ClassicDOSSimulation, ClassicCampaignLevel) {
        let entry = campaign.levels[index]
        let level = entry.level
        guard let ground = grounds[level.groundStyle] else {
            throw ReplayFailure(description: "missing ground style \(level.groundStyle)")
        }
        let rendered = try ClassicLevelRenderer.render(
            level, groundSet: ground, specialGraphic: specials[level.specialStyle])
        let simulation = try ClassicDOSSimulation(
            level: level, renderedLevel: rendered, mainDATAssets: assets)
        return (simulation, entry)
    }
}

// Every witness must complete the unmodified retail level and reproduce exactly.
private func run(_ replay: ClassicDOSReplay, base: ClassicDOSSimulation) throws -> ClassicDOSReplayOutcome {
    var simulation = base
    try require(replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: base), "initial state mismatch")
    let grouped = Dictionary(grouping: replay.events, by: \.tick)
    for event in replay.events {
        try require(event.tick > 0, "invalid event tick")
        if case let .assign(id, skill) = event.action {
            try require(simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)), "assignment rejected")
        }
    }
    while !simulation.isComplete && simulation.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        let tick = simulation.tickCount + 1
        for event in grouped[tick] ?? [] {
            switch event.action {
            case let .releaseRate(value): simulation.setReleaseRate(value)
            case .nuke: simulation.beginNuke()
            case .assign: break
            }
        }
        var applied = simulation.tick()
        for event in grouped[tick] ?? [] {
            if case let .assign(id, skill) = event.action {
                guard let index = applied.firstIndex(of: .skillAssigned(lemmingID: id, skill: skill)) else {
                    throw ReplayFailure(description: "assignment did not apply at tick \(tick)")
                }
                applied.remove(at: index)
            }
        }
        if simulation.lostCount > simulation.configuration.totalLemmings - simulation.configuration.requiredToSave {
            throw ReplayFailure(description: "too many losses")
        }
    }
    try require(simulation.isComplete && simulation.didWin, "level did not complete with a win")
    try require(replay.events.allSatisfy { $0.tick <= simulation.tickCount }, "unconsumed inputs")
    let outcome = ClassicDOSReplayOutcome(ticks: simulation.tickCount, released: simulation.releasedCount,
        saved: simulation.savedCount, required: simulation.configuration.requiredToSave,
        didWin: simulation.didWin, stateHash: ClassicDOSReplayRecorder.stateHash(of: simulation))
    if let expected = replay.expected { try require(expected == outcome, "outcome mismatch") }
    return outcome
}

private func appliedInputs(_ inputs: [ClassicDOSReplayEvent], base: ClassicDOSSimulation) -> [ClassicDOSReplayEvent] {
    var sim = base
    var result: [ClassicDOSReplayEvent] = []
    let grouped = Dictionary(grouping: inputs, by: \.tick)
    while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        let tick = sim.tickCount + 1
        for event in grouped[tick] ?? [] {
            switch event.action {
            case let .releaseRate(value): sim.setReleaseRate(value); result.append(event)
            case .nuke: sim.beginNuke(); result.append(event)
            case .assign: break
            }
        }
        _ = sim.tick()
        for event in grouped[tick] ?? [] {
            if case let .assign(id, skill) = event.action, sim.assign(skill, to: id) == .assigned { result.append(event) }
        }
    }
    return result
}

// Discovery policies only emit ordinary player inputs. A fresh replay validates every result.
private let discoveryTrace = ProcessInfo.processInfo.environment["CLASSIC_DISCOVERY_TRACE"] != nil
private func tutorialInputs(base: ClassicDOSSimulation, index: Int, parameter: Int) -> [ClassicDOSReplayEvent] {
    var sim = base
    var events: [ClassicDOSReplayEvent] = []
    let nessyInput: InputCandidate? = index == 73 ? try? JSONDecoder().decode(InputCandidate.self, from: Data(contentsOf: URL(fileURLWithPath: "Tools/ClassicCompletion/Plans/taxing-14-route.json"))) : nil
    let nessyCues = (nessyInput?.cues ?? []).filter { $0.id == 0 && $0.skill != .bomber && $0.skill != .blocker }
    var nessyStep = 0
    var wallDigger = 1
    if index == 89 || index == 100 {
        sim.setReleaseRate(80)
        events.append(.init(tick: 1, action: .releaseRate(80)))
    }
    while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        _ = sim.tick()
        for lem in sim.lemmings where lem.isActive {
            var skill: ClassicSkill?
            let x = lem.foot.x, y = lem.foot.y, dx = lem.direction.rawValue
            if discoveryTrace && lem.id < 2 && sim.tickCount % 100 == 0 { print("TRACE", parameter, sim.tickCount, lem.id, lem.foot, lem.action, dx) }
            switch index {
            case 73:
                if lem.id == 1 && nessyStep < nessyCues.count {
                    let cue = nessyCues[nessyStep]
                    if cue.x == 1458 { if x == 1363 && lem.action == .shrugging { skill = .builder } }
                    else if x == cue.x && abs(y - cue.y) <= 1 { skill = cue.skill }
                } else {
                    if lem.id == 0 && x == 209 && lem.action == .walking && sim.remainingSkillCount(.digger) > 0 { skill = .digger }
                    else if lem.action == .digging && y >= parameter { skill = .builder }
                    else if lem.id == 0 && nessyStep >= nessyCues.count && x >= 203 && x <= 215 && y > 118 && dx == 1 && lem.action == .walking { skill = .builder }
                }
                if lem.id == 1 && nessyStep >= nessyCues.count && lem.action == .shrugging && x < 1455 { skill = .builder }
            case 50:
                if lem.id == 1 && x == 690 && lem.action == .walking && sim.remainingSkillCount(.blocker) == base.remainingSkillCount(.blocker) { skill = .blocker }
                if lem.id == 0 && [.walking, .shrugging, .bashing].contains(lem.action) {
                    let nx = x + dx * parameter
                    if !(0...40).contains(where: { sim.terrain.isSolid(x: nx, y: y + $0) }) { skill = .builder }
                    else if lem.action == .walking && (1...6).contains(where: { sim.terrain.isSolid(x: x + dx * $0, y: y - 6) }) { skill = .basher }
                }
                if sim.lemmings.first?.foot.x ?? 0 >= 940 {
                    if x == 678 && dx == 1 && lem.action == .walking && sim.remainingSkillCount(.miner) == base.remainingSkillCount(.miner) { skill = .miner }
                    if lem.action == .mining && x >= 690 { skill = .builder }
                }
            case 33:
                if lem.id == 0 {
                    if !lem.hasClimber { skill = .climber }
                    else if !lem.hasFloater { skill = .floater }
                    else if x == 925 && dx == 1 && sim.remainingSkillCount(.builder) == base.remainingSkillCount(.builder) { skill = .builder }
                    else if x > 940 && (lem.action == .walking || lem.action == .shrugging) {
                        let nx = x + dx * parameter
                        if !(0...60).contains(where: { sim.terrain.isSolid(x: nx, y: y + $0) }) { skill = .builder }
                    }
                }
                if lem.id == wallDigger && wallDigger <= 6 && sim.tickCount >= 2200 {
                    if !lem.hasClimber { if x == 740 && dx == 1 { skill = .climber } }
                    else if !lem.hasFloater { skill = .floater }
                    else if x == 805 - wallDigger * 8 && lem.action == .walking { skill = .digger }
                }
            case 1: if !lem.hasFloater { skill = .floater }
            case 2:
                if lem.action == .walking {
                    let nx = x + dx * parameter
                    let landing = (0...64).first { sim.terrain.isSolid(x: nx, y: y + $0) }
                    if landing == nil { skill = .blocker }
                }
            case 3:
                if !lem.hasClimber { skill = .climber }
                else if lem.id == 0 && lem.action == .walking && sim.remainingSkillCount(.miner) == base.remainingSkillCount(.miner) && sim.tickCount >= parameter { skill = .miner }
            case 83:
                if lem.action == .walking || lem.action == .shrugging {
                    let nx = x + dx * parameter
                    let landing = (0...60).first { sim.terrain.isSolid(x: nx, y: y + $0) }
                    if (landing == nil && x < 607) || (dx == -1 && x == 690 && y >= 138) { skill = .builder }
                }
            case 5:
                if lem.action == .blocking && lem.bomberCountdown == nil { skill = .bomber }
                else if lem.action == .walking && ((y == 68 && x >= 640 && sim.remainingSkillCount(.bomber) == 5) || (y == 92 && x >= parameter && sim.remainingSkillCount(.bomber) == 4)) { skill = .blocker }
            case 4:
                if lem.action == .walking && (1...6).contains(where: { sim.terrain.isSolid(x: x + dx * $0, y: y - 6) }) { skill = .basher }
            case 12, 31, 89, 100:
                if lem.action == .walking && x >= parameter - lem.id * ((index == 89 || index == 100) ? 5 : 9) && dx == 1 && !events.contains(where: { $0.action == .assign(lemmingID: lem.id, skill: .digger) }) { skill = .digger }
            default: return []
            }
            if let skill, sim.assign(skill, to: lem.id) == .assigned {
                if index == 73 && lem.id == 1 { nessyStep += 1 }
                if index == 33 && skill == .digger { wallDigger += 1 }
                events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill)))
                if discoveryTrace { print("INPUT", parameter, sim.tickCount, lem.id, lem.foot, skill) }
                break
            }
        }
        if sim.lostCount > sim.configuration.totalLemmings - sim.configuration.requiredToSave { break }
    }
    if discoveryTrace { print("DISCOVERY RESULT",parameter,sim.savedCount,sim.lostCount,sim.lemmings.filter { $0.isActive }.prefix(5).map { "\($0.id) \($0.foot) \($0.action)" }) }
    return events
}

private struct PlanStep: Decodable {
    let skill: ClassicSkill
    let id: Int?
    let x: Int?
    let y: Int?
    let direction: Int?
    let action: String?
    let tick: Int?
}
private func plannedInputs(_ steps: [PlanStep], base: ClassicDOSSimulation, releaseRate: Int?, releaseRateTick: Int = 1) -> [ClassicDOSReplayEvent] {
    var sim = base
    var result: [ClassicDOSReplayEvent] = []
    var index = 0
    var lastID = 0
    while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        if let releaseRate, sim.tickCount + 1 == releaseRateTick { sim.setReleaseRate(releaseRate); result.append(.init(tick: releaseRateTick, action: .releaseRate(releaseRate))) }
        _ = sim.tick()
        guard index < steps.count else { continue }
        let step = steps[index]
        for lem in sim.lemmings where lem.isActive {
            if let id = step.id, lem.id != (id == -1 ? lastID : id) { continue }
            if let x = step.x, lem.foot.x != x { continue }
            if let y = step.y, lem.foot.y != y { continue }
            if let direction = step.direction, lem.direction.rawValue != direction { continue }
            if let action = step.action, lem.action.rawValue != action { continue }
            if let tick = step.tick, sim.tickCount < tick { continue }
            if sim.assign(step.skill, to: lem.id) == .assigned {
                result.append(.init(tick: sim.tickCount, action: .assign(lemmingID: lem.id, skill: step.skill)))
                print("STEP", index, sim.tickCount, lem.id, step.skill, lem.foot, lem.action)
                lastID = lem.id
                index += 1
                break
            }
        }
    }
    try? JSONEncoder().encode(result).write(to: URL(fileURLWithPath: ".build/classic-completion/last-plan-events.json"))
    print("PLAN", index, "of", steps.count, "saved", sim.savedCount, "lost", sim.lostCount)
    return result
}

private struct Cue: Decodable { let tick: Int; let id: Int; let skill: ClassicSkill; let x: Int; let y: Int }
private struct InputCandidate: Decodable { let title: String; let events: [ClassicDOSReplayEvent]; let cues: [Cue]? }

private func guidedInputs(_ input: InputCandidate, base: ClassicDOSSimulation, tolerance: Int) -> [ClassicDOSReplayEvent] {
    var sim = base
    var result: [ClassicDOSReplayEvent] = []
    let cues = input.cues ?? []
    var done = Set<Int>()
    let grouped = Dictionary(grouping: input.events, by: \.tick)
    while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        let tick = sim.tickCount + 1
        for event in grouped[tick] ?? [] {
            switch event.action {
            case let .releaseRate(value): sim.setReleaseRate(value); result.append(event)
            case .nuke: break
            case .assign: break
            }
        }
        _ = sim.tick()
        for (index, cue) in cues.enumerated() where !done.contains(index) && abs(cue.tick - tick) <= 120 {
            guard let lem = sim.lemmings.first(where: { $0.id == cue.id }),
                abs(lem.foot.x - cue.x) <= tolerance, abs(lem.foot.y - cue.y) <= tolerance else { continue }
            if sim.assign(cue.skill, to: cue.id) == .assigned {
                result.append(.init(tick: tick, action: .assign(lemmingID: cue.id, skill: cue.skill)))
                done.insert(index)
                break
            }
        }
    }
    return result
}

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "verify"
let directory = URL(fileURLWithPath: args.count > 2 ? args[2] : ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/lemmings_dos_1991-07-30")
let fixtures = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLASSIC_COMPLETION_FIXTURES"] ?? "Tests/ClassicDOSCompletionTests/Fixtures")
let selected = args.count > 3 ? Int(args[3]) : nil
let familyMode = ProcessInfo.processInfo.environment["CLASSIC_COMPLETION_FAMILY"] == "1"
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
do {
    try require(["verify", "verify-known", "augment", "polish", "maximize", "maximize-adapt", "maximize-guided", "search", "solve", "import", "adapt", "guided", "tutorial", "plan", "refresh"].contains(mode), "unknown mode")
    if mode == "plan" { try require(args.count > 4 && selected != nil, "plan requires a level and a plan file") }
    if familyMode {
        try require(ProcessInfo.processInfo.environment["CLASSIC_COMPLETION_FIXTURES"] != nil, "family mode requires a separate fixture directory")
        try require(mode != "tutorial", "tutorial policies apply only to the original campaign")
    }
    let content = try Content(directory: directory)
    if !familyMode { try require(content.campaign.levels.count == 120, "expected 120 retail levels") }
    if args.count > 3 { try require(selected != nil && (1...content.campaign.levels.count).contains(selected!), "level is outside the campaign") }
    try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
    var related: [String: Set<String>] = [:]
    for index in content.campaign.levels.indices {
        let (simulation, entry) = try content.simulation(at: index)
        let key = SHA256.hash(data: simulation.terrain.solidMask + simulation.terrain.steelMask).description
        related[key, default: []].insert(entry.level.title.trimmingCharacters(in: .whitespaces).lowercased())
    }
    var failures = 0
    var verified = 0
    var uncovered = 0
    for index in content.campaign.levels.indices where selected == nil || selected == index + 1 {
        let (base, entry) = try content.simulation(at: index)
        let name = String(format: "%@-%02d.json", entry.rank.lowercased(), entry.number)
        let file = fixtures.appendingPathComponent(name)
        if mode == "verify-known" && !FileManager.default.fileExists(atPath: file.path) {
            uncovered += 1; continue
        }
        let title = entry.level.title.trimmingCharacters(in: .whitespaces)
        func candidate(_ events: [ClassicDOSReplayEvent], expected: ClassicDOSReplayOutcome? = nil) -> ClassicDOSReplay {
            ClassicDOSReplay(rank: entry.rank, number: entry.number, title: title,
                initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: events, expected: expected)
        }
        var replay = try? JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
        if mode == "refresh", let existing = replay {
            do {
                let outcome = try run(candidate(existing.events), base: base)
                let witness = candidate(existing.events, expected: outcome)
                _ = try run(witness, base: content.simulation(at: index).0)
                try encoder.encode(witness).write(to: file, options: .atomic)
                replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
            } catch { print("REFRESH FAILED \(entry.rank) \(entry.number): \(error)") }
        }
        if mode != "verify", let existing = replay, (try? run(existing, base: base)) == nil { replay = nil }
        if mode == "augment", let existing = replay, existing.expected!.saved < base.configuration.totalLemmings {
            for event in existing.events {
                guard case let .assign(id, skill) = event.action, skill == .builder else { continue }
                for delta in 1...400 where replay!.expected!.saved < base.configuration.totalLemmings {
                    let events = (existing.events + [.init(tick: event.tick + delta, action: .assign(lemmingID: id, skill: .builder))]).sorted { $0.tick < $1.tick }
                    if let outcome = try? run(candidate(events), base: base), outcome.saved > replay!.expected!.saved {
                        let improved = candidate(events, expected: outcome)
                        _ = try run(improved, base: content.simulation(at: index).0)
                        try encoder.encode(improved).write(to: file, options: .atomic)
                        replay = improved
                        print("AUGMENTED", entry.rank, entry.number, outcome.saved, id, event.tick + delta); fflush(nil)
                    }
                }
            }
        }
        if mode == "polish", let existing = replay, existing.expected!.saved < base.configuration.totalLemmings {
            var best = existing
            for _ in 0..<3 {
                let startSaved = best.expected!.saved
                let seed = best.events
                for eventIndex in seed.indices where best.expected!.saved < base.configuration.totalLemmings {
                    for offset in [0, -1, 1, -2, 2, -4, 4, -8, 8, -16, 16, -32, 32, -64, 64, -128, 128, 256, 512, 1024] {
                        var events = seed
                        if offset == 0 { events.remove(at: eventIndex) }
                        else { events[eventIndex] = .init(tick: max(1, seed[eventIndex].tick + offset), action: seed[eventIndex].action) }
                        events.sort { $0.tick < $1.tick }
                        if let outcome = try? run(candidate(events), base: base), outcome.saved > best.expected!.saved {
                            best = candidate(events, expected: outcome)
                            _ = try run(best, base: content.simulation(at: index).0)
                            try encoder.encode(best).write(to: file, options: .atomic)
                            replay = best
                            print("IMPROVED", entry.rank, entry.number, outcome.saved, "event", eventIndex, "offset", offset)
                            fflush(nil)
                        }
                    }
                }
                if best.expected!.saved == startSaved { break }
            }
        }
        if mode == "plan" && selected == index + 1 {
            let steps = try JSONDecoder().decode([PlanStep].self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
            let events = plannedInputs(steps, base: base, releaseRate: args.count > 5 ? Int(args[5]) : nil, releaseRateTick: args.count > 6 ? Int(args[6]) ?? 1 : 1)
            if let outcome = try? run(candidate(events), base: base), outcome.saved >= (replay?.expected?.saved ?? -1) {
                let witness = candidate(events, expected: outcome)
                _ = try run(witness, base: content.simulation(at: index).0)
                try encoder.encode(witness).write(to: file, options: .atomic)
                replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
            }
        }
        if mode == "tutorial" {
            let parameters: [Int]
            switch index {
            case 33, 50: parameters = Array(1...8)
            case 73: parameters = Array(124...136)
            case 1, 4: parameters = [4]
            case 5: parameters = Array(810...823)
            case 83: parameters = Array(1...8)
            case 2: parameters = Array(1...12)
            case 3: parameters = Array(stride(from: 60, through: 500, by: 8))
            case 12, 31, 89, 100: parameters = Array(stride(from: 0, through: 1600, by: 4))
            default: parameters = []
            }
            for parameter in parameters where replay == nil || replay!.expected!.saved < base.configuration.totalLemmings {
                let events = tutorialInputs(base: base, index: index, parameter: parameter)
                if let outcome = try? run(candidate(events), base: base) {
                    if outcome.saved <= (replay?.expected?.saved ?? -1) { continue }
                    let witness = candidate(events, expected: outcome)
                    _ = try run(witness, base: content.simulation(at: index).0)
                    try encoder.encode(witness).write(to: file, options: .atomic)
                    replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
                    print("TUTORIAL parameter \(parameter)")
                }
            }
        }
        if (replay == nil || mode.hasPrefix("maximize")) && (mode.hasPrefix("maximize") || mode == "import" || mode == "adapt" || mode == "guided") {
            let sources = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: ".build/classic-completion/reference/candidates"), includingPropertiesForKeys: nil).sorted { $0.path < $1.path }
            for source in sources where replay == nil || (mode.hasPrefix("maximize") && replay!.expected!.saved < base.configuration.totalLemmings) {
                let input = try JSONDecoder().decode(InputCandidate.self, from: Data(contentsOf: source))
                let key = SHA256.hash(data: base.terrain.solidMask + base.terrain.steelMask).description
                guard related[key, default: []].contains(input.title.lowercased()) else { continue }
                for offset in ((mode == "guided" || mode == "maximize-guided") ? [0, 1, 2] : [0, 1, -1, 2, -2, 3, -3]) where replay == nil || (mode.hasPrefix("maximize") && replay!.expected!.saved < base.configuration.totalLemmings) {
                    let shifted = input.events.map { ClassicDOSReplayEvent(tick: max(1, $0.tick + offset), action: $0.action) }
                    let events = (mode == "guided" || mode == "maximize-guided") ? guidedInputs(input, base: base, tolerance: offset) : ((mode == "adapt" || mode == "maximize-adapt") ? appliedInputs(shifted, base: base) : shifted)
                    do {
                        let outcome = try run(candidate(events), base: base)
                        if mode.hasPrefix("maximize"), outcome.saved <= (replay?.expected?.saved ?? -1) { continue }
                        let witness = candidate(events, expected: outcome)
                        _ = try run(witness, base: content.simulation(at: index).0)
                        try encoder.encode(witness).write(to: file, options: .atomic)
                        replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
                        print("IMPORTED \(source.lastPathComponent), tick offset \(offset)")
                    } catch { print("CANDIDATE \(source.lastPathComponent) for \(entry.rank) \(entry.number) offset \(offset): \(error)") }
                }
            }
        }
        // Beam search over multi-assignment routes. The existing search mode only
        // ever tries a single assignment to lemming 0, which cannot reach a level
        // that needs two skills. This keeps a population of real simulation
        // states, branches them at a tick grid, and scores on rescues first and
        // distance to an exit second. Every retained route still goes through the
        // same witness replay as any other evidence.
        if replay == nil && mode == "solve" {
            func tuning(_ name: String, _ fallback: Int) -> Int {
                ProcessInfo.processInfo.environment[name].flatMap(Int.init) ?? fallback
            }
            let beamWidth = tuning("SOLVE_BEAM", 24)
            let branchStride = tuning("SOLVE_STRIDE", 8)
            let maxAssignments = tuning("SOLVE_DEPTH", 8)
            let lemmingFanout = tuning("SOLVE_FANOUT", 10)
            let tickLimit = min(ClassicDOSReplayPlayer.defaultTickLimit, tuning("SOLVE_TICKS", 4200))
            let trace = ProcessInfo.processInfo.environment["SOLVE_TRACE"] == "1"

            let exits = base.configuration.triggers.filter { $0.effect == .exit }
            func exitDistance(_ point: ClassicDOSPoint) -> Int {
                guard !exits.isEmpty else { return 0 }
                return exits.map { trigger in
                    let cx = (trigger.bounds.x1 + trigger.bounds.x2) / 2
                    let cy = (trigger.bounds.y1 + trigger.bounds.y2) / 2
                    return abs(point.x - cx) + abs(point.y - cy)
                }.min() ?? 0
            }

            struct Node {
                var sim: ClassicDOSSimulation
                var events: [ClassicDOSReplayEvent]
                var assignments: Int
                var pending: (id: Int, skill: ClassicSkill)?
            }
            // Rescues dominate. Then keep lemmings alive, then get someone near an
            // exit, then prefer the route that spent fewer skills.
            func score(_ node: Node) -> Int {
                let nearest = node.sim.lemmings.lazy.filter(\.isActive)
                    .map { exitDistance($0.foot) }.min() ?? 4096
                return node.sim.savedCount * 1_000_000
                    - node.sim.lostCount * 8_000
                    - min(nearest, 4096) * 4
                    - node.assignments
            }

            var beam = [Node(sim: base, events: [], assignments: 0, pending: nil)]
            var solution: [ClassicDOSReplayEvent]?
            var expanded = 0
            search: while let head = beam.first, head.sim.tickCount < tickLimit {
                let tick = head.sim.tickCount + 1
                var frontier: [Node] = []
                for node in beam {
                    frontier.append(Node(sim: node.sim, events: node.events,
                                         assignments: node.assignments, pending: nil))
                    guard node.assignments < maxAssignments, tick % branchStride == 0 else { continue }
                    let ordered = node.sim.lemmings.filter(\.isActive)
                        .sorted { exitDistance($0.foot) < exitDistance($1.foot) }
                        .prefix(lemmingFanout)
                    for lemming in ordered {
                        for skill in ClassicSkill.allCases where node.sim.remainingSkillCount(skill) > 0 {
                            var fork = node.sim
                            guard fork.schedule(.init(tick: tick, lemmingID: lemming.id, skill: skill)) else { continue }
                            frontier.append(Node(
                                sim: fork,
                                events: node.events + [.init(tick: tick, action: .assign(lemmingID: lemming.id, skill: skill))],
                                assignments: node.assignments + 1,
                                pending: (lemming.id, skill)))
                            expanded += 1
                        }
                    }
                }
                var advanced: [Node] = []
                var seen = Set<String>()
                for var node in frontier {
                    let applied = node.sim.tick()
                    // A scheduled assignment that never applied would fail the
                    // witness replay later, so that branch is dropped here.
                    if let pending = node.pending,
                       !applied.contains(.skillAssigned(lemmingID: pending.id, skill: pending.skill)) { continue }
                    node.pending = nil
                    if node.sim.lostCount > node.sim.configuration.totalLemmings - node.sim.configuration.requiredToSave { continue }
                    if node.sim.isComplete {
                        if node.sim.didWin { solution = node.events; break search }
                        continue
                    }
                    // Identical states differ only by history, so keep one.
                    let key = ClassicDOSReplayRecorder.stateHash(of: node.sim) + ":\(node.assignments)"
                    if !seen.insert(key).inserted { continue }
                    advanced.append(node)
                }
                if advanced.isEmpty { break }
                beam = Array(advanced.sorted { score($0) > score($1) }.prefix(beamWidth))
                if trace && tick % 240 == 0 {
                    let top = beam[0]
                    FileHandle.standardError.write(Data("  tick \(tick) beam \(beam.count) saved \(top.sim.savedCount) lost \(top.sim.lostCount) skills \(top.assignments) expanded \(expanded)\n".utf8))
                }
            }
            if let events = solution {
                let trial = candidate(events)
                if let outcome = try? run(trial, base: base), outcome.saved > (replay?.expected?.saved ?? -1) {
                    let witness = candidate(events, expected: outcome)
                    _ = try run(witness, base: content.simulation(at: index).0)
                    try encoder.encode(witness).write(to: file, options: .atomic)
                    replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
                }
            }
        }
        if replay == nil && mode == "search" {
            var candidates: [[ClassicDOSReplayEvent]] = [[]]
            for skill in ClassicSkill.allCases where base.remainingSkillCount(skill) > 0 {
                for tick in stride(from: 36, through: 800, by: 4) {
                    candidates.append([.init(tick: tick, action: .assign(lemmingID: 0, skill: skill))])
                }
            }
            for events in candidates {
                let trial = candidate(events)
                if let outcome = try? run(trial, base: base) {
                    if outcome.saved <= (replay?.expected?.saved ?? -1) { continue }
                    let witness = candidate(events, expected: outcome)
                    _ = try run(witness, base: content.simulation(at: index).0)
                    try encoder.encode(witness).write(to: file, options: .atomic)
                    replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: file))
                    break
                }
            }
        }
        do {
            guard let replay else { throw ReplayFailure(description: "missing winning replay") }
            try require(replay.rank == entry.rank && replay.number == entry.number && replay.title == title, "level identity mismatch")
            try require(replay.expected != nil, "missing expected outcome")
            let outcome = try run(replay, base: base)
            let repeated = try run(replay, base: content.simulation(at: index).0)
            try require(outcome == repeated, "fresh replay differs")
            print("PASS \(entry.rank) \(entry.number): \(outcome.saved)/\(outcome.required) in \(outcome.ticks) ticks")
            verified += 1
        } catch {
            failures += 1
            print("UNVERIFIED \(entry.rank) \(entry.number): \(error)")
        }
        fflush(nil)
    }
    print("Verified \(verified); missing or failed \(failures).")
    if mode == "verify-known" { print("Uncovered \(uncovered) levels. This is a partial-coverage gate.") }
    if failures > 0 || (mode == "verify-known" && verified == 0) { exit(1) }
} catch {
    FileHandle.standardError.write(Data("Completion verification failed: \(error)\n".utf8))
    exit(1)
}
