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
// Usage: ClassicSolver DATA LEVEL OUT [--width N] [--seconds S] [--rate R]
//        [--fallback N] [--refire N] [--prefix PLAN] [--partial-out]
//        [--rollout-single] [--sweep-single]
//        [--broadcast-skill SKILL --broadcast-from N --broadcast-through N]
//        [--sweep-pair FIRST,SECOND --first-from N --first-through N]
//        [--second-gap-min N --second-gap-max N]
//        [--golems-objects] [--dos-clock | --golems-clock]
//        [--golems-mechanics | --ohno-mechanics] [--member FILE#SECTION]
//        [--prefer-progress]
//        [--rescue-quota-distance]
//        [--direct-exit-distance]
//        [--focus-workers N]
//        [--canvas-width N --canvas-height N]
//        [--source-terrain-coordinates]
//        [--source-object-coordinates]
//        [--source-canvas]
// Use --golems-objects for fan levels whose later object slots must be active.
// PLAN holds forced inputs as [{"tick": T, "id": N, "skill": S} or {"tick": T, "rate": R}],
// applied after their ticks; the search fills in everything else.
// DATA is a DOS data directory, `conversion:PORTS` for the Oh Yes! pack, or
// `fan:PACK` for a fan archive. LEVEL is one-based. Fan levels also require
// `--resources RESOURCES`; --member selects an exact archive member.

struct Failure: Error, CustomStringConvertible { let description: String }

let preferProgress = CommandLine.arguments.contains("--prefer-progress")
let rescueQuotaDistance = CommandLine.arguments.contains("--rescue-quota-distance")
let directExitDistance = CommandLine.arguments.contains("--direct-exit-distance")

func option(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

func loadLevel(_ argument: String, _ index: Int) throws -> (ClassicDOSSimulation, ClassicCampaignLevel) {
    if argument.hasPrefix("fan:") {
        guard !(CommandLine.arguments.contains("--golems-mechanics")
            && CommandLine.arguments.contains("--ohno-mechanics")) else {
            throw Failure(description: "choose one mechanics override")
        }
        guard let resources = option("--resources") else {
            throw Failure(description: "fan levels require --resources RESOURCES")
        }
        let pack = URL(fileURLWithPath: String(argument.dropFirst("fan:".count)))
        let root = URL(fileURLWithPath: resources)
        let entries = try FanLevelLibrary.validatedEntries(in: pack)
        let item: FanLevelLibrary.Entry
        if let member = option("--member") {
            let matches = entries.filter { "\($0.file)#\($0.section ?? -1)" == member }
            guard matches.count == 1, let selected = matches.first else {
                throw Failure(description: "fan member is missing or ambiguous: \(member)")
            }
            item = selected
        } else {
            guard entries.indices.contains(index) else { throw Failure(description: "fan level index is out of range") }
            item = entries[index]
        }
        let (level, style) = try FanLevelLibrary.level(item, in: pack,
            preserveTextTerrainCoordinates: CommandLine.arguments.contains("--source-terrain-coordinates"),
            preserveTextObjectCoordinates: CommandLine.arguments.contains("--source-object-coordinates"))
        let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
            portsRoot: root.appendingPathComponent("Ports"), pack: pack, entry: item)
        let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack,
            portsRoot: root.appendingPathComponent("Ports"))
        let sourceCanvas = try CommandLine.arguments.contains("--source-canvas")
            ? FanLevelLibrary.textCanvasSize(item, in: pack) : nil
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
            specialGraphic: special,
            objectSemantics: CommandLine.arguments.contains("--golems-objects")
                ? .golems : .forFanLevel(level, groundSet: ground),
            canvasWidth: try option("--canvas-width").map {
                guard let value = Int($0) else { throw Failure(description: "invalid canvas width") }
                return value
            } ?? sourceCanvas?.width ?? ClassicLevel.width,
            canvasHeight: try option("--canvas-height").map {
                guard let value = Int($0) else { throw Failure(description: "invalid canvas height") }
                return value
            } ?? sourceCanvas?.height ?? ClassicLevel.height)
        let assets = try ClassicMainDATAssets.load(from: root.appendingPathComponent("Ports/lemmings_dos_1991-07-30"))
        let clock: ClassicDOSClock = CommandLine.arguments.contains("--dos-clock") ? .dos : .golems
        let mechanics: ClassicDOSMechanics = CommandLine.arguments.contains("--golems-mechanics")
            ? .golems : CommandLine.arguments.contains("--ohno-mechanics")
            ? .ohNoMore : FanLevelLibrary.mechanics(for: pack, entry: item)
        let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mainDATAssets: assets, mechanics: mechanics, clock: clock)
        let entry = ClassicCampaignLevel.standalone(level, rank: "fan:" + FanLevelLibrary.catalogueID(pack), number: index + 1)
        return (simulation, entry)
    }
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
    let exitCentres: [(x: Int, y: Int)]
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
        exitCentres = sim.configuration.triggers.filter { $0.effect == .exit }.map {
            (($0.bounds.x1 + $0.bounds.x2) / 2, ($0.bounds.y1 + $0.bounds.y2) / 2)
        }
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
        let unreachableBase = Self.cell * (columns + rows) * 4
        return unreachableBase + (exitCentres.map { abs(x - $0.x) + abs(y - $0.y) }.min() ?? 0)
    }
    func directDistance(_ x: Int, _ y: Int) -> Int {
        exitCentres.map { abs(x - $0.x) + abs(y - $0.y) }.min() ?? 0
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
    var rateChanges = 0
    var searchAssignments = 0
    var invalidForced = false
}

