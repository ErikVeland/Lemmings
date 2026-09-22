import CoreGraphics
import CoreText
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

// Level lab: inspect, render and run ordered coordinate plans against the native
// Classic DOS engine. Output replays use live after-tick inputs and are imported
// through the strict completion tool, which validates them independently.

struct Failure: Error, CustomStringConvertible { let description: String }

// DATA is a DOS data directory, or `conversion:PORTS` for the Oh Yes! pack.
// Conversion ranks take their artwork from different releases, so assets are
// resolved per level in the same way as Tools/ClassicValidation.
struct Content {
    let campaign: ClassicCampaign
    let title: ClassicTitle?
    let directory: URL
    let portsRoot: URL?
    init(argument: String) throws {
        if argument.hasPrefix("conversion:") {
            let ports = URL(fileURLWithPath: String(argument.dropFirst("conversion:".count)))
            guard let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) else {
                throw Failure(description: "no conversion levels under \(ports.path)")
            }
            campaign = set.campaign; title = set.title; directory = ports; portsRoot = ports
        } else {
            directory = URL(fileURLWithPath: argument)
            let set = try ClassicDataSet.detect(directory: directory)
            campaign = set.campaign; title = set.title; portsRoot = nil
        }
    }
    func load(_ index: Int, mechanics override: ClassicDOSMechanics? = nil) throws -> (ClassicDOSSimulation, ClassicCampaignLevel, ClassicRenderedLevel) {
        let entry = campaign.levels[index]
        let level = entry.level
        var root = directory, fallback: URL? = nil
        if let portsRoot {
            root = PortExclusivePack.artworkDirectory(for: entry, portsRoot: portsRoot)
            fallback = PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: portsRoot)
        }
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: root, fallbackDirectory: fallback)
        let special = level.specialStyle == 0 ? nil : try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: root)
        let assets = try ClassicMainDATAssets.load(from: fallback ?? root)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
        let mechanics = override ?? ClassicDOSMechanics(title: title, rank: entry.rank)
        return (try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets, mechanics: mechanics), entry, rendered)
    }
}

struct Step: Codable {
    var skill: ClassicSkill?
    var id: Int?
    var x: Int?
    var xMin: Int?
    var xMax: Int?
    var y: Int?
    var yMin: Int?
    var yMax: Int?
    var direction: Int?
    var action: String?
    var tick: Int?
    var rate: Int?
    var nuke: Bool?
    var notID: [Int]?
    var async: Bool?
    var exactTick: Bool?
}

struct Result {
    var sim: ClassicDOSSimulation
    var events: [ClassicDOSReplayEvent]
    var applied: Int
}

func matches(_ step: Step, _ lem: ClassicDOSLemming, lastID: Int) -> Bool {
    if let id = step.id, lem.id != (id == -1 ? lastID : id) { return false }
    if let ids = step.notID, ids.contains(lem.id) { return false }
    if let x = step.x, lem.foot.x != x { return false }
    if let v = step.xMin, lem.foot.x < v { return false }
    if let v = step.xMax, lem.foot.x > v { return false }
    if let y = step.y, lem.foot.y != y { return false }
    if let v = step.yMin, lem.foot.y < v { return false }
    if let v = step.yMax, lem.foot.y > v { return false }
    if let d = step.direction, lem.direction.rawValue != d { return false }
    if let a = step.action, lem.action.rawValue != a { return false }
    return true
}

