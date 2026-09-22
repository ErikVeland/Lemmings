import CryptoKit
import Foundation
import NxlvKit

// Classic DOS route solver: a beam search over decision points, after the
// Lemmings 3 solver. A decision fires when a walker meets a wall or an edge,
// turns, or changes action. Candidates rank by saved lemmings, then lemmings
// still able to reach an exit, then total distance to an exit through open
// space, then fewer inputs. A win is written as a live after-tick replay; the
// strict `recorded` import in Tools/ClassicCompletion verifies it again.
//
// Usage: ClassicSolver DATA LEVEL OUT [--width N] [--seconds S] [--rate R] [--prefix PLAN]
// PLAN holds forced inputs as [{"tick": T, "id": N, "skill": S} or {"tick": T, "rate": R}],
// applied after their ticks; the search fills in everything else.
// DATA is a DOS data directory, or `conversion:PORTS` for the Oh Yes! pack.

struct Failure: Error, CustomStringConvertible { let description: String }

func option(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

func loadLevel(_ argument: String, _ index: Int) throws -> (ClassicDOSSimulation, ClassicCampaignLevel) {
    var campaign: ClassicCampaign, title: ClassicTitle?, root: URL, fallback: URL? = nil
    if argument.hasPrefix("conversion:") {
        let ports = URL(fileURLWithPath: String(argument.dropFirst("conversion:".count)))
        guard let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) else {
            throw Failure(description: "no conversion levels")
        }
        campaign = set.campaign; title = set.title
        root = PortExclusivePack.artworkDirectory(for: campaign.levels[index], portsRoot: ports)
        fallback = PortExclusivePack.fallbackArtworkDirectory(for: campaign.levels[index], portsRoot: ports)
    } else {
        root = URL(fileURLWithPath: argument)
        let set = try ClassicDataSet.detect(directory: root)
        campaign = set.campaign; title = set.title
    }
    let entry = campaign.levels[index], level = entry.level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: root, fallbackDirectory: fallback)
    let special = level.specialStyle == 0 ? nil : try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: root)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
    let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
        mainDATAssets: ClassicMainDATAssets.load(from: fallback ?? root),
        mechanics: ClassicDOSMechanics(title: title, rank: entry.rank))
    return (simulation, entry)
}

/// Steps to the nearest exit through open space, on a 4 pixel grid.
struct DistanceField {
    static let cell = 4
    let columns: Int, rows: Int, steps: [Int]
    init(_ sim: ClassicDOSSimulation) {
        let cell = Self.cell, width = sim.terrain.width, height = sim.terrain.height
        columns = (width + cell - 1) / cell; rows = (height + cell - 1) / cell
        let columns = self.columns, rows = self.rows
        var open = [Bool](repeating: false, count: columns * rows)
        for r in 0..<rows { for c in 0..<columns {
            var any = false
            for y in (r * cell)..<min(height, r * cell + cell) where !any {
                for x in (c * cell)..<min(width, c * cell + cell) where !sim.terrain.isSolid(x: x, y: y) { any = true; break }
            }
            open[r * columns + c] = any
        } }
        var steps = [Int](repeating: .max, count: columns * rows), queue: [Int] = []
        for trigger in sim.configuration.triggers where trigger.effect == .exit {
            let b = trigger.bounds
            let i = min(rows - 1, max(0, (b.y1 + b.y2) / 2 / cell)) * columns + min(columns - 1, max(0, (b.x1 + b.x2) / 2 / cell))
            if steps[i] != 0 { steps[i] = 0; queue.append(i) }
        }
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let c = i % columns, r = i / columns
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let nc = c + dx, nr = r + dy
                guard nc >= 0, nc < columns, nr >= 0, nr < rows else { continue }
                let n = nr * columns + nc
                guard open[n], steps[n] == .max else { continue }
                steps[n] = steps[i] + 1; queue.append(n)
            }
        }
        self.steps = steps
    }
    func distance(_ x: Int, _ y: Int) -> Int {
        let c = min(columns - 1, max(0, x / Self.cell)), r = min(rows - 1, max(0, y / Self.cell))
        for dr in [0, -1, -2] where r + dr >= 0 {
            let s = steps[(r + dr) * columns + c]
            if s != .max { return s * Self.cell }
        }
        return Self.cell * (columns + rows) * 4
    }
}