enum Choice {
    case wait
    case assign(Int, ClassicSkill)
    case releaseRate(Int)
}

struct Score: Comparable {
    let saved: Int, remaining: Int, distance: Int, inputs: Int, key: String
    let progressFirst: Bool
    static func < (a: Score, b: Score) -> Bool {
        if a.saved != b.saved { return a.saved < b.saved }
        if a.progressFirst {
            if a.distance != b.distance { return a.distance > b.distance }
            if a.remaining != b.remaining { return a.remaining < b.remaining }
        } else {
            if a.remaining != b.remaining { return a.remaining < b.remaining }
            if a.distance != b.distance { return a.distance > b.distance }
        }
        if a.inputs != b.inputs { return a.inputs > b.inputs }
        return a.key > b.key
    }
    init(_ c: Candidate, _ field: DistanceField, progressFirst: Bool = preferProgress) {
        let s = c.sim
        self.progressFirst = progressFirst
        saved = s.savedCount
        remaining = s.configuration.totalLemmings - s.lostCount - s.lemmings.filter { $0.isActive && $0.action == .blocking }.count
        let distanceToExit = directExitDistance ? field.directDistance : field.distance
        let entrance = s.configuration.entrances.map { distanceToExit($0.x, $0.y) }.min() ?? 0
        let distances = s.lemmings.filter { $0.isActive && (focusWorkers == 0 || $0.id < focusWorkers) }
            .map { distanceToExit($0.foot.x, $0.foot.y) }
            + Array(repeating: entrance, count: max(0,
                (focusWorkers == 0 ? s.configuration.totalLemmings : min(focusWorkers, s.configuration.totalLemmings))
                - s.releasedCount))
        if rescueQuotaDistance {
            let needed = max(0, min(
                focusWorkers == 0 ? s.configuration.requiredToSave : focusWorkers,
                s.configuration.requiredToSave - s.savedCount))
            distance = distances.count >= needed
                ? distances.sorted().prefix(needed).reduce(0, +)
                : 1_000_000
        } else {
            distance = distances.reduce(0, +)
        }
        inputs = c.events.count
        key = c.key
    }
}

func fingerprint(_ sim: ClassicDOSSimulation) -> String { ClassicDOSReplayRecorder.stateHash(of: sim) }