func runPlan(_ steps: [Step], base: ClassicDOSSimulation, until: Int? = nil, verbose: Bool, traceIDs: Set<Int> = [], every: Int = 50, stopLoss: Bool = true) -> Result {
    var sim = base
    var events: [ClassicDOSReplayEvent] = []
    let asyncSteps = steps.filter { $0.async == true }
    let steps = steps.filter { $0.async != true }
    var asyncDone = Array(repeating: false, count: asyncSteps.count)
    var index = 0
    var lastID = 0
    let limit = until ?? ClassicDOSReplayPlayer.defaultTickLimit
    while !sim.isComplete && sim.tickCount < limit {
        _ = sim.tick()
        for (ai, step) in asyncSteps.enumerated() where !asyncDone[ai] {
            if let t = step.tick, sim.tickCount < t { continue }
            if step.exactTick == true, let t = step.tick, sim.tickCount != t { continue }
            if let rate = step.rate {
                sim.setReleaseRate(rate); events.append(.init(tick: sim.tickCount, action: .releaseRate(rate), afterTick: true)); asyncDone[ai] = true; continue
            }
            guard let skill = step.skill else { asyncDone[ai] = true; continue }
            for lem in sim.lemmings where lem.isActive && matches(step, lem, lastID: lastID) {
                if sim.assign(skill, to: lem.id) == .assigned {
                    events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill), afterTick: true))
                    if verbose { print("ASYNC", ai, sim.tickCount, lem.id, skill.rawValue, lem.foot.x, lem.foot.y, lem.action.rawValue, lem.direction.rawValue) }
                    asyncDone[ai] = true
                    break
                }
            }
        }
        if !traceIDs.isEmpty && sim.tickCount % every == 0 {
            for lem in sim.lemmings where traceIDs.contains(lem.id) {
                print("T", sim.tickCount, lem.id, lem.foot.x, lem.foot.y, lem.action.rawValue, lem.direction.rawValue, lem.outcome.rawValue)
            }
        }
        // Several non-assignment steps may fire on the same tick; one assignment per tick.
        while index < steps.count {
            let step = steps[index]
            if let t = step.tick, sim.tickCount < t { break }
            if let rate = step.rate {
                sim.setReleaseRate(rate)
                events.append(.init(tick: sim.tickCount, action: .releaseRate(rate), afterTick: true))
                if verbose { print("STEP", index, sim.tickCount, "rate", rate) }
                index += 1; continue
            }
            if step.nuke == true {
                sim.beginNuke()
                events.append(.init(tick: sim.tickCount, action: .nuke, afterTick: true))
                if verbose { print("STEP", index, sim.tickCount, "nuke") }
                index += 1; continue
            }
            guard let skill = step.skill else { index += 1; continue }
            var done = false
            for lem in sim.lemmings where lem.isActive && matches(step, lem, lastID: lastID) {
                if sim.assign(skill, to: lem.id) == .assigned {
                    events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill), afterTick: true))
                    if verbose { print("STEP", index, sim.tickCount, lem.id, skill.rawValue, lem.foot.x, lem.foot.y, lem.action.rawValue, lem.direction.rawValue) }
                    lastID = lem.id
                    index += 1
                    done = true
                    break
                }
            }
            if !done { break }
            break
        }
        if stopLoss && sim.lostCount > sim.configuration.totalLemmings - sim.configuration.requiredToSave && until == nil { break }
    }
    return Result(sim: sim, events: events, applied: index)
}


struct BeamNode {
    var sim: ClassicDOSSimulation
    var events: [ClassicDOSReplayEvent]
    var index: Int
    var asyncDone: [Bool]
    var lastID: Int
    var trailAssigns: Int
    var best: Int
    var wp: Int = 0
}

// Advance one tick with the scripted plan, like runPlan.
func stepPlan(_ n: inout BeamNode, seq: [Step], asyncSteps: [Step]) {
    _ = n.sim.tick()
    for (ai, step) in asyncSteps.enumerated() where !n.asyncDone[ai] {
        if let t = step.tick, n.sim.tickCount < t { continue }
        if let rate = step.rate { n.sim.setReleaseRate(rate); n.events.append(.init(tick: n.sim.tickCount, action: .releaseRate(rate), afterTick: true)); n.asyncDone[ai] = true; continue }
        if step.nuke == true { n.sim.beginNuke(); n.events.append(.init(tick: n.sim.tickCount, action: .nuke, afterTick: true)); n.asyncDone[ai] = true; continue }
        guard let skill = step.skill else { n.asyncDone[ai] = true; continue }
        for lem in n.sim.lemmings where lem.isActive && matches(step, lem, lastID: n.lastID) {
            if n.sim.assign(skill, to: lem.id) == .assigned {
                n.events.append(.init(tick: n.sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill), afterTick: true))
                n.asyncDone[ai] = true; break
            }
        }
    }
    while n.index < seq.count {
        let step = seq[n.index]
        if let t = step.tick, n.sim.tickCount < t { break }
        if let rate = step.rate { n.sim.setReleaseRate(rate); n.events.append(.init(tick: n.sim.tickCount, action: .releaseRate(rate), afterTick: true)); n.index += 1; continue }
        if step.nuke == true { n.sim.beginNuke(); n.events.append(.init(tick: n.sim.tickCount, action: .nuke, afterTick: true)); n.index += 1; continue }
        guard let skill = step.skill else { n.index += 1; continue }
        var done = false
        for lem in n.sim.lemmings where lem.isActive && matches(step, lem, lastID: n.lastID) {
            if n.sim.assign(skill, to: lem.id) == .assigned {
                n.events.append(.init(tick: n.sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill), afterTick: true))
                n.lastID = lem.id; n.index += 1; done = true; break
            }
        }
        if !done { break }
        break
    }
}

