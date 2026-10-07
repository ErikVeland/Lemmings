import Foundation
import NxlvKit

/// Set once by `--fewer-inputs-first`, before any search starts: rank routes with fewer inputs
/// before shorter crowd distance. This keeps a one-action line, such as a single dig, in the beam
/// until its effect shows.
nonisolated(unsafe) var fewerInputsFirst = false

/// A solver candidate: a runtime snapshot and the recorded input that produced it.
struct L3Candidate: Sendable {
    var game: Lemmings3Runtime
    var inputs: [L3Replay.Input] = []
    var depth = 0
    var detector: L3Detector
    var decision: [Int] = []
    var fingerprint: UInt64 = 0
}

struct L3Limits: Sendable {
    var beamWidth = 64
    var maxDepth = 200
    var budgetSeconds = 600.0
    var cell = 8
    var refire = 150
    /// Zero keeps the standard decision set; a positive value samples walking tool holders by location.
    var toolSiteCell = 0
    var pairedActors = false
    /// Lemmings 3 levels end when every lemming is out. A search stops a run after this many ticks.
    var maxTicks = 30_000
}

/// A route prefix. Complete replay files can also be read as seeds; their outcome is not used.
struct L3Seed: Decodable {
    let version: Int
    let level: Int
    let levelSHA256: String
    let population: Int
    let initialStateHash: String
    let inputs: [L3Replay.Input]
}

/// Applies a checked prefix while retaining the detector's history for the continuation.
func l3SeedCandidate(from base: Lemmings3Runtime, levelNumber: Int, levelData: Data,
                     seed: L3Seed, throughTick: Int, limits: L3Limits) throws -> L3Candidate {
    guard seed.version == 1, seed.level == levelNumber,
          seed.levelSHA256 == L3Replay.digest(levelData),
          seed.population == base.configuration.total,
          seed.initialStateHash == L3Replay.stateHash(base) else {
        throw SequelDataError.invalid("L3 seed source, population or initial state differs.")
    }
    guard (0..<limits.maxTicks).contains(throughTick), seed.inputs.count <= 100_000,
          seed.inputs.prefix(while: { $0.tick <= throughTick }).allSatisfy({ $0.tick >= 0 }),
          zip(seed.inputs, seed.inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
        throw SequelDataError.invalid("L3 seed checkpoint or input order is invalid.")
    }
    var candidate = L3Candidate(game: base,
        detector: L3Detector(cell: limits.cell, refire: limits.refire, toolSiteCell: limits.toolSiteCell))
    var cursor = 0
    while candidate.game.tick <= throughTick {
        while cursor < seed.inputs.count && seed.inputs[cursor].tick == candidate.game.tick {
            let input = seed.inputs[cursor]
            guard L3Replay.apply(input, to: &candidate.game) else {
                throw SequelDataError.invalid("L3 seed input \(cursor) failed at tick \(candidate.game.tick).")
            }
            candidate.inputs.append(input)
            cursor += 1
        }
        if candidate.game.tick == throughTick { break }
        candidate.game.step()
        candidate.decision = candidate.detector.update(candidate.game) ?? []
        if candidate.game.isComplete {
            throw SequelDataError.invalid("L3 seed ended before the requested checkpoint.")
        }
    }
    guard !candidate.game.isComplete else {
        throw SequelDataError.invalid("L3 seed checkpoint is already complete.")
    }
    return candidate
}

/// Reports decision points keyed by location, as the Lemmings 2 solver does. A crowd that meets
/// one wall fires one decision. A lemming that stands still for the fallback period also fires.
/// Targeted searches can sample walking Brick and Spade holders on a coarser grid.
struct L3Detector: Sendable {
    let cell: Int, refire: Int, fallback: Int, toolSiteCell: Int
    private var lastDirection: [Int: Int] = [:]
    private var lastState: [Int: Lemmings3Runtime.State] = [:]
    private var lastTool: [Int: Int] = [:]
    private var lastQuantity: [Int: Int] = [:]
    private var lastFired: [String: Int] = [:]
    private var lastSaved = 0
    private var lastDecisionTick = 0
    private var lastFallbackTick = 0

    init(cell: Int = 8, refire: Int = 150, fallback: Int = 150, toolSiteCell: Int = 0) {
        self.cell = cell; self.refire = refire; self.fallback = fallback; self.toolSiteCell = toolSiteCell
    }

