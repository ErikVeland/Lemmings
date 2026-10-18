import Foundation
import NxlvKit

// solver <level number>... | missing [--budget SECONDS] [--beam N] [--population N] [--tool-site-cell PIXELS]
//        [--paired-actors] [--seed FILE --seed-through TICK [--refresh-engine-seed]] [--promote]
// Searches Lemmings 3 levels with the selected population. A route counts only after two replays agree.
let arguments = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
var limits = L3Limits()
if let value = option("--budget").flatMap(Double.init) { limits.budgetSeconds = value }
if let value = option("--beam").flatMap(Int.init) { limits.beamWidth = value }
if let value = option("--depth").flatMap(Int.init) { limits.maxDepth = value }
if arguments.contains("--tool-site-cell") {
    guard let value = option("--tool-site-cell").flatMap(Int.init), value > 0 else {
        fputs("--tool-site-cell requires a positive pixel count\n", stderr)
        exit(2)
    }
    limits.toolSiteCell = value
}
limits.pairedActors = arguments.contains("--paired-actors")
let population: Int
if arguments.contains("--population") {
    guard let value = option("--population").flatMap(Int.init), (1...1000).contains(value) else {
        fputs("--population requires an integer from 1 to 1000\n", stderr)
        exit(2)
    }
    population = value
} else {
    population = 20
}
let promoting = arguments.contains("--promote")
if promoting && population != 20 {
    fputs("--promote requires population 20; save carried-population routes as candidates\n", stderr)
    exit(2)
}
fewerInputsFirst = arguments.contains("--fewer-inputs-first")
let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L3_PORTS_ROOT"] ?? "Sources/Ports/LEM3CD")
let fixtures = URL(fileURLWithPath: "Tests/Lemmings3CompletionTests/Fixtures")
let seedSuffix = arguments.contains("--seed") ? "-seeded" : ""
let defaultOut = population == 20 ? ".build/l3-solver/candidates\(seedSuffix)" : ".build/l3-solver/candidates-pop\(population)\(seedSuffix)"
let out = URL(fileURLWithPath: option("--out") ?? defaultOut)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let valuedOptions: Set<String> = ["--budget", "--beam", "--depth", "--population", "--tool-site-cell", "--out", "--seed", "--seed-through"]
var requested: Set<Int> = []
var skipOptionValue = false
for argument in arguments {
    if skipOptionValue { skipOptionValue = false; continue }
    if valuedOptions.contains(argument) { skipOptionValue = true; continue }
    if let level = Int(argument) { requested.insert(level) }
}
let missingOnly = arguments.contains("missing")
let hasSeed = arguments.contains("--seed")
let hasSeedThrough = arguments.contains("--seed-through")
let refreshEngineSeed = arguments.contains("--refresh-engine-seed")
let seed: L3Seed?
let seedThrough: Int?
if hasSeed || hasSeedThrough || refreshEngineSeed {
    guard hasSeed, hasSeedThrough, requested.count == 1, !missingOnly,
          let path = option("--seed"), !path.hasPrefix("--"),
          let tick = option("--seed-through").flatMap(Int.init), (0..<limits.maxTicks).contains(tick) else {
        fputs("--seed FILE and --seed-through TICK require one level and a valid checkpoint tick\n", stderr)
        exit(2)
    }
    do {
        seed = try JSONDecoder().decode(L3Seed.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    } catch {
        fputs("--seed could not be read: \(error)\n", stderr)
        exit(2)
    }
    seedThrough = tick
} else {
    seed = nil
    seedThrough = nil
}

var failed = false
for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
    let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
    let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
    for (index, level) in campaign.levels.enumerated() {
        let number = tribe.firstLevel + index
        let file = fixtures.appendingPathComponent(String(format: "%03d.json", number))
        let existing = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(L3Replay.self, from: $0) }
        guard requested.contains(number) || (missingOnly && existing == nil) else { continue }
        requested.remove(number)
        let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let base = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: population)
        let retainedRouteWins: Bool
        if let existing, let first = try? existing.replay(from: base, levelData: level.rawData),
           let second = try? existing.replay(from: base, levelData: level.rawData) {
            retainedRouteWins = first.isComplete && first.saved > 0 &&
                L3Replay.stateHash(first) == L3Replay.stateHash(second)
        } else {
            retainedRouteWins = false
        }
        if promoting && retainedRouteWins {
            print(String(format: "KEPT MVP %03d: retained route wins", number))
            fflush(stdout)
            continue
        }
        let seeded: L3Candidate?
        if let seed, let seedThrough {
            do {
                seeded = try l3SeedCandidate(from: base, levelNumber: number,
                    levelData: level.rawData, seed: seed, throughTick: seedThrough, limits: limits,
                    refreshEngine: refreshEngineSeed)
            } catch {
                fputs("--seed rejected for level \(number): \(error)\n", stderr)
                exit(2)
            }
        } else {
            seeded = nil
        }
        // The depth follows the level: decision points on a run without input, plus 40. A search that
        // ends before its budget runs again with a wider beam, as the Lemmings 2 solver does.
        let started = Date()
        let deadline = started.addingTimeInterval(limits.budgetSeconds)
        var passive = seeded ?? L3Candidate(game: base, detector: L3Detector(cell: limits.cell, refire: limits.refire,
                                                                           toolSiteCell: limits.toolSiteCell))
        var points = 0
        while l3Advance(&passive, limits: limits, deadline: deadline) { points += 1 }
        var run = limits
        if option("--depth") == nil { run.maxDepth = points + 40 }
        var report = L3Report()
        var rounds = 0
        while Date() < deadline {
            rounds += 1
            run.budgetSeconds = deadline.timeIntervalSinceNow
            guard run.budgetSeconds > 0 else { break }
            let attempt = l3Search(from: base, limits: run, seed: seeded, deadline: deadline)
            report.expanded += attempt.expanded
            if report.best == nil { report.best = attempt.best }
            if report.bestPartial == nil || (attempt.bestPartial?.game.saved ?? 0) > (report.bestPartial?.game.saved ?? 0) { report.bestPartial = attempt.bestPartial }
            if report.best != nil || attempt.seconds >= run.budgetSeconds || run.beamWidth >= 4096 { break }
            run.beamWidth *= 2
        }
        report.seconds = Date().timeIntervalSince(started)
        let seedSummary = seedThrough.map { "seed through \($0), " } ?? ""
        let summary = "\(seedSummary)decision points \(points), depth \(run.maxDepth), \(rounds) rounds to beam \(run.beamWidth), expanded \(report.expanded), \(Int(report.seconds)) s"
        guard let best = report.best else {
            let partial = report.bestPartial?.game
            print(String(format: "UNSOLVED %03d: best saved %d, lost %d; ", number, partial?.saved ?? 0, partial?.lost ?? 0) + summary)
            fflush(stdout)
            continue
        }
        let replay = L3Replay(level: number, levelSHA256: L3Replay.digest(level.rawData), population: population,
            initialStateHash: L3Replay.stateHash(base), inputs: best.inputs, expected: .init(best.game))
        do {
            let first = try replay.replay(from: base, levelData: level.rawData)
            let second = try replay.replay(from: base, levelData: level.rawData)
            guard L3Replay.stateHash(first) == L3Replay.stateHash(second) else {
                throw SequelDataError.invalid("two replays disagree")
            }
        } catch {
            print(String(format: "ERROR %03d: ", number) + "\(error)")
            failed = true
            continue
        }
        try encoder.encode(replay).write(to: out.appendingPathComponent(String(format: "%03d.json", number)), options: .atomic)
        let game = best.game
        var line = String(format: "SOLVED %03d: saved %d, lost %d, reserve %d, %d ticks, %d inputs; ", number, game.saved,
                          game.lost, game.reserve, game.tick, best.inputs.count) + summary
        if promoting {
            if !retainedRouteWins {
                try encoder.encode(replay).write(to: file, options: .atomic)
                line += existing == nil ? "; PROMOTED MVP fixture" : "; PROMOTED MVP replacement for invalid route"
            } else {
                line += "; KEPT verified MVP fixture"
            }
        }
        print(line)
        fflush(stdout)
    }
}
exit(failed ? 1 : 0)