func runBeam(base: ClassicDOSSimulation, steps: [Step], trail: Int, targets: [(Int, Int)], skills: [ClassicSkill], width: Int, stride: Int, maxAssigns: Int, until: Int, requireAll: Bool) -> BeamNode? {
    let asyncSteps = steps.filter { $0.async == true }
    let seq = steps.filter { $0.async != true }
    var beam = [BeamNode(sim: base, events: [], index: 0, asyncDone: Array(repeating: false, count: asyncSteps.count), lastID: 0, trailAssigns: 0, best: 1 << 20)]
    var bestSaved: BeamNode?
    func dist(_ n: BeamNode) -> Int {
        guard trail < n.sim.lemmings.count else { return 1 << 20 }
        let l = n.sim.lemmings[trail]
        let t = targets[min(n.wp, targets.count - 1)]
        return abs(l.foot.x - t.0) + abs(l.foot.y - t.1) + (targets.count - 1 - n.wp) * 2000
    }
    while let head = beam.first, head.sim.tickCount < until {
        var next: [BeamNode] = []
        var seen = Set<String>()
        for var node in beam {
            // Branch before advancing, so the assignment applies after this tick like a live input.
            stepPlan(&node, seq: seq, asyncSteps: asyncSteps)
            if node.sim.isComplete { if node.sim.didWin { return node }; continue }
            let tick = node.sim.tickCount
            var candidates = [node]
            if trail < node.sim.lemmings.count, node.trailAssigns < maxAssigns, tick % stride == 0 || node.sim.lemmings[trail].action == .shrugging {
                let l = node.sim.lemmings[trail]
                if l.isActive {
                    for sk in skills where node.sim.remainingSkillCount(sk) > 0 {
                        var fork = node
                        if fork.sim.assign(sk, to: trail) == .assigned {
                            fork.events.append(.init(tick: tick, action: .assign(lemmingID: trail, skill: sk), afterTick: true))
                            fork.trailAssigns += 1
                            candidates.append(fork)
                        }
                    }
                }
            }
            for var c in candidates {
                if trail < c.sim.lemmings.count {
                    let l = c.sim.lemmings[trail]
                    if l.outcome == .lost { continue }
                    if l.outcome == .saved {
                        if !requireAll { return c }
                        if bestSaved == nil || c.sim.savedCount > bestSaved!.sim.savedCount { bestSaved = c }
                    }
                }
                if requireAll && c.sim.lostCount > c.sim.configuration.totalLemmings - c.sim.configuration.requiredToSave { continue }
                if c.wp < targets.count - 1, trail < c.sim.lemmings.count {
                    let l = c.sim.lemmings[trail]; let t = targets[c.wp]
                    if abs(l.foot.x - t.0) + abs(l.foot.y - t.1) <= 10 { c.wp += 1; c.best = 1 << 20 }
                }
                c.best = min(c.best, dist(c))
                let key = ClassicDOSReplayRecorder.stateHash(of: c.sim) + ":\(c.index)"
                if !seen.insert(key).inserted { continue }
                next.append(c)
            }
        }
        if next.isEmpty { break }
        next.sort { (a, b) in
            let da = dist(a) * 4 + a.best + a.trailAssigns * 6
            let db = dist(b) * 4 + b.best + b.trailAssigns * 6
            return da < db
        }
        // Keep some of every assignment count so frugal routes survive.
        var buckets: [Int: [BeamNode]] = [:]
        for n in next { buckets[n.trailAssigns, default: []].append(n) }
        let share = max(2, width / max(1, buckets.count))
        var kept: [BeamNode] = []
        for (_, b) in buckets { kept.append(contentsOf: b.prefix(share)) }
        kept.sort { dist($0) * 4 + $0.best + $0.trailAssigns * 6 < dist($1) * 4 + $1.best + $1.trailAssigns * 6 }
        beam = Array(kept.prefix(width))
        if head.sim.tickCount % 200 == 0 {
            FileHandle.standardError.write(Data("tick \(head.sim.tickCount) beam \(beam.count) bestdist \(dist(beam[0])) wp \(beam[0].wp) assigns \(beam[0].trailAssigns)\n".utf8))
        }
    }
    return bestSaved ?? beam.first
}

func summary(_ r: Result, _ steps: [Step]) -> String {
    let s = r.sim
    return "RESULT applied \(r.applied)/\(steps.count) tick \(s.tickCount) released \(s.releasedCount) saved \(s.savedCount)/\(s.configuration.requiredToSave) lost \(s.lostCount) active \(s.activeCount) win \(s.didWin)"
}

func actionColor(_ a: ClassicDOSAction) -> (CGFloat, CGFloat, CGFloat) {
    switch a {
    case .walking: return (0.1, 1, 0.1)
    case .falling, .jumping: return (1, 1, 0.2)
    case .floating: return (1, 0.6, 1)
    case .climbing, .hoisting: return (0.2, 1, 1)
    case .blocking: return (1, 0.2, 0.2)
    case .building, .shrugging: return (1, 0.6, 0.1)
    case .bashing, .mining, .digging: return (0.5, 0.5, 1)
    case .exiting: return (1, 1, 1)
    default: return (0.8, 0.1, 0.1)
    }
}