let args = CommandLine.arguments
guard args.count >= 4 else { throw Failure(description: "usage: ClassicSolver DATA LEVEL OUT [--width N] [--seconds S] [--rate R]") }
if args.contains("--dos-clock") && args.contains("--golems-clock") {
    throw Failure(description: "choose one fan clock: --dos-clock or --golems-clock")
}
let (base, entry) = try loadLevel(args[1], Int(args[2])! - 1)
if args.contains("--describe") {
    let available = ClassicSkill.allCases.compactMap { skill -> String? in
        let count = base.remainingSkillCount(skill)
        return count > 0 ? "\(skill.rawValue)=\(count)" : nil
    }
    print("\(entry.rank) \(entry.number) \(entry.level.title): "
        + "\(base.configuration.totalLemmings) lemmings, \(base.configuration.requiredToSave) required, "
        + "rate \(base.releaseRate), skills \(available.joined(separator: ","))")
    exit(0)
}
let tickLimit = max(ClassicDOSReplayPlayer.defaultTickLimit, base.configuration.timeLimitTicks ?? 0)
let width = Int(option("--width") ?? "48")!
let budget = Double(option("--seconds") ?? "300")!
let maxDepth = Int(option("--depth") ?? "100000")!
let adaptiveRate = args.contains("--adaptive-rate")
let rolloutSingle = args.contains("--rollout-single")
let sweepSingle = args.contains("--sweep-single")
let broadcastSkill: ClassicSkill? = try option("--broadcast-skill").map { value in
    guard let skill = ClassicSkill(rawValue: value) else {
        throw Failure(description: "--broadcast-skill requires a Classic skill name")
    }
    return skill
}
let broadcastFrom = Int(option("--broadcast-from") ?? "0")!
let broadcastThrough = Int(option("--broadcast-through") ?? "20")!
if broadcastFrom < 0 || broadcastThrough < broadcastFrom {
    throw Failure(description: "invalid broadcast delay window")
}
let sweepPair: (ClassicSkill, ClassicSkill)? = try option("--sweep-pair").map { value in
    let names = value.split(separator: ",").map(String.init)
    guard names.count == 2, let first = ClassicSkill(rawValue: names[0]),
          let second = ClassicSkill(rawValue: names[1]) else {
        throw Failure(description: "--sweep-pair requires two comma-separated skill names")
    }
    return (first, second)
}
let firstFrom = Int(option("--first-from") ?? "0")!
let firstThrough = Int(option("--first-through") ?? "200")!
let secondGapMin = Int(option("--second-gap-min") ?? "1")!
let secondGapMax = Int(option("--second-gap-max") ?? "100")!
if sweepPair != nil && (sweepSingle || rolloutSingle || args.contains("--adaptive-rate")) {
    throw Failure(description: "--sweep-pair requires a fixed-rate search without other sweep modes")
}
if broadcastSkill != nil && (sweepPair != nil || sweepSingle || rolloutSingle || adaptiveRate || option("--prefix") != nil) {
    throw Failure(description: "--broadcast-skill requires a fixed-rate search without other sweep modes or a prefix")
}
if firstFrom < 0 || firstThrough < firstFrom || secondGapMin < 1 || secondGapMax < secondGapMin {
    throw Failure(description: "invalid sweep-pair tick window")
}
let balancedRanking = args.contains("--balanced-ranking")
if balancedRanking && preferProgress { throw Failure(description: "choose either --balanced-ranking or --prefer-progress") }
let focusWorkers = Int(option("--focus-workers") ?? "0")!
if focusWorkers < 0 { throw Failure(description: "--focus-workers must be non-negative") }
if focusWorkers > 0 && (sweepSingle || sweepPair != nil || broadcastSkill != nil) {
    throw Failure(description: "--focus-workers requires the beam search")
}
if sweepSingle && (adaptiveRate || rolloutSingle) {
    throw Failure(description: "--sweep-single requires a fixed rate and cannot be combined with --rollout-single")
}
let field = DistanceField(base)
let started = ProcessInfo.processInfo.systemUptime
let deadline = started + budget
func timeExpired() -> Bool { ProcessInfo.processInfo.systemUptime >= deadline }
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
let lastForcedTick = forced.keys.max() ?? 0
for command in forced.values.flatMap({ $0 }) {
    guard command.tick >= 0,
          (command.rate != nil && command.id == nil && command.skill == nil)
            || (command.rate == nil && command.id != nil && command.skill != nil) else {
        throw Failure(description: "forced prefix contains an invalid command")
    }
}
if (sweepSingle || sweepPair != nil) && !forced.isEmpty {
    throw Failure(description: "sweep modes cannot be combined with --prefix")
}
for f in forced[0] ?? [] {
    if let rate = f.rate {
        start.sim.setReleaseRate(rate)
        start.events.append(.init(tick: 0, action: .releaseRate(rate), afterTick: true))
    } else if let id = f.id, let skill = f.skill {
        guard start.sim.assign(skill, to: id) == .assigned else {
            throw Failure(description: "forced skill assignment rejected at tick 0")
        }
        start.events.append(.init(tick: 0, action: .assign(lemmingID: id, skill: skill), afterTick: true))
    }
}