/// Fires decisions at places, as the sequel solvers do. One crowd meeting one
/// wall fires once per refire period.
struct Detector {
    let cell = 8
    var refire: Int, fallback: Int
    var lastDirection: [Int: Int] = [:], lastAction: [Int: ClassicDOSAction] = [:]
    var lastFired: [String: Int] = [:], lastDecision = 0
    mutating func claim(_ kind: String, _ l: ClassicDOSLemming, _ tick: Int) -> Bool {
        let key = "\(kind)|\(l.foot.x / cell),\(l.foot.y / cell),\(l.direction.rawValue)"
        if let t = lastFired[key], tick - t < refire { return false }
        lastFired[key] = tick; return true
    }
    mutating func update(_ sim: ClassicDOSSimulation) -> [Int]? {
        var fired: [(Int, Int)] = []
        let actionable: Set<ClassicDOSAction> = [.walking, .building, .bashing, .mining, .digging, .climbing, .falling, .floating, .shrugging]
        for l in sim.lemmings where l.isActive {
            let pd = lastDirection[l.id], pa = lastAction[l.id]
            lastDirection[l.id] = l.direction.rawValue; lastAction[l.id] = l.action
            if let pa, pa != l.action, actionable.contains(l.action), claim("s\(l.action.rawValue)", l, sim.tickCount) { fired.append((2, l.id)) }
            if pa == nil, claim("new", l, sim.tickCount) { fired.append((3, l.id)) }
            guard l.action == .walking else { continue }
            let ahead = l.foot.x + l.direction.rawValue * 6
            if ((l.foot.y - 9)...(l.foot.y - 7)).contains(where: { sim.terrain.isSolid(x: ahead, y: $0) }), claim("wall", l, sim.tickCount) { fired.append((0, l.id)) }
            if !(l.foot.y...(l.foot.y + 4)).contains(where: { sim.terrain.isSolid(x: ahead, y: $0) }), claim("edge", l, sim.tickCount) { fired.append((1, l.id)) }
            if let pd, pd != l.direction.rawValue, claim("turn", l, sim.tickCount) { fired.append((3, l.id)) }
        }
        if fired.isEmpty {
            guard sim.tickCount - lastDecision >= fallback else { return nil }
            lastDecision = sim.tickCount
            return sim.lemmings.filter { $0.isActive && $0.action == .walking }.prefix(1).map(\.id)
        }
        lastDecision = sim.tickCount
        var offered: [Int] = []
        for (_, id) in fired.sorted(by: { $0 < $1 }) where !offered.contains(id) {
            if offered.count == 3 { break }
            offered.append(id)
        }
        return offered
    }
}

struct Candidate {
    var sim: ClassicDOSSimulation
    var events: [ClassicDOSReplayEvent] = []
    var detector: Detector
    var decision: [Int] = []
    var key = ""
    var depth = 0
}

struct Score: Comparable {
    let saved: Int, remaining: Int, distance: Int, inputs: Int, key: String
    static func < (a: Score, b: Score) -> Bool {
        if a.saved != b.saved { return a.saved < b.saved }
        if a.remaining != b.remaining { return a.remaining < b.remaining }
        if a.distance != b.distance { return a.distance > b.distance }
        if a.inputs != b.inputs { return a.inputs > b.inputs }
        return a.key > b.key
    }
    init(_ c: Candidate, _ field: DistanceField) {
        let s = c.sim
        saved = s.savedCount
        remaining = s.configuration.totalLemmings - s.lostCount - s.lemmings.filter { $0.isActive && $0.action == .blocking }.count
        let entrance = s.configuration.entrances.map { field.distance($0.x, $0.y) }.min() ?? 0
        distance = s.lemmings.filter(\.isActive).reduce(0) { $0 + field.distance($1.foot.x, $1.foot.y) }
            + (s.configuration.totalLemmings - s.releasedCount) * entrance
        inputs = c.events.count
        key = c.key
    }
}

func fingerprint(_ sim: ClassicDOSSimulation) -> String { ClassicDOSReplayRecorder.stateHash(of: sim) }

let args = CommandLine.arguments
guard args.count >= 4 else { throw Failure(description: "usage: ClassicSolver DATA LEVEL OUT [--width N] [--seconds S] [--rate R]") }
let (base, entry) = try loadLevel(args[1], Int(args[2])! - 1)
let width = Int(option("--width") ?? "48")!
let budget = Double(option("--seconds") ?? "300")!
let maxDepth = Int(option("--depth") ?? "100000")!
let field = DistanceField(base)
let started = Date()
let skills: [ClassicSkill] = [.builder, .basher, .miner, .digger, .blocker, .climber, .floater, .bomber]
var start = Candidate(sim: base, detector: Detector(refire: Int(option("--refire") ?? "120")!, fallback: Int(option("--fallback") ?? "170")!))
if let rate = option("--rate").flatMap(Int.init) {
    start.sim.setReleaseRate(rate)
    start.events.append(.init(tick: 0, action: .releaseRate(rate), afterTick: true))
}