func render(_ sim: ClassicDOSSimulation, original: ClassicRenderedLevel, crop: (Int, Int, Int, Int)?, scale: Int, url: URL, labels: Bool) {
    let t = sim.terrain
    let (cx1, cy1, cx2, cy2) = crop ?? (0, 0, t.width - 1, t.height - 1)
    let w = (cx2 - cx1 + 1) * scale, h = (cy2 - cy1 + 1) * scale + 14
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(red: 0, green: 0, blue: 0.08, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    func fy(_ y: Int) -> Int { h - 14 - (y - cy1 + 1) * scale }
    let rgba = [UInt8](original.rgba)
    for y in cy1...cy2 {
        for x in cx1...cx2 {
            let solid = t.isSolid(x: x, y: y)
            let o = (y * original.width + x) * 4
            let wasSolid = x < original.width && y < original.height && rgba[o + 3] > 0
            if solid {
                if t.isSteelProtected(x: x, y: y) { ctx.setFillColor(red: 0.45, green: 0.6, blue: 0.9, alpha: 1) }
                else if wasSolid { ctx.setFillColor(red: CGFloat(rgba[o]) / 255 * 0.7 + 0.15, green: CGFloat(rgba[o + 1]) / 255 * 0.7 + 0.15, blue: CGFloat(rgba[o + 2]) / 255 * 0.7 + 0.15, alpha: 1) }
                else { ctx.setFillColor(red: 1, green: 0.85, blue: 0.3, alpha: 1) }
                ctx.fill(CGRect(x: (x - cx1) * scale, y: fy(y), width: scale, height: scale))
            } else if wasSolid {
                ctx.setFillColor(red: 0.25, green: 0.1, blue: 0.1, alpha: 1)
                ctx.fill(CGRect(x: (x - cx1) * scale, y: fy(y), width: scale, height: scale))
            }
        }
    }
    for trig in sim.configuration.triggers {
        switch trig.effect {
        case .exit: ctx.setStrokeColor(red: 0, green: 1, blue: 0, alpha: 1)
        case .water: ctx.setStrokeColor(red: 0.2, green: 0.4, blue: 1, alpha: 1)
        case .fire: ctx.setStrokeColor(red: 1, green: 0.3, blue: 0, alpha: 1)
        case .triggeredTrap: ctx.setStrokeColor(red: 1, green: 0, blue: 1, alpha: 1)
        case .oneWayLeft, .oneWayRight: ctx.setStrokeColor(red: 1, green: 1, blue: 0, alpha: 1)
        default: ctx.setStrokeColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        }
        let b = trig.bounds
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: (b.x1 - cx1) * scale, y: fy(b.y2), width: (b.x2 - b.x1 + 1) * scale, height: (b.y2 - b.y1 + 1) * scale))
    }
    for e in sim.configuration.entrances {
        ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.stroke(CGRect(x: (e.x - cx1 - 4) * scale, y: fy(e.y), width: 8 * scale, height: 4 * scale))
    }
    // Grid every 50 px, labelled.
    let font = CTFontCreateWithName("Menlo" as CFString, 9, nil)
    func text(_ s: String, _ x: Int, _ y: Int) {
        let attr = NSAttributedString(string: s, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1)])
        let line = CTLineCreateWithAttributedString(attr)
        ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, ctx)
    }
    ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 0.18)
    for gx in stride(from: (cx1 + 49) / 50 * 50, through: cx2, by: 50) {
        ctx.stroke(CGRect(x: (gx - cx1) * scale, y: 14, width: 0, height: h - 14))
        text("\(gx)", (gx - cx1) * scale + 1, 2)
    }
    for gy in stride(from: (cy1 + 19) / 20 * 20, through: cy2, by: 20) {
        ctx.stroke(CGRect(x: 0, y: fy(gy), width: w, height: 0))
        text("\(gy)", 1, fy(gy) + 1)
    }
    for lem in sim.lemmings where lem.isActive {
        let (r, g, b) = actionColor(lem.action)
        ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
        ctx.fill(CGRect(x: (lem.foot.x - cx1) * scale - scale / 2, y: fy(lem.foot.y), width: max(2, scale), height: 8 * scale))
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: (lem.foot.x - cx1 + lem.direction.rawValue * 2) * scale, y: fy(lem.foot.y - 7), width: max(1, scale), height: max(1, scale)))
        if labels { text("\(lem.id)", (lem.foot.x - cx1) * scale + 2, fy(lem.foot.y - 10)) }
    }
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
}