func advance(_ c: inout Candidate) -> Bool {
    while !c.sim.isComplete && c.sim.tickCount < tickLimit {
        if c.sim.tickCount.isMultiple(of: 64) && timeExpired() { return false }
        _ = c.sim.tick()
        for f in forced[c.sim.tickCount] ?? [] {
            if let rate = f.rate {
                c.sim.setReleaseRate(rate); c.events.append(.init(tick: c.sim.tickCount, action: .releaseRate(rate), afterTick: true))
            } else if let id = f.id, let skill = f.skill {
                guard c.sim.assign(skill, to: id) == .assigned else {
                    c.invalidForced = true
                    return false
                }
                c.events.append(.init(tick: c.sim.tickCount, action: .assign(lemmingID: id, skill: skill), afterTick: true))
            }
        }
        if c.sim.lostCount > c.sim.configuration.totalLemmings - c.sim.configuration.requiredToSave { return false }
        if let offered = c.detector.update(c.sim) { c.decision = offered; return true }
    }
    return false
}

var best: Candidate?, bestPartial: Candidate?, expanded = 0
var singleSkillRollouts: Set<String> = []
var waitingRouteTick = 0
var sweptAssignments = 0
var completedSweepContinuations = 0
var pairFirstAssignments = 0
var pairSecondAssignments = 0
var broadcastDelaysCompleted = 0
func isBetterPartial(_ candidate: Candidate, than current: Candidate) -> Bool {
    let proposed = candidate.sim
    let previous = current.sim
    if proposed.savedCount != previous.savedCount { return proposed.savedCount > previous.savedCount }
    let proposedViable = proposed.lostCount <= proposed.configuration.totalLemmings - proposed.configuration.requiredToSave
    let previousViable = previous.lostCount <= previous.configuration.totalLemmings - previous.configuration.requiredToSave
    if proposedViable != previousViable { return proposedViable }
    if candidate.searchAssignments != current.searchAssignments {
        return candidate.searchAssignments > current.searchAssignments
    }
    if proposed.releasedCount != previous.releasedCount { return proposed.releasedCount > previous.releasedCount }
    return Score(current, field) < Score(candidate, field)
}
func consider(_ c: Candidate) {
    if c.sim.tickCount < lastForcedTick { return }
    if c.sim.isComplete && c.sim.didWin, best.map({ Score($0, field) < Score(c, field) }) ?? true { best = c }
    if bestPartial.map({ isBetterPartial(c, than: $0) }) ?? true { bestPartial = c }
}
if !sweepSingle && broadcastSkill == nil && forced.isEmpty {
    var passive = start
    while !passive.sim.isComplete && passive.sim.tickCount < tickLimit {
        if passive.sim.tickCount.isMultiple(of: 64) && timeExpired() { break }
        _ = passive.sim.tick()
        if passive.sim.lostCount > passive.sim.configuration.totalLemmings
            - passive.sim.configuration.requiredToSave { break }
    }
    consider(passive)
}
if let broadcastSkill {
    broadcastSearch: for delay in broadcastFrom...broadcastThrough {
        if timeExpired() { break }
        var candidate = start
        var spawnTicks: [Int: Int] = [:]
        var assigned: Set<Int> = []
        while !candidate.sim.isComplete && candidate.sim.tickCount < tickLimit {
            if candidate.sim.tickCount.isMultiple(of: 64) && timeExpired() { break broadcastSearch }
            _ = candidate.sim.tick()
            for event in candidate.sim.lastTickEvents {
                if case let .hatched(id, _) = event { spawnTicks[id] = candidate.sim.tickCount }
            }
            for lemming in candidate.sim.lemmings where lemming.isActive && !assigned.contains(lemming.id) {
                guard let spawnTick = spawnTicks[lemming.id], candidate.sim.tickCount - spawnTick >= delay else { continue }
                if candidate.sim.assign(broadcastSkill, to: lemming.id) == .assigned {
                    candidate.events.append(.init(tick: candidate.sim.tickCount,
                        action: .assign(lemmingID: lemming.id, skill: broadcastSkill), afterTick: true))
                    assigned.insert(lemming.id)
                    expanded += 1
                }
            }
        }
        broadcastDelaysCompleted += 1
        consider(candidate)
        if candidate.sim.didWin { best = candidate; break }
    }
} else if let (firstSkill, secondSkill) = sweepPair {
    var waiting = start
    bestPartial = start
    pairSearch: while !waiting.sim.isComplete && waiting.sim.tickCount < min(tickLimit, firstThrough) && !timeExpired() {
        _ = waiting.sim.tick()
        waitingRouteTick = waiting.sim.tickCount
        guard waiting.sim.tickCount >= firstFrom else { continue }
        for lemming in waiting.sim.lemmings where lemming.isActive {
            if timeExpired() { break pairSearch }
            var first = waiting
            guard first.sim.assign(firstSkill, to: lemming.id) == .assigned else { continue }
            first.events.append(.init(tick: waiting.sim.tickCount,
                action: .assign(lemmingID: lemming.id, skill: firstSkill), afterTick: true))
            pairFirstAssignments += 1
            for gap in 1...secondGapMax {
                if timeExpired() { break pairSearch }
                guard !first.sim.isComplete, first.sim.tickCount < tickLimit else { break }
                _ = first.sim.tick()
                if first.sim.lostCount > first.sim.configuration.totalLemmings
                    - first.sim.configuration.requiredToSave { break }
                guard gap >= secondGapMin else { continue }
                for secondLemming in first.sim.lemmings where secondLemming.isActive {
                    if timeExpired() { break pairSearch }
                    var continuation = first
                    guard continuation.sim.assign(secondSkill, to: secondLemming.id) == .assigned else { continue }
                    continuation.events.append(.init(tick: first.sim.tickCount,
                        action: .assign(lemmingID: secondLemming.id, skill: secondSkill), afterTick: true))
                    pairSecondAssignments += 1
                    expanded += 1
                    while !continuation.sim.isComplete && continuation.sim.tickCount < tickLimit {
                        if continuation.sim.tickCount.isMultiple(of: 64) && timeExpired() { break pairSearch }
                        _ = continuation.sim.tick()
                        if continuation.sim.lostCount > continuation.sim.configuration.totalLemmings
                            - continuation.sim.configuration.requiredToSave { break }
                    }
                    completedSweepContinuations += 1
                    if continuation.sim.savedCount > (bestPartial?.sim.savedCount ?? 0) {
                        consider(continuation)
                    }
                    if continuation.sim.didWin { best = continuation; break pairSearch }
                }
            }
        }
        if waiting.sim.lostCount > waiting.sim.configuration.totalLemmings
            - waiting.sim.configuration.requiredToSave { break }
    }
    if best == nil { consider(waiting) }
} else if sweepSingle {
    var waiting = start
    bestPartial = start
    sweep: while !waiting.sim.isComplete && waiting.sim.tickCount < tickLimit && !timeExpired() {
        _ = waiting.sim.tick()
        waitingRouteTick = waiting.sim.tickCount
        if waiting.sim.didWin { best = waiting; break }
        for lemming in waiting.sim.lemmings where lemming.isActive {
            for skill in skills where waiting.sim.remainingSkillCount(skill) > 0 {
                if timeExpired() { break sweep }
                var continuation = waiting
                guard continuation.sim.assign(skill, to: lemming.id) == .assigned else { continue }
                continuation.events.append(.init(tick: waiting.sim.tickCount,
                    action: .assign(lemmingID: lemming.id, skill: skill), afterTick: true))
                sweptAssignments += 1
                expanded += 1
                while !continuation.sim.isComplete && continuation.sim.tickCount < tickLimit {
                    if continuation.sim.tickCount.isMultiple(of: 64) && timeExpired() { break }
                    _ = continuation.sim.tick()
                    if continuation.sim.lostCount > continuation.sim.configuration.totalLemmings
                        - continuation.sim.configuration.requiredToSave { break }
                }
                if continuation.sim.isComplete || continuation.sim.tickCount >= tickLimit
                    || continuation.sim.lostCount > continuation.sim.configuration.totalLemmings
                        - continuation.sim.configuration.requiredToSave {
                    completedSweepContinuations += 1
                }
                if continuation.sim.savedCount > (bestPartial?.sim.savedCount ?? 0) {
                    consider(continuation)
                }
                if continuation.sim.didWin { best = continuation; break sweep }
            }
        }
        if waiting.sim.lostCount > waiting.sim.configuration.totalLemmings
            - waiting.sim.configuration.requiredToSave { break }
    }
    if best == nil { consider(waiting) }
} else {
    _ = advance(&start)
    if start.invalidForced { throw Failure(description: "forced skill assignment rejected before search") }
    waitingRouteTick = start.sim.tickCount
    start.key = fingerprint(start.sim) + (adaptiveRate ? "|0" : "")
    consider(start)
    var beam = start.sim.isComplete ? [] : [start]
    search: while !beam.isEmpty && best == nil && !timeExpired() {
        var next: [String: Candidate] = [:]
        for node in beam {
            if timeExpired() { break search }
            guard node.depth < maxDepth else { continue }
            var choices: [Choice] = [.wait]
            for id in node.decision where focusWorkers == 0 || id < focusWorkers {
                for skill in skills where node.sim.remainingSkillCount(skill) > 0 {
                    choices.append(.assign(id, skill))
                }
            }
            if adaptiveRate && node.rateChanges < 2 && node.sim.releasedCount < node.sim.configuration.totalLemmings {
                for rate in [25, 50, 75, 99] where rate > node.sim.releaseRate {
                    choices.append(.releaseRate(rate))
                }
            }
            for choice in choices {
                if timeExpired() { break search }
                var child = node
                switch choice {
                case .wait:
                    break
                case let .assign(id, skill):
                    guard child.sim.assign(skill, to: id) == .assigned else { continue }
                    child.events.append(.init(tick: child.sim.tickCount, action: .assign(lemmingID: id, skill: skill), afterTick: true))
                    child.searchAssignments += 1
                case let .releaseRate(rate):
                    child.sim.setReleaseRate(rate)
                    child.events.append(.init(tick: child.sim.tickCount, action: .releaseRate(rate), afterTick: true))
                    child.rateChanges += 1
                }
                child.depth += 1
                expanded += 1
                let alive = advance(&child)
                if child.invalidForced { continue }
                if child.searchAssignments == 0 {
                    waitingRouteTick = max(waitingRouteTick, child.sim.tickCount)
                }
                child.key = fingerprint(child.sim) + (adaptiveRate ? "|\(child.rateChanges)" : "")
                consider(child)
                if best != nil { break search }
                if rolloutSingle, node.searchAssignments == 0,
                   case let .assign(id, skill) = choice,
                   forced.keys.allSatisfy({ $0 <= child.sim.tickCount }) {
                    let signature = "\(node.key)|\(id)|\(skill)"
                    if singleSkillRollouts.insert(signature).inserted {
                        var continuation = child
                        while !continuation.sim.isComplete && continuation.sim.tickCount < tickLimit {
                            if continuation.sim.tickCount.isMultiple(of: 64) && timeExpired() { break }
                            _ = continuation.sim.tick()
                            if continuation.sim.lostCount > continuation.sim.configuration.totalLemmings - continuation.sim.configuration.requiredToSave { break }
                        }
                        consider(continuation)
                        if continuation.sim.didWin { best = continuation; break search }
                    }
                }
                guard alive, !child.sim.isComplete else { continue }
                if let existing = next[child.key], !(Score(existing, field) < Score(child, field)) { continue }
                next[child.key] = child
            }
            if timeExpired() { break search }
        }
        if balancedRanking {
            let pool = Array(next.values)
            let survivor = pool.sorted { Score($1, field, progressFirst: false) < Score($0, field, progressFirst: false) }
            let progress = pool.sorted { Score($1, field, progressFirst: true) < Score($0, field, progressFirst: true) }
            var seen: Set<String> = []
            var selected: [Candidate] = []
            for ranking in [survivor.prefix(max(1, width / 2)), progress.prefix(max(1, width / 2))] {
                for candidate in ranking where selected.count < width && seen.insert(candidate.key).inserted {
                    selected.append(candidate)
                }
            }
            for candidate in survivor where selected.count < width && seen.insert(candidate.key).inserted {
                selected.append(candidate)
            }
            beam = selected
        } else {
            beam = next.values.sorted { Score($1, field) < Score($0, field) }.prefix(width).map { $0 }
        }
        if !beam.contains(where: { $0.searchAssignments == 0 }), let waiting = next.values.first(where: { $0.searchAssignments == 0 }) {
            if beam.count == width { beam.removeLast() }
            beam.append(waiting)
        }
        if ProcessInfo.processInfo.environment["SOLVER_TRACE"] != nil, let top = beam.first {
            print("ROUND expanded \(expanded) beam \(beam.count) tick \(top.sim.tickCount) depth \(top.depth) saved \(top.sim.savedCount) lost \(top.sim.lostCount) inputs \(top.events.count)")
        }
    }
}
let seconds = Int(ProcessInfo.processInfo.systemUptime - started)
let route = best ?? bestPartial
let proposal = route.map {
    ClassicDOSReplay(rank: entry.rank, number: entry.number,
        title: entry.level.title.trimmingCharacters(in: .whitespaces),
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: $0.events)
}
let forcedInputsSatisfied = proposal.map { replay in
    forced.values.flatMap { $0 }.allSatisfy { command in
        replay.events.contains { event in
            guard event.tick == command.tick && event.afterTick == true else { return false }
            if let rate = command.rate { return event.action == .releaseRate(rate) }
            if let id = command.id, let skill = command.skill {
                return event.action == .assign(lemmingID: id, skill: skill)
            }
            return false
        }
    }
} ?? forced.isEmpty
let verifiedOutcome = proposal.flatMap {
    try? ClassicDOSReplayPlayer.run($0, simulation: base, tickLimit: tickLimit)
}
let coverage = broadcastSkill != nil
    ? " broadcast delays completed \(broadcastDelaysCompleted) deadline \(timeExpired())"
    : sweepPair != nil
    ? " waiting tick \(waitingRouteTick) first-skill assignments \(pairFirstAssignments) second-skill assignments \(pairSecondAssignments) completed \(completedSweepContinuations) deadline \(timeExpired())"
    : sweepSingle
    ? " waiting tick \(waitingRouteTick) single-skill assignments \(sweptAssignments) completed \(completedSweepContinuations) deadline \(timeExpired())"
    : rolloutSingle ? " waiting tick \(waitingRouteTick) single-skill rollouts \(singleSkillRollouts.count)" : ""