    private mutating func claim(_ kind: String, _ lemming: Lemmings3Runtime.Lemming,
                                tick: Int, cellSize: Int? = nil) -> Bool {
        let size = cellSize ?? cell
        let key = "\(kind)|\(lemming.x / size),\(lemming.y / size),\(lemming.direction)"
        if let fired = lastFired[key], tick - fired < refire { return false }
        lastFired[key] = tick
        return true
    }

    /// Returns up to three lemmings to act on, or nil when no decision fires on this tick.
    mutating func update(_ game: Lemmings3Runtime) -> [Int]? {
        var fired: [(priority: Int, id: Int)] = []
        let actionable: Set<Lemmings3Runtime.State> = [.walking, .blocking, .building, .digging, .climbing, .shimmying, .swimming]
        for lemming in game.lemmings where lemming.active {
            let previousDirection = lastDirection[lemming.id], previousState = lastState[lemming.id]
            let previousTool = lastTool[lemming.id]
            let previousQuantity = lastQuantity[lemming.id]
            lastDirection[lemming.id] = lemming.direction
            lastState[lemming.id] = lemming.state
            lastTool[lemming.id] = lemming.tool?.rawValue ?? -1
            lastQuantity[lemming.id] = lemming.quantity
            if let previousState, previousState != lemming.state, actionable.contains(lemming.state),
               claim("state-\(lemming.state.rawValue)", lemming, tick: game.tick) {
                fired.append((2, lemming.id))
            }
            if let previousTool, previousTool != (lemming.tool?.rawValue ?? -1), claim("tool", lemming, tick: game.tick) {
                fired.append((0, lemming.id))
            }
            if let previousQuantity, previousQuantity != lemming.quantity,
               lemming.state == .building || lemming.state == .digging,
               claim("work", lemming, tick: game.tick) {
                fired.append((0, lemming.id))
            }
            if toolSiteCell > 0, lemming.state == .walking,
               lemming.tool == .bricks || lemming.tool == .spade,
               claim("tool-site-\(lemming.id)", lemming, tick: game.tick, cellSize: toolSiteCell) {
                fired.append((0, lemming.id))
            }
            guard lemming.state == .walking else { continue }
            let ahead = lemming.x + lemming.direction * 8
            if ((lemming.y - 8)...(lemming.y - 1)).contains(where: { game.isSolid(ahead, $0) }), claim("wall", lemming, tick: game.tick) {
                fired.append((0, lemming.id))
            }
            if !(lemming.y...(lemming.y + 4)).contains(where: { game.isSolid(ahead, $0) }), claim("edge", lemming, tick: game.tick) {
                fired.append((1, lemming.id))
            }
            if let previousDirection, previousDirection != lemming.direction, claim("turn", lemming, tick: game.tick) {
                fired.append((3, lemming.id))
            }
        }
        let newSave = game.saved > lastSaved
        lastSaved = game.saved
        if fired.isEmpty && newSave {
            lastDecisionTick = game.tick
            return []
        }
        if toolSiteCell == 0 {
            if fired.isEmpty {
                guard game.tick - lastDecisionTick >= fallback else { return nil }
                lastDecisionTick = game.tick
                let walking = game.lemmings.filter { $0.active && $0.state == .walking }.map(\.id)
                return Array(walking.prefix(3))
            }
            lastDecisionTick = game.tick
        }
        let fallbackDue = toolSiteCell > 0 && game.tick - lastFallbackTick >= fallback
        guard !fired.isEmpty || fallbackDue else { return nil }
        var offered: [Int] = []
        for entry in fired.sorted(by: { ($0.priority, $0.id) < ($1.priority, $1.id) }) where !offered.contains(entry.id) {
            if offered.count == 3 { break }
            offered.append(entry.id)
        }
        if fallbackDue {
            let walking = game.lemmings.filter { $0.active && $0.state == .walking }
            let fallbackActor = walking.first(where: { $0.tool == nil && !offered.contains($0.id) })
                ?? walking.first(where: { !offered.contains($0.id) })
            if let id = fallbackActor?.id {
                if offered.count == 3 { offered.removeLast() }
                offered.append(id)
            }
            if !walking.isEmpty { lastFallbackTick = game.tick }
        }
        return offered.isEmpty ? nil : offered
    }
}

/// Distance to the nearest exit through open space, on a 4 pixel grid.
struct L3DistanceField: Sendable {
    static let cell = 4
    let columns: Int, rows: Int
    let steps: [Int]