struct Forced: Decodable { let tick: Int; let id: Int?; let skill: ClassicSkill?; let rate: Int? }
let forced: [Int: [Forced]] = try option("--prefix").map {
    Dictionary(grouping: try JSONDecoder().decode([Forced].self, from: Data(contentsOf: URL(fileURLWithPath: $0))), by: \.tick)
} ?? [:]

func advance(_ c: inout Candidate) -> Bool {
    while !c.sim.isComplete && c.sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        _ = c.sim.tick()
        for f in forced[c.sim.tickCount] ?? [] {
            if let rate = f.rate {
                c.sim.setReleaseRate(rate); c.events.append(.init(tick: c.sim.tickCount, action: .releaseRate(rate), afterTick: true))
            } else if let id = f.id, let skill = f.skill, c.sim.assign(skill, to: id) == .assigned {
                c.events.append(.init(tick: c.sim.tickCount, action: .assign(lemmingID: id, skill: skill), afterTick: true))
            }
        }
        if c.sim.lostCount > c.sim.configuration.totalLemmings - c.sim.configuration.requiredToSave { return false }
        if let offered = c.detector.update(c.sim) { c.decision = offered; return true }
    }
    return false
}

var best: Candidate?, bestPartial: Candidate?, expanded = 0
@MainActor func consider(_ c: Candidate) {
    if c.sim.isComplete && c.sim.didWin, best.map({ Score($0, field) < Score(c, field) }) ?? true { best = c }
    if bestPartial.map({ Score($0, field) < Score(c, field) }) ?? true { bestPartial = c }
}
_ = advance(&start)
start.key = fingerprint(start.sim)
consider(start)
var beam = start.sim.isComplete ? [] : [start]
search: while !beam.isEmpty && best == nil && Date().timeIntervalSince(started) < budget {
    var next: [String: Candidate] = [:]
    for node in beam {
        guard node.depth < maxDepth else { continue }
        var choices: [(Int, ClassicSkill)?] = [nil]
        for id in node.decision { for skill in skills where node.sim.remainingSkillCount(skill) > 0 { choices.append((id, skill)) } }
        for choice in choices {
            var child = node
            if let (id, skill) = choice {
                guard child.sim.assign(skill, to: id) == .assigned else { continue }
                child.events.append(.init(tick: child.sim.tickCount, action: .assign(lemmingID: id, skill: skill), afterTick: true))
            }
            child.depth += 1
            expanded += 1
            let alive = advance(&child)
            child.key = fingerprint(child.sim)
            consider(child)
            if best != nil { break search }
            guard alive, !child.sim.isComplete else { continue }
            if let existing = next[child.key], !(Score(existing, field) < Score(child, field)) { continue }
            next[child.key] = child
        }
        if Date().timeIntervalSince(started) >= budget { break }
    }
    beam = next.values.sorted { Score($1, field) < Score($0, field) }.prefix(width).map { $0 }
    if !beam.contains(where: { $0.events.count == start.events.count }), let waiting = next.values.first(where: { $0.events.count == start.events.count }) {
        if beam.count == width { beam.removeLast() }
        beam.append(waiting)
    }
    if ProcessInfo.processInfo.environment["SOLVER_TRACE"] != nil, let top = beam.first {
        print("ROUND expanded \(expanded) beam \(beam.count) tick \(top.sim.tickCount) depth \(top.depth) saved \(top.sim.savedCount) lost \(top.sim.lostCount) inputs \(top.events.count)")
    }
}
let seconds = Int(Date().timeIntervalSince(started))
if let best {
    let s = best.sim
    let outcome = ClassicDOSReplayOutcome(ticks: s.tickCount, released: s.releasedCount, saved: s.savedCount,
        required: s.configuration.requiredToSave, didWin: true, stateHash: ClassicDOSReplayRecorder.stateHash(of: s))
    let replay = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: entry.level.title.trimmingCharacters(in: .whitespaces),
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: best.events, expected: outcome)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(replay).write(to: URL(fileURLWithPath: args[3]))
    print("SOLVED \(entry.rank) \(entry.number) saved \(s.savedCount)/\(s.configuration.requiredToSave) inputs \(best.events.count) expanded \(expanded) in \(seconds)s")
} else {
    let s = bestPartial?.sim
    print("UNSOLVED \(entry.rank) \(entry.number) best saved \(s?.savedCount ?? 0)/\(base.configuration.requiredToSave) expanded \(expanded) in \(seconds)s")
    exit(1)
}