if let proposal, let outcome = verifiedOutcome, outcome.didWin, forcedInputsSatisfied {
    let replay = ClassicDOSReplay(rank: proposal.rank, number: proposal.number,
        title: proposal.title, initialStateHash: proposal.initialStateHash,
        events: proposal.events, expected: outcome)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let destination = args.contains("--hash-named")
        ? URL(fileURLWithPath: args[3]).appendingPathComponent(replay.initialStateHash + ".json")
        : URL(fileURLWithPath: args[3])
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try encoder.encode(replay).write(to: destination, options: .atomic)
    print("SOLVED \(entry.rank) \(entry.number) saved \(outcome.saved)/\(outcome.required) inputs \(replay.events.count) expanded \(expanded) in \(seconds)s\(coverage)")
} else {
    let s = bestPartial?.sim
    if args.contains("--partial-out"), let proposal, forcedInputsSatisfied {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let destination = args.contains("--hash-named")
            ? URL(fileURLWithPath: args[3]).appendingPathComponent(proposal.initialStateHash + ".partial.json")
            : URL(fileURLWithPath: args[3] + ".partial.json")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try encoder.encode(proposal).write(to: destination, options: .atomic)
    }
    let state = s.map { " tick \($0.tickCount) released \($0.releasedCount) lost \($0.lostCount) active \($0.lemmings.filter(\.isActive).count) complete \($0.isComplete)" } ?? ""
    print("UNSOLVED \(entry.rank) \(entry.number) best saved \(s?.savedCount ?? 0)/\(base.configuration.requiredToSave) expanded \(expanded) in \(seconds)s\(coverage)\(state)")
    if args.contains("--diagnose-active"), let s {
        for lemming in s.lemmings where lemming.isActive {
            print("ACTIVE id \(lemming.id) x \(lemming.foot.x) y \(lemming.foot.y) direction \(lemming.direction) action \(lemming.action)")
        }
    }
    exit(1)
}