    init(_ game: Lemmings3Runtime) {
        let cell = Self.cell, width = game.configuration.width, height = game.configuration.height
        columns = (width + cell - 1) / cell
        rows = (height + cell - 1) / cell
        let columns = self.columns, rows = self.rows
        var open = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                var any = false
                for y in (row * cell)..<min(height, row * cell + cell) where !any {
                    for x in (column * cell)..<min(width, column * cell + cell) where !game.isSolid(x, y) { any = true; break }
                }
                open[row * columns + column] = any
            }
        }
        var steps = [Int](repeating: .max, count: columns * rows)
        var queue: [Int] = []
        for exit in game.configuration.exits {
            let index = min(rows - 1, max(0, exit.y / cell)) * columns + min(columns - 1, max(0, exit.x / cell))
            if steps[index] != 0 { steps[index] = 0; queue.append(index) }
        }
        var head = 0
        while head < queue.count {
            let index = queue[head]; head += 1
            let column = index % columns, row = index / columns
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let c = column + dx, r = row + dy
                guard c >= 0, c < columns, r >= 0, r < rows else { continue }
                let next = r * columns + c
                guard open[next], steps[next] == .max else { continue }
                steps[next] = steps[index] + 1
                queue.append(next)
            }
        }
        self.steps = steps
    }

    func distance(x: Int, y: Int) -> Int {
        let column = min(columns - 1, max(0, x / Self.cell)), row = min(rows - 1, max(0, y / Self.cell))
        if steps[row * columns + column] != .max { return steps[row * columns + column] * Self.cell }
        if row > 0, steps[(row - 1) * columns + column] != .max { return steps[(row - 1) * columns + column] * Self.cell }
        return Self.cell * (columns + rows) * 4
    }
}

/// Ranks candidates: saved, then lemmings not lost, then distance to an exit, then fewer inputs.
struct L3Score: Comparable, Sendable {
    let saved: Int, remaining: Int, distance: Int, inputs: Int, fingerprint: UInt64

    static func < (a: L3Score, b: L3Score) -> Bool {
        if a.saved != b.saved { return a.saved < b.saved }
        if a.remaining != b.remaining { return a.remaining < b.remaining }
        if fewerInputsFirst {
            if a.inputs != b.inputs { return a.inputs > b.inputs }
            if a.distance != b.distance { return a.distance > b.distance }
        } else {
            if a.distance != b.distance { return a.distance > b.distance }
            if a.inputs != b.inputs { return a.inputs > b.inputs }
        }
        return a.fingerprint > b.fingerprint
    }

    init(_ candidate: L3Candidate, field: L3DistanceField) {
        let game = candidate.game
        let active = game.lemmings.filter(\.active).reduce(0) { $0 + field.distance(x: $1.x, y: $1.y) }
        let entrances = [game.configuration.entrance] + game.configuration.additionalEntrances
        let hatchDistances = entrances.map { field.distance(x: $0.x, y: $0.y) }
        let pending = game.pendingReleases
        let completeCycles = pending / hatchDistances.count
        let firstHatch = game.released % hatchDistances.count
        let remainingHatches = (0..<(pending % hatchDistances.count)).reduce(0) { sum, index in
            sum + hatchDistances[(firstHatch + index) % hatchDistances.count]
        }
        saved = game.saved
        // Walker can release a blocker, so it still has a chance to reach an exit.
        remaining = game.configuration.total - game.lost
        distance = active + completeCycles * hatchDistances.reduce(0, +) + remainingHatches
        inputs = candidate.inputs.count
        fingerprint = candidate.fingerprint
    }
}

