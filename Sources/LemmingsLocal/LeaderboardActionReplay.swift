#if os(macOS)
import AppKit
import CryptoKit
import NxlvKit

/// Public replay data contains commands and identities, never level assets or saved states.
struct LeaderboardActionReplay: Codable, Sendable {
    static let byteLimit = 8 * 1024 * 1024
    struct Command: Codable, Sendable {
        let tick: Int
        let action: String
        var lemming: Int? = nil
        var skill: Int? = nil
        var value: Int? = nil
        var x: Int? = nil
        var y: Int? = nil
        var held: Bool? = nil
        var direction: String? = nil
    }
    let version: Int
    let runID: UUID
    let conditions: TrolleyConditions
    let engine: String
    let engineFingerprint: String
    let initialStateHash: String
    let finalStateHash: String
    let ticks: Int
    let saved: Int
    let population: Int
    let skills: Int
    let won: Bool
    let assisted: Bool
    let commands: [Command]

    func validateStructure() throws {
        func hash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
        guard version == 1, conditions.isValid, !engineFingerprint.isEmpty, engineFingerprint.count <= 256,
              hash(initialStateHash), hash(finalStateHash), (0...120_000).contains(ticks),
              (0...population).contains(saved), population >= conditions.population, population <= 1_000_000,
              (0...100_000_000).contains(skills), commands.count <= 100_000,
              commands.allSatisfy({ (0...ticks).contains($0.tick) && !$0.action.isEmpty && $0.action.count <= 32 }),
              zip(commands, commands.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else { throw RunRecoveryError.invalid }
        let expected = conditions.gameID == "lemmings2" ? "lemmings2"
            : conditions.gameID == "lemmings3" ? "lemmings3" : conditions.gameID == "neolemmix" ? "neolemmix" : "classic"
        guard engine == expected else { throw RunRecoveryError.invalid }
    }

    static func capture(run: ArcadeRun, initial: ActionReplayState, final: ActionReplayState,
                        commands: [Command]) throws -> Self {
        guard let conditions = run.level.conditions, final.complete else { throw RunRecoveryError.invalid }
        let result = Self(version: 1, runID: run.id, conditions: conditions, engine: initial.engine,
            engineFingerprint: RunRecovery.bundledEngine, initialStateHash: try initial.hash(),
            finalStateHash: try final.hash(), ticks: final.tick, saved: run.saved, population: run.population,
            skills: run.skillCount, won: run.qualifies, assisted: run.assisted, commands: commands)
        try result.validateStructure()
        return result
    }
    func checked(initial: ActionReplayState) throws -> ActionReplayCursor {
        try validateStructure()
        guard engineFingerprint == RunRecovery.bundledEngine, engine == initial.engine,
              try initial.hash() == initialStateHash else { throw RunRecoveryError.differentGame }
        var cursor = try ActionReplayCursor(replay: self, initial: initial)
        try cursor.seek(to: ticks)
        guard cursor.state.complete, cursor.state.saved == saved, cursor.state.population == population,
              (cursor.state.didWin && saved >= conditions.rescueRequirement) == won,
              commands.filter({ engine == "lemmings3" ? ["walker", "blocker", "jumper", "use", "drop"].contains($0.action) : $0.action == "assign" }).count == skills,
              try cursor.state.hash() == finalStateHash else { throw RunRecoveryError.invalid }
        return try ActionReplayCursor(replay: self, initial: initial)
    }
}

/// Playback copies the engine. It has no campaign, profile, telemetry or sound callbacks.
enum ActionReplayState: Sendable {
    case classic(ClassicDOSSimulation)
    case neolemmix(NeoLemmixSimulation)
    case lemmings2(Lemmings2Runtime)
    case lemmings3(Lemmings3Runtime)
    var engine: String {
        switch self { case .classic: "classic"; case .neolemmix: "neolemmix"; case .lemmings2: "lemmings2"; case .lemmings3: "lemmings3" }
    }
    var tick: Int {
        switch self { case .classic(let g): g.tickCount; case .neolemmix(let g): g.tickCount; case .lemmings2(let g): g.tick; case .lemmings3(let g): g.tick }
    }
    var complete: Bool {
        switch self { case .classic(let g): g.isComplete; case .neolemmix(let g): g.isComplete; case .lemmings2(let g): g.isComplete; case .lemmings3(let g): g.isComplete }
    }
    var didWin: Bool {
        switch self { case .classic(let g): g.didWin; case .neolemmix(let g): g.didWin; case .lemmings2(let g): g.didWin; case .lemmings3(let g): g.saved > 0 }
    }
    var saved: Int {
        switch self { case .classic(let g): g.savedCount; case .neolemmix(let g): g.savedCount; case .lemmings2(let g): g.saved; case .lemmings3(let g): g.saved }
    }
    var population: Int {
        switch self { case .classic(let g): g.configuration.totalLemmings; case .neolemmix(let g): g.totalPopulation; case .lemmings2(let g): g.configuration.total; case .lemmings3(let g): g.configuration.total + g.configuration.extras.count }
    }
    var ticksPerSecond: Double {
        switch self { case .classic: Double(ClassicDOSRules.ticksPerSecond); case .neolemmix: Double(NeoLemmixRules.ticksPerSecond); case .lemmings2: Lemmings2Runtime.ticksPerSecond; case .lemmings3: Lemmings3Runtime.ticksPerSecond }
    }
    func hash() throws -> String {
        switch self {
        case .classic(let g): return ClassicDOSReplayRecorder.stateHash(of: g)
        case .lemmings2(let g): return try L2RunRecovery.stateHash(g, includeConfiguration: true)
        case .lemmings3(let g): return L3RunRecovery.stateHash(g)
        case .neolemmix(let g): return SHA256.hash(data: try RecoveryValueEncoding.data(g)).map { String(format: "%02x", $0) }.joined()
        }
    }
    mutating func step() {
        switch self {
        case .classic(var g): _ = g.tick(); self = .classic(g)
        case .neolemmix(var g): _ = g.tick(); self = .neolemmix(g)
        case .lemmings2(var g): g.step(); _ = g.drainSoundEvents(); self = .lemmings2(g)
        case .lemmings3(var g): g.step(); self = .lemmings3(g)
        }
    }
    func replaySkillName(_ command: LeaderboardActionReplay.Command) -> String? {
        switch self {
        case .classic:
            guard command.action == "assign", let skill = command.skill, ClassicSkill.allCases.indices.contains(skill) else { return nil }
            return ClassicSkill.allCases[skill].rawValue.capitalized
        case .neolemmix(let game):
            let order = NeoLemmixSkill.allCases.filter { game.configuration.skills[$0] != nil }
            guard command.action == "assign", let skill = command.skill, order.indices.contains(skill) else { return nil }
            return order[skill].rawValue.capitalized
        case .lemmings2(let game):
            guard command.action == "assign", let skill = command.skill, game.configuration.skills.indices.contains(skill) else { return nil }
            return game.configuration.skills[skill].name
        case .lemmings3(let game):
            guard ["walker", "blocker", "jumper", "use", "drop"].contains(command.action) else { return nil }
            let tool = game.lemmings.first { $0.id == command.lemming }?.tool
            let name = command.action == "use" ? tool.map { String(describing: $0).capitalized } ?? "Use"
                : command.action.capitalized
            return name + (command.lemming.map { " L\($0)" } ?? "")
        }
    }
    mutating func apply(_ c: LeaderboardActionReplay.Command) throws {
        guard c.tick == tick, !complete else { throw RunRecoveryError.invalid }
        switch self {
        case .classic(var g):
            switch c.action {
            case "assign":
                guard let id = c.lemming, let raw = c.skill, ClassicSkill.allCases.indices.contains(raw),
                      g.assign(ClassicSkill.allCases[raw], to: id) == .assigned else { throw RunRecoveryError.invalid }
            case "rate": guard let value = c.value, (0...99).contains(value) else { throw RunRecoveryError.invalid }; g.setReleaseRate(value)
            case "nuke": guard !g.isNuking else { throw RunRecoveryError.invalid }; g.beginNuke()
            default: throw RunRecoveryError.invalid
            }
            self = .classic(g)
        case .neolemmix(var g):
            switch c.action {
            case "assign":
                let order = NeoLemmixSkill.allCases.filter { g.configuration.skills[$0] != nil }
                guard let id = c.lemming, let raw = c.skill, order.indices.contains(raw) else { throw RunRecoveryError.invalid }
                if case .rejected = g.assign(skill: order[raw], to: id) { throw RunRecoveryError.invalid }
            case "rate": guard let value = c.value, (-10_000...10_000).contains(value) else { throw RunRecoveryError.invalid }; _ = g.enqueue(.setSpawnInterval(g.spawnInterval + value))
            case "nuke": guard !g.isNuking else { throw RunRecoveryError.invalid }; _ = g.enqueue(.nuke)
            default: throw RunRecoveryError.invalid
            }
            self = .neolemmix(g)
        case .lemmings2(var g):
            let action: L2RunRecovery.Input.Action
            switch c.action {
            case "assign": guard let skill = c.skill, let id = c.lemming else { throw RunRecoveryError.invalid }; action = .assign(slot: skill, lemming: id)
            case "fan", "aim":
                guard let x = c.x, let y = c.y, let held = c.held else { throw RunRecoveryError.invalid }
                action = c.action == "fan" ? .fan(x: x, y: y, active: held) : .aim(x: x, y: y, held: held)
            case "machine", "chain": guard let x = c.x, let y = c.y else { throw RunRecoveryError.invalid }; action = c.action == "machine" ? .machine(x: x, y: y) : .chain(x: x, y: y)
            case "releasePointer": action = .releasePointer
            case "nuke": action = .nuke
            default: throw RunRecoveryError.invalid
            }
            try L2RunRecovery.apply(.init(tick: c.tick, action: action), to: &g)
            self = .lemmings2(g)
        case .lemmings3(var g):
            guard L3RunRecovery.apply(.init(tick: c.tick, action: c.action, lemming: c.lemming, direction: c.direction), to: &g) else { throw RunRecoveryError.invalid }
            self = .lemmings3(g)
        }
    }
}

struct ActionReplayCursor {
    let replay: LeaderboardActionReplay
    let initial: ActionReplayState
    private(set) var state: ActionReplayState
    private(set) var skillUses: [(tick: Int, name: String)] = []
    private var next = 0
    init(replay: LeaderboardActionReplay, initial: ActionReplayState) throws {
        guard initial.tick == 0, !initial.complete else { throw RunRecoveryError.invalid }
        self.replay = replay; self.initial = initial; state = initial
        try applyCurrent()
    }
    private mutating func applyCurrent() throws {
        while next < replay.commands.count, replay.commands[next].tick == state.tick {
            let command = replay.commands[next]
            let name = state.replaySkillName(command)
            try state.apply(command)
            if let name { skillUses.append((tick: command.tick, name: name)) }
            next += 1
        }
    }
    mutating func step() throws {
        guard state.tick < replay.ticks else { return }
        guard !state.complete else { throw RunRecoveryError.invalid }
        state.step(); try applyCurrent()
    }
    mutating func seek(to tick: Int) throws {
        let target = max(0, min(replay.ticks, tick))
        if target < state.tick { self = try Self(replay: replay, initial: initial) }
        while state.tick < target { try step() }
    }
}

extension LeaderboardActionReplay.Command {
    static func classic(_ e: ClassicDOSReplayEvent) throws -> Self {
        guard e.afterTick == true else { throw RunRecoveryError.invalid }
        switch e.action {
        case let .assign(id, skill): return .init(tick: e.tick, action: "assign", lemming: id, skill: ClassicSkill.allCases.firstIndex(of: skill)!)
        case .releaseRate(let value): return .init(tick: e.tick, action: "rate", value: value)
        case .nuke: return .init(tick: e.tick, action: "nuke")
        }
    }
    static func neo(_ e: NeoRunRecovery.Input) -> Self {
        switch e.action {
        case let .assign(skill, id): .init(tick: e.tick, action: "assign", lemming: id, skill: skill)
        case .rate(let value): .init(tick: e.tick, action: "rate", value: value)
        case .nuke: .init(tick: e.tick, action: "nuke")
        }
    }
    static func l2(_ e: L2RunRecovery.Input) -> Self {
        switch e.action {
        case let .assign(slot, id): .init(tick: e.tick, action: "assign", lemming: id, skill: slot)
        case let .fan(x, y, active): .init(tick: e.tick, action: "fan", x: x, y: y, held: active)
        case let .aim(x, y, held): .init(tick: e.tick, action: "aim", x: x, y: y, held: held)
        case .releasePointer: .init(tick: e.tick, action: "releasePointer")
        case let .machine(x, y): .init(tick: e.tick, action: "machine", x: x, y: y)
        case let .chain(x, y): .init(tick: e.tick, action: "chain", x: x, y: y)
        case .nuke: .init(tick: e.tick, action: "nuke")
        }
    }
    static func l3(_ e: L3RunRecovery.Input) -> Self { .init(tick: e.tick, action: e.action, lemming: e.lemming, direction: e.direction) }
}
#endif
