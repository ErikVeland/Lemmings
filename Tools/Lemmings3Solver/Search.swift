import Foundation
import NxlvKit

/// Set once by `--fewer-inputs-first`, before any search starts: rank routes with fewer inputs
/// before shorter crowd distance. This keeps a one-action line, such as a single dig, in the beam
/// until its effect shows. It found every Lemmings 3 route in the first full run.
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
    /// Lemmings 3 levels end when every lemming is out. A search stops a run after this many ticks.
    var maxTicks = 30_000
}

/// Reports decision points keyed by location, as the Lemmings 2 solver does. A crowd that meets
/// one wall fires one decision. A lemming that stands still for the fallback period also fires.
struct L3Detector: Sendable {
    let cell: Int, refire: Int, fallback: Int
    private var lastDirection: [Int: Int] = [:]
    private var lastState: [Int: Lemmings3Runtime.State] = [:]
    private var lastTool: [Int: Int] = [:]
    private var lastFired: [String: Int] = [:]
    private var lastDecisionTick = 0

    init(cell: Int = 8, refire: Int = 150, fallback: Int = 150) {
        self.cell = cell; self.refire = refire; self.fallback = fallback
    }

    private mutating func claim(_ kind: String, _ lemming: Lemmings3Runtime.Lemming, tick: Int) -> Bool {
        let key = "\(kind)|\(lemming.x / cell),\(lemming.y / cell),\(lemming.direction)"
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
            lastDirection[lemming.id] = lemming.direction
            lastState[lemming.id] = lemming.state
            lastTool[lemming.id] = lemming.tool?.rawValue ?? -1
            if let previousState, previousState != lemming.state, actionable.contains(lemming.state),
               claim("state-\(lemming.state.rawValue)", lemming, tick: game.tick) {
                fired.append((2, lemming.id))
            }
            if let previousTool, previousTool != (lemming.tool?.rawValue ?? -1), claim("tool", lemming, tick: game.tick) {
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
        if fired.isEmpty {
            guard game.tick - lastDecisionTick >= fallback else { return nil }
            lastDecisionTick = game.tick
            let walking = game.lemmings.filter { $0.active && $0.state == .walking }.map(\.id)
            return Array(walking.prefix(1))
        }
        lastDecisionTick = game.tick
        var offered: [Int] = []
        for entry in fired.sorted(by: { ($0.priority, $0.id) < ($1.priority, $1.id) }) where !offered.contains(entry.id) {
            if offered.count == 3 { break }
            offered.append(entry.id)
        }
        return offered
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

/// Ranks candidates: saved, then lemmings neither lost nor blocking, then distance to an exit, then fewer inputs.
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
        let entrance = field.distance(x: game.configuration.entrance.x, y: game.configuration.entrance.y)
        saved = game.saved
        // A blocker can never reach an exit while it blocks, so it does not count as remaining.
        remaining = game.configuration.total - game.lost - game.lemmings.filter { $0.state == .blocking }.count
        distance = active + game.reserve * entrance
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
    add(game.tick); add(game.released)
    for lemming in game.lemmings {
        add(lemming.id); add(lemming.x); add(lemming.y); add(lemming.direction); add(lemming.age)
        for byte in lemming.state.rawValue.utf8 { add(Int(byte)) }; add(lemming.tool?.rawValue ?? -1); add(lemming.quantity)
        add(lemming.mobilityTool?.rawValue ?? -1); add(lemming.mobilityTicks)
    }
    for pickup in game.pickups { add(pickup.id); add(pickup.x); add(pickup.y); add(pickup.quantity) }
    for (key, solid) in game.terrainEdits.sorted(by: { $0.key < $1.key }) { add(key); add(solid ? 1 : 0) }
    for bomb in game.explosives { add(bomb.id); add(bomb.x); add(bomb.y); add(bomb.age) }
    for creature in game.creatures { add(creature.id); add(creature.x); add(creature.y); add(creature.alive ? 1 : 0) }
    return value
}

/// The actions to try for one lemming at a decision point.
func l3Actions(_ game: Lemmings3Runtime, lemming id: Int) -> [L3Replay.Input] {
    guard let lemming = game.lemmings.first(where: { $0.id == id && $0.active }) else { return [] }
    var result: [L3Replay.Input] = []
    for action in ["walker", "blocker", "jumper"] {
        result.append(.init(tick: game.tick, action: action, lemming: id, direction: nil))
    }
    if let tool = lemming.tool {
        result.append(.init(tick: game.tick, action: "drop", lemming: id, direction: nil))
        let directions: [Lemmings3Runtime.Direction]
        switch tool {
        case .spade: directions = [.left, .right, .down, .downLeft, .downRight]
        case .bricks: directions = [.upLeft, .upRight, .left, .right]
        case .bomb, .grenade, .hadoken, .sucker, .shimmy: directions = [lemming.direction > 0 ? .right : .left]
        default: directions = []
        }
        for direction in directions {
            result.append(.init(tick: game.tick, action: "use", lemming: id, direction: direction.rawValue))
        }
    }
    // Keep only actions the runtime accepts now.
    return result.filter { input in
        var trial = game
        return L3Replay.apply(input, to: &trial)
    }
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
func l3Search(from start: Lemmings3Runtime, limits: L3Limits) -> L3Report {
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
    var root = L3Candidate(game: start, detector: L3Detector(cell: limits.cell, refire: limits.refire))
    _ = l3Advance(&root, limits: limits)
    root.fingerprint = l3Fingerprint(root.game)
    consider(root)
    var beam = root.game.isComplete ? [] : [root]
    while !beam.isEmpty && Date().timeIntervalSince(started) < limits.budgetSeconds {
        var next: [UInt64: L3Candidate] = [:]
        for node in beam {
            if node.depth >= limits.maxDepth { consider(finish(node)); continue }
            var choices: [[L3Replay.Input]] = [[]]
            for id in node.decision { choices += l3Actions(node.game, lemming: id).map { [$0] } }
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
        if !beam.contains(where: { $0.inputs.isEmpty }), let waiting = next.values.first(where: { $0.inputs.isEmpty }) {
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