/// FNV-1a over the state the search can change. Two equal fingerprints merge in the beam.
func l3Fingerprint(_ game: Lemmings3Runtime) -> UInt64 {
    var value: UInt64 = 0xcbf2_9ce4_8422_2325
    func add(_ number: Int) {
        var bits = UInt64(bitPattern: Int64(number))
        for _ in 0..<8 { value = (value ^ (bits & 0xff)) &* 0x0000_0100_0000_01b3; bits >>= 8 }
    }
    add(game.tick); add(game.released); add(game.bonusSeconds); add(game.isComplete ? 1 : 0)
    for lemming in game.lemmings {
        for byte in lemming.state.rawValue.utf8 { add(Int(byte)) }
        for byte in lemming.workDirection.rawValue.utf8 { add(Int(byte)) }
        for number in [lemming.id, lemming.x, lemming.y, lemming.direction, lemming.age,
                       lemming.fall, lemming.velocityY, lemming.tool?.rawValue ?? -1,
                       lemming.quantity, lemming.swimTicks, lemming.trapTicks,
                       lemming.mobilityTool?.rawValue ?? -1, lemming.mobilityTicks,
                       lemming.charmedBy ?? -1, lemming.charmTicks, lemming.charmImmunity] { add(number) }
    }
    for pickup in game.pickups {
        for number in [pickup.id, pickup.tool.rawValue, pickup.x, pickup.y,
                       pickup.quantity, pickup.ignoredBy ?? -1] { add(number) }
    }
    for (key, solid) in game.terrainEdits.sorted(by: { $0.key < $1.key }) { add(key); add(solid ? 1 : 0) }
    for bomb in game.explosives {
        for number in [bomb.id, bomb.tool.rawValue, bomb.x, bomb.y,
                       bomb.velocityX, bomb.velocityY, bomb.age] { add(number) }
    }
    for ball in game.fireballs {
        for number in [ball.x, ball.y, ball.direction, ball.age] { add(number) }
    }
    for creature in game.creatures {
        for byte in creature.digDirection.rawValue.utf8 { add(Int(byte)) }
        for number in [creature.id, creature.kind.rawValue, creature.x, creature.y,
                       creature.direction, creature.alive ? 1 : 0, creature.target ?? -1,
                       creature.cooldown, creature.age] { add(number) }
    }
    for trap in game.configuration.traps.sorted(by: { $0.id < $1.id }) {
        add(trap.id); add(game.trapFrame(id: trap.id))
    }
    return value
}

/// The input sequences to try for one lemming at a decision point.
func l3Actions(_ game: Lemmings3Runtime, lemming id: Int) -> [[L3Replay.Input]] {
    guard let lemming = game.lemmings.first(where: { $0.id == id && $0.active }) else { return [] }
    var result: [L3Replay.Input] = []
    for action in ["walker", "blocker", "jumper"] {
        result.append(.init(tick: game.tick, action: action, lemming: id, direction: nil))
    }
    if let tool = lemming.tool {
        result.append(.init(tick: game.tick, action: "drop", lemming: id, direction: nil))
        let directions: [Lemmings3Runtime.Direction]
        switch tool {
        case .spade: directions = Lemmings3Runtime.Direction.allCases
        case .bricks: directions = Lemmings3Runtime.Direction.allCases.filter { $0 != .down }
        case .bomb, .grenade, .hadoken, .sucker, .shimmy: directions = [lemming.direction > 0 ? .right : .left]
        default: directions = []
        }
        for direction in directions {
            result.append(.init(tick: game.tick, action: "use", lemming: id, direction: direction.rawValue))
        }
    }
    // Keep only actions the runtime accepts now.
    var choices = result.filter { input in
        var trial = game
        return L3Replay.apply(input, to: &trial)
    }.map { [$0] }
    if lemming.state == .building || lemming.state == .digging {
        let walker = L3Replay.Input(tick: game.tick, action: "walker", lemming: id, direction: nil)
        var trial = game
        if L3Replay.apply(walker, to: &trial), L3Replay.apply(walker, to: &trial) {
            choices.append([walker, walker])
        }
    }
    return choices
}

/**
 * Returns a bounded set of same-tick actions for two offered actors.
 */
func l3PairedActions(_ game: Lemmings3Runtime, actorChoices: [[[L3Replay.Input]]], limit: Int = 32) -> [[L3Replay.Input]] {
    guard actorChoices.count > 1, limit > 0 else { return [] }
    func priority(_ input: L3Replay.Input) -> Int {
        switch input.action {
        case "walker": 0
        case "jumper": 1
        case "use": 2
        case "blocker": 3
        default: 4
        }
    }
    var proposals: [(priority: Int, order: Int, first: L3Replay.Input, second: L3Replay.Input)] = []
    for firstActor in 0..<(actorChoices.count - 1) {
        for secondActor in (firstActor + 1)..<actorChoices.count {
            for first in actorChoices[firstActor] where first.count == 1 {
                for second in actorChoices[secondActor] where second.count == 1 {
                    proposals.append((priority(first[0]) + priority(second[0]), proposals.count, first[0], second[0]))
                }
            }
        }
    }
    proposals.sort { ($0.priority, $0.order) < ($1.priority, $1.order) }
    var result: [[L3Replay.Input]] = []
    for proposal in proposals {
        var trial = game
        guard L3Replay.apply(proposal.first, to: &trial), L3Replay.apply(proposal.second, to: &trial) else { continue }
        result.append([proposal.first, proposal.second])
        if result.count == limit { break }
    }
    return result
}