func option(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

let args = CommandLine.arguments
let command = args[1]
let content = try Content(argument: args[2])
let index = Int(args[3])! - 1
// --mechanics original|ohNoMore overrides the level's own rule set.
let (base, entry, original) = try content.load(index, mechanics: option("--mechanics").flatMap(ClassicDOSMechanics.init(rawValue:)))
let c = base.configuration

switch command {
case "info":
    print(entry.rank, entry.number, entry.level.title.trimmingCharacters(in: .whitespaces))
    print("size \(base.terrain.width)x\(base.terrain.height) lemmings \(c.totalLemmings) required \(c.requiredToSave) timeTicks \(c.timeLimitTicks.map(String.init) ?? "none") (\((c.timeLimitTicks ?? 0) / 17)s) rate \(c.initialReleaseRate) maxX \(c.maximumX) maxY \(c.maximumY)")
    print("skills", ClassicSkill.allCases.map { "\($0.rawValue)=\(c.initialSkills[$0] ?? 0)" }.joined(separator: " "))
    print("entrances", c.entrances.map { "(\($0.x),\($0.y))" }.joined(separator: " "))
    for t in c.triggers { print("trigger", t.id, t.effect, t.bounds.x1, t.bounds.y1, t.bounds.x2, t.bounds.y2, "reset", t.trapResetTicks) }
case "run", "replay":
    let steps = try JSONDecoder().decode([Step].self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
    let until = option("--until").flatMap(Int.init)
    let ids = Set((option("--trace") ?? "").split(separator: ",").compactMap { Int($0) })
    let result = runPlan(steps, base: base, until: until, verbose: true, traceIDs: ids, every: option("--every").flatMap(Int.init) ?? 50, stopLoss: args.contains("--nostop") == false)
    print(summary(result, steps))
    if let png = option("--png") {
        let crop = option("--crop").map { s -> (Int, Int, Int, Int) in let v = s.split(separator: ",").map { Int($0)! }; return (v[0], v[1], v[2], v[3]) }
        render(result.sim, original: original, crop: crop, scale: option("--scale").flatMap(Int.init) ?? 1, url: URL(fileURLWithPath: png), labels: args.contains("--labels"))
    }
    if let m = option("--map") {
        let v = m.split(separator: ",").map { Int($0)! }
        for y in v[2]...v[3] {
            var row = String(format: "%3d ", y)
            for x in v[0]...v[1] { row += result.sim.terrain.isSolid(x: x, y: y) ? "#" : "." }
            print(row)
        }
    }
    if args.contains("--lost") {
        let groups = Dictionary(grouping: result.sim.lemmings.filter { $0.outcome == .lost }, by: { "\($0.action.rawValue) \($0.foot.x) \($0.foot.y)" }).mapValues { $0.map(\.id) }
        for (k, v) in groups.sorted(by: { $0.key < $1.key }) { print("L", k, v) }
    }
    if args.contains("--groups") {
        let groups = Dictionary(grouping: result.sim.lemmings.filter(\.isActive), by: { "\($0.action.rawValue) \($0.foot.x) \($0.foot.y) \($0.direction.rawValue)" }).mapValues { $0.map(\.id) }
        for (k, v) in groups.sorted(by: { $0.key < $1.key }) { print("G", k, v) }
    }
    if let out = option("--out"), result.sim.didWin {
        let events = result.events
        let outcome = ClassicDOSReplayOutcome(ticks: result.sim.tickCount, released: result.sim.releasedCount, saved: result.sim.savedCount, required: c.requiredToSave, didWin: true, stateHash: ClassicDOSReplayRecorder.stateHash(of: result.sim))
        let replay = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: entry.level.title.trimmingCharacters(in: .whitespaces), initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: events, expected: outcome)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(replay).write(to: URL(fileURLWithPath: out))
        print("WROTE", out)
    }
case "beam":
    let steps = try JSONDecoder().decode([Step].self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
    let trail = Int(option("--id") ?? "0")!
    let targets = option("--target")!.split(separator: ";").map { pair -> (Int, Int) in let v = pair.split(separator: ",").map { Int($0)! }; return (v[0], v[1]) }
    let skills = (option("--skills") ?? "builder").split(separator: ",").map { ClassicSkill(rawValue: String($0))! }
    let node = runBeam(base: base, steps: steps, trail: trail, targets: targets, skills: skills,
        width: Int(option("--width") ?? "60")!, stride: Int(option("--stride") ?? "4")!, maxAssigns: Int(option("--maxassign") ?? "8")!,
        until: Int(option("--until") ?? "4000")!, requireAll: args.contains("--requireall"))
    if let node {
        // Emit the trail assignments as an exact plan to be finished with run.
        let trailEvents = node.events.filter { if case let .assign(id, _) = $0.action { return id == trail } else { return false } }
        var planOut: [[String: Any]] = []
        for e in trailEvents { if case let .assign(id, sk) = e.action { planOut.append(["skill": sk.rawValue, "id": id, "tick": e.tick, "exactTick": true, "async": true]) } }
        print("BEAM tick \(node.sim.tickCount) trail \(node.sim.lemmings.count > trail ? node.sim.lemmings[trail].outcome.rawValue : "none") saved \(node.sim.savedCount) lost \(node.sim.lostCount)")
        let data = try JSONSerialization.data(withJSONObject: planOut)
        print("TRAIL " + String(data: data, encoding: .utf8)!)
    }
case "sweep":
    // Each line of the file is one plan. Prints one result line per plan.
    let lines = try String(contentsOfFile: args[4], encoding: .utf8).split(separator: "\n")
    var best = -1
    for (n, line) in lines.enumerated() {
        let steps = try JSONDecoder().decode([Step].self, from: Data(line.utf8))
        let r = runPlan(steps, base: base, verbose: false)
        if args.contains("--all") || r.sim.savedCount > best || r.sim.didWin {
            best = max(best, r.sim.savedCount)
            print(n, summary(r, steps))
        }
        if r.sim.didWin && args.contains("--first") { print("PLAN", line); break }
    }
case "transplant":
    // transplant DATA LEVEL OLD_REPLAY [--out FILE]
    // Moves a route found under the original rules to the level's own rules.
    // The old route runs under the original rules with every command applied
    // after its tick. Each assignment records where its lemming stood. The new
    // run gives the same skill to the lemming with the same hatch and release
    // position once it stands in the same place, trying small offsets.
    let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
    let (oldBase, _, _) = try content.load(index, mechanics: .original)
    struct Target { var tick: Int; var action: ClassicDOSReplayAction; var lemming: ClassicDOSLemming? }
    // Legacy rate and nuke commands apply before their tick, so they move to
    // the end of the previous tick. Legacy assignments apply within their tick.
    let byTick = Dictionary(grouping: replay.events.sorted { $0.tick < $1.tick }, by: { event -> Int in
        if event.afterTick != true, case .assign = event.action { return event.tick }
        return event.afterTick == true ? event.tick : event.tick - 1
    })
    var old = oldBase, targets: [Target] = []
    while !old.isComplete && old.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        _ = old.tick()
        for event in byTick[old.tickCount] ?? [] {
            switch event.action {
            case let .assign(id, skill):
                let before = old.lemmings.first { $0.id == id }
                guard old.assign(skill, to: id) == .assigned else { print("OLD refused", old.tickCount, id, skill.rawValue); continue }
                targets.append(Target(tick: old.tickCount, action: event.action, lemming: before))
            case let .releaseRate(value): old.setReleaseRate(value); targets.append(Target(tick: old.tickCount, action: event.action))
            case .nuke: old.beginNuke(); targets.append(Target(tick: old.tickCount, action: event.action))
            }
        }
    }
    print("OLD live conversion saved \(old.savedCount)/\(c.requiredToSave) win \(old.didWin) (fixture saved \(replay.expected?.saved ?? -1))")

    // A lemming's hatch and its release order within that hatch identify it
    // across the two release tables.
    let oldTable = ClassicDOSRules.hatchOrder(entranceCount: c.entrances.count, mechanics: .original)
    let newTable = ClassicDOSRules.hatchOrder(entranceCount: c.entrances.count, mechanics: c.mechanics)
    func key(_ id: Int, _ table: [Int]) -> (Int, Int) { (table[id % 4], (0..<id).filter { table[$0 % 4] == table[id % 4] }.count) }
    let idMap: [Int] = (0..<max(c.totalLemmings, 1)).map { id in
        let k = key(id, oldTable)
        return (0..<c.totalLemmings).first { key($0, newTable) == k } ?? id
    }
    func newID(_ id: Int) -> Int { idMap.indices.contains(id) ? idMap[id] : id }

    // Offsets tried for each assignment, nearest first. Three further modes
    // follow: any lemming at the spot, the matching lemming at the old tick,
    // and the old lemming number at the spot.
    let offsets: [(Int, Int)] = [(0, 0), (1, 0), (-1, 0), (0, -1), (0, 1), (2, 0), (-2, 0), (1, -1), (1, 1), (-1, 1), (-1, -1)]
    let modes = offsets.count + 3
    let early = Int(option("--early") ?? "120")!, late = Int(option("--late") ?? "200")!
    func attempt(_ choice: [Int], limit: Int? = nil) -> (sim: ClassicDOSSimulation, events: [ClassicDOSReplayEvent], applied: Int) {
        var sim = base, events: [ClassicDOSReplayEvent] = [], next = 0
        let end = limit ?? ClassicDOSReplayPlayer.defaultTickLimit
        while !sim.isComplete && sim.tickCount < end {
            _ = sim.tick()
            while next < targets.count {
                let t = targets[next]
                // Give up on a step that has not matched long after its old tick.
                if sim.tickCount > t.tick + late { return (sim, events, next) }
                switch t.action {
                case let .releaseRate(value):
                    guard sim.tickCount >= t.tick else { break }
                    sim.setReleaseRate(value); events.append(.init(tick: sim.tickCount, action: t.action, afterTick: true)); next += 1; continue
                case .nuke:
                    guard sim.tickCount >= t.tick else { break }
                    sim.beginNuke(); events.append(.init(tick: sim.tickCount, action: t.action, afterTick: true)); next += 1; continue
                case let .assign(id, skill):
                    guard let at = t.lemming, sim.tickCount >= t.tick - early else { break }
                    let mode = next < choice.count ? choice[next] : 0
                    func here(_ lem: ClassicDOSLemming, _ dx: Int = 0, _ dy: Int = 0) -> Bool {
                        lem.isActive && lem.foot.x == at.foot.x + dx && lem.foot.y == at.foot.y + dy
                            && lem.direction == at.direction && lem.action == at.action
                    }
                    var pick: Int?
                    switch mode {
                    case ..<offsets.count:
                        let (dx, dy) = offsets[mode]
                        pick = sim.lemmings.first { $0.id == newID(id) && here($0, dx, dy) }?.id
                    case offsets.count:
                        pick = sim.lemmings.first { here($0) || here($0, 1) }?.id
                    case offsets.count + 1:
                        pick = sim.tickCount == t.tick ? newID(id) : nil
                    default:
                        pick = sim.lemmings.first { $0.id == id && (here($0) || here($0, 1)) }?.id
                    }
                    if let pick, sim.assign(skill, to: pick) == .assigned {
                        events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: pick, skill: skill), afterTick: true))
                        next += 1
                    }
                }
                break
            }
        }
        return (sim, events, next)
    }
    // Greedy: settle each step on the first offset that lets the run apply it
    // and keeps the later steps applicable for longest.
    var choice: [Int] = []
    for step in 0..<targets.count {
        var best = (score: -1, offset: 0)
        for o in 0..<modes {
            let trial = attempt(choice + [o])
            let score = trial.applied * 1000 + trial.sim.savedCount
            if trial.applied > step && score > best.score { best = (score, o) }
            if trial.sim.didWin { best = (Int.max, o); break }
        }
        choice.append(best.offset)
        if best.score == Int.max { break }
    }
    let final = attempt(choice)
    print("NEW applied \(final.applied)/\(targets.count) saved \(final.sim.savedCount)/\(c.requiredToSave) lost \(final.sim.lostCount) tick \(final.sim.tickCount) win \(final.sim.didWin)")
    if let planFile = option("--plan") {
        // Exact-tick steps for further work with `run`.
        var steps: [[String: Any]] = []
        for e in final.events {
            switch e.action {
            case let .assign(id, skill): steps.append(["skill": skill.rawValue, "id": id, "tick": e.tick, "exactTick": true, "async": true])
            case let .releaseRate(v): steps.append(["rate": v, "tick": e.tick, "async": true])
            case .nuke: steps.append(["nuke": true, "tick": e.tick])
            }
        }
        try JSONSerialization.data(withJSONObject: steps).write(to: URL(fileURLWithPath: planFile))
    }
    if let out = option("--out"), final.sim.didWin {
        let outcome = ClassicDOSReplayOutcome(ticks: final.sim.tickCount, released: final.sim.releasedCount, saved: final.sim.savedCount, required: c.requiredToSave, didWin: true, stateHash: ClassicDOSReplayRecorder.stateHash(of: final.sim))
        let moved = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: entry.level.title.trimmingCharacters(in: .whitespaces), initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: final.events, expected: outcome)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(moved).write(to: URL(fileURLWithPath: out))
        print("WROTE", out)
    }