struct L3Report: Sendable {
    var best: L3Candidate?
    var bestPartial: L3Candidate?
    var expanded = 0
    var seconds = 0.0
}

/// Runs a candidate until its next decision point or the end of the level.
func l3Advance(_ candidate: inout L3Candidate, limits: L3Limits) -> Bool {
    while !candidate.game.isComplete && candidate.game.tick < limits.maxTicks {
        candidate.game.step()
        if let offered = candidate.detector.update(candidate.game) {
            candidate.decision = offered
            return true
        }
    }
    return false
}

/// A beam search over decision points. A finished winning candidate keeps its inputs as the route.
func l3Search(from start: Lemmings3Runtime, limits: L3Limits, seed: L3Candidate? = nil) -> L3Report {
    let started = Date()
    let field = L3DistanceField(start)
    var report = L3Report()
    func consider(_ candidate: L3Candidate) {
        let score = L3Score(candidate, field: field)
        if candidate.game.isComplete && candidate.game.saved > 0,
           report.best.map({ L3Score($0, field: field) < score }) ?? true {
            report.best = candidate
        }
        if report.bestPartial.map({ L3Score($0, field: field) < score }) ?? true { report.bestPartial = candidate }
    }
    func finish(_ candidate: L3Candidate) -> L3Candidate {
        var tail = candidate
        while l3Advance(&tail, limits: limits) {}
        return tail
    }
    var root = seed ?? L3Candidate(game: start, detector: L3Detector(cell: limits.cell, refire: limits.refire,
                                                                   toolSiteCell: limits.toolSiteCell))
    if seed == nil { _ = l3Advance(&root, limits: limits) }
    root.fingerprint = l3Fingerprint(root.game)
    consider(root)
    let prefixInputCount = root.inputs.count
    var beam = root.game.isComplete ? [] : [root]
    while !beam.isEmpty && Date().timeIntervalSince(started) < limits.budgetSeconds {
        var next: [UInt64: L3Candidate] = [:]
        for node in beam {
            if node.depth >= limits.maxDepth { consider(finish(node)); continue }
            var choices: [[L3Replay.Input]] = [[]]
            let actorChoices = node.decision.map { l3Actions(node.game, lemming: $0) }
            for actions in actorChoices { choices += actions }
            if limits.pairedActors { choices += l3PairedActions(node.game, actorChoices: actorChoices) }
            if node.game.saved > 0 {
                choices.append([.init(tick: node.game.tick, action: "abort", lemming: nil, direction: nil)])
            }
            for inputs in choices {
                var child = node
                for input in inputs { _ = L3Replay.apply(input, to: &child.game) }
                child.inputs += inputs
                child.depth += 1
                report.expanded += 1
                _ = l3Advance(&child, limits: limits)
                child.fingerprint = l3Fingerprint(child.game)
                consider(child)
                guard !child.game.isComplete, child.game.tick < limits.maxTicks else { continue }
                if let existing = next[child.fingerprint],
                   !(L3Score(existing, field: field) < L3Score(child, field: field)) { continue }
                next[child.fingerprint] = child
            }
            if Date().timeIntervalSince(started) >= limits.budgetSeconds { break }
        }
        beam = next.values.sorted { L3Score($1, field: field) < L3Score($0, field: field) }.prefix(limits.beamWidth).map { $0 }
        // Keep the line that has only waited. A useful action often scores no better than a harmful
        // one until long after it happens, so the untouched line must stay available to branch from.
        if !beam.contains(where: { $0.inputs.count == prefixInputCount }),
           let waiting = next.values.first(where: { $0.inputs.count == prefixInputCount }) {
            if beam.count == limits.beamWidth { beam.removeLast() }
            beam.append(waiting)
        }
        if ProcessInfo.processInfo.environment["L3_SOLVER_TRACE"] != nil, let top = beam.first {
            let g = top.game
            print("ROUND expanded \(report.expanded) beam \(beam.count) top tick \(g.tick) depth \(top.depth) saved \(g.saved) lost \(g.lost) released \(g.released) states \(g.lemmings.filter(\.active).map { "\($0.state.rawValue)@\($0.x),\($0.y)\($0.tool.map { " \($0)" } ?? "")" }.prefix(4))")
        }
    }
    if let top = beam.first { consider(finish(top)) }
    report.seconds = Date().timeIntervalSince(started)
    return report
}