case "climb":
    // climb DATA LEVEL PLAN [--iters N] [--seed S] [--out FILE] [--plan FILE]
    // Local search from a partial plan. Each assignment becomes "at tick T,
    // the nearest lemming to (x, y) facing d". Random nudges to ticks and
    // points are kept when the rescue count does not fall.
    struct Move { var tick: Int; var skill: ClassicSkill?; var x = 0; var y = 0; var dir = 0; var rate: Int?; var nuke = false }
    let steps = try JSONDecoder().decode([Step].self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
    // Resolve the starting plan into moves by running it once.
    let first = runPlan(steps, base: base, verbose: false, stopLoss: false)
    var moves: [Move] = []
    do {
        var sim = base, cursor = 0
        let events = first.events
        while cursor < events.count && !sim.isComplete {
            _ = sim.tick()
            while cursor < events.count && events[cursor].tick == sim.tickCount {
                let e = events[cursor]; cursor += 1
                switch e.action {
                case let .assign(id, skill):
                    if let l = sim.lemmings.first(where: { $0.id == id }) {
                        moves.append(Move(tick: e.tick, skill: skill, x: l.foot.x, y: l.foot.y, dir: l.direction.rawValue))
                    }
                    _ = sim.assign(skill, to: id)
                case let .releaseRate(v): moves.append(Move(tick: e.tick, rate: v)); sim.setReleaseRate(v)
                case .nuke: moves.append(Move(tick: e.tick, nuke: true)); sim.beginNuke()
                }
            }
        }
    }
    func play(_ moves: [Move]) -> (sim: ClassicDOSSimulation, events: [ClassicDOSReplayEvent], hits: Int) {
        var sim = base, events: [ClassicDOSReplayEvent] = [], hits = 0
        let byTick = Dictionary(grouping: moves, by: \.tick)
        while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
            _ = sim.tick()
            for m in byTick[sim.tickCount] ?? [] {
                if let r = m.rate { sim.setReleaseRate(r); events.append(.init(tick: sim.tickCount, action: .releaseRate(r), afterTick: true)); continue }
                if m.nuke { sim.beginNuke(); events.append(.init(tick: sim.tickCount, action: .nuke, afterTick: true)); continue }
                guard let skill = m.skill else { continue }
                let near = sim.lemmings.filter { $0.isActive && abs($0.foot.x - m.x) <= 12 && abs($0.foot.y - m.y) <= 12 }
                    .sorted { (abs($0.foot.x - m.x) + abs($0.foot.y - m.y) + ($0.direction.rawValue == m.dir ? 0 : 20))
                            < (abs($1.foot.x - m.x) + abs($1.foot.y - m.y) + ($1.direction.rawValue == m.dir ? 0 : 20)) }
                for l in near where sim.assign(skill, to: l.id) == .assigned {
                    events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: l.id, skill: skill), afterTick: true)); hits += 1; break
                }
            }
        }
        return (sim, events, hits)
    }
    func score(_ r: (sim: ClassicDOSSimulation, events: [ClassicDOSReplayEvent], hits: Int)) -> Int {
        (r.sim.didWin ? 1_000_000 : 0) + r.sim.savedCount * 1000 + r.hits * 10 - r.sim.tickCount / 1000
    }
    var rng = SystemRandomNumberGenerator()
    var seed = UInt64(option("--seed") ?? "") ?? rng.next()
    func rand(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(max(1, n))) }
    var current = moves, best = play(current), bestScore = score(best)
    print("START moves \(moves.count) saved \(best.sim.savedCount)/\(c.requiredToSave) win \(best.sim.didWin)")
    let iterations = Int(option("--iters") ?? "3000")!
    var iteration = 0
    while iteration < iterations && !best.sim.didWin {
        iteration += 1
        var trial = current
        let changes = 1 + rand(3)
        for _ in 0..<changes where !trial.isEmpty {
            let i = rand(trial.count)
            switch rand(10) {
            case 0...4: trial[i].tick = max(1, trial[i].tick + rand(41) - 20)
            case 5...6: trial[i].x += rand(9) - 4
            case 7: trial[i].y += rand(7) - 3
            case 8: trial[i].tick = max(1, trial[i].tick + rand(5) - 2)
            default: if trial[i].skill != nil { trial[i].dir = -trial[i].dir }
            }
        }
        let r = play(trial), s = score(r)
        if s >= bestScore {
            if s > bestScore { print("ITER \(iteration) saved \(r.sim.savedCount)/\(c.requiredToSave) lost \(r.sim.lostCount) win \(r.sim.didWin)") }
            current = trial; best = r; bestScore = s
        }
    }
    print("CLIMB saved \(best.sim.savedCount)/\(c.requiredToSave) lost \(best.sim.lostCount) tick \(best.sim.tickCount) win \(best.sim.didWin) after \(iteration)")
    if let planFile = option("--plan") {
        var out: [[String: Any]] = []
        for e in best.events {
            switch e.action {
            case let .assign(id, skill): out.append(["skill": skill.rawValue, "id": id, "tick": e.tick, "exactTick": true, "async": true])
            case let .releaseRate(v): out.append(["rate": v, "tick": e.tick, "async": true])
            case .nuke: out.append(["nuke": true, "tick": e.tick])
            }
        }
        try JSONSerialization.data(withJSONObject: out).write(to: URL(fileURLWithPath: planFile))
    }
    if let out = option("--out"), best.sim.didWin {
        let outcome = ClassicDOSReplayOutcome(ticks: best.sim.tickCount, released: best.sim.releasedCount, saved: best.sim.savedCount, required: c.requiredToSave, didWin: true, stateHash: ClassicDOSReplayRecorder.stateHash(of: best.sim))
        let replay = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: entry.level.title.trimmingCharacters(in: .whitespaces), initialStateHash: ClassicDOSReplayRecorder.stateHash(of: base), events: best.events, expected: outcome)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(replay).write(to: URL(fileURLWithPath: out))
        print("WROTE", out)
    }
case "steelmap":
    // steelmap DATA LEVEL x1 x2 y1 y2: '#' steel, 'o' solid, '.' empty
    let x1 = Int(args[4])!, x2 = Int(args[5])!, y1 = Int(args[6])!, y2 = Int(args[7])!
    for y in y1...y2 {
        var row = String(format: "%3d ", y)
        for x in x1...x2 { row += base.terrain.isSteelProtected(x: x, y: y) ? (base.terrain.isSolid(x: x, y: y) ? "#" : "+") : (base.terrain.isSolid(x: x, y: y) ? "o" : ".") }
        print(row)
    }
case "columns":
    // columns DATA LEVEL x1 x2 [y0]: first solid y at or below y0 for each x, plus steel flag
    let x1 = Int(args[4])!, x2 = Int(args[5])!, y0 = args.count > 6 ? Int(args[6])! : 0
    var out: [String] = []
    for x in x1...x2 {
        var y = y0
        while y < base.terrain.height && !base.terrain.isSolid(x: x, y: y) { y += 1 }
        out.append("\(x):\(y)\(y < base.terrain.height && base.terrain.isSteelProtected(x: x, y: y) ? "s" : "")")
    }
    print(out.joined(separator: " "))
default:
    throw Failure(description: "unknown command")
}
