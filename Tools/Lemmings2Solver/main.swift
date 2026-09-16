import Foundation
import NxlvKit

// solver level <data-root> <tribe-NN> [--seed FILE] [--population N] [--promote] [search options]
// solver tribe <data-root> <tribe> [--seeds DIR] [--promote] [search options]
// Search options: [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
let usage = """
usage: solver level <data-root> <tribe-NN> [--seed FILE] [--population N] [--promote] [search options]
       solver tribe <data-root> <tribe> [--seeds DIR] [--promote] [search options]
       solver promote <data-root> <candidate.json>...
search options: [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
"""
let arguments = Array(CommandLine.arguments.dropFirst())

@MainActor func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

guard arguments.count >= 3, ["level", "tribe", "promote"].contains(arguments[0]) else {
    print(usage)
    exit(1)
}
let root = URL(fileURLWithPath: arguments[1])
var limits = SearchLimits()
if let value = option("--beam").flatMap(Int.init) { limits.beamWidth = value }
if let value = option("--budget").flatMap(Double.init) { limits.budgetSeconds = value }
if let value = option("--cell").flatMap(Int.init) { limits.cell = value }
if let value = option("--refire").flatMap(Int.init) { limits.refire = value }
let out = URL(fileURLWithPath: option("--out") ?? ".build/l2-solver/candidates")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)

func levelName(_ index: Int, _ level: Lemmings2Level) -> String {
    let tribe = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
    return String(format: "\(tribe)-%02d", index % 10 + 1)
}

func style(for level: Lemmings2Level) throws -> Lemmings2Style {
    try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

let promoting = arguments.contains("--promote")
let fixtures = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures")
let chains = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Chains")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func report(_ name: String, _ route: Lemmings2ReplayWitness, chosenByChain: Bool = false) throws {
    try encoder.encode(route).write(to: out.appendingPathComponent(name + ".json"))
    guard promoting else { return }
    switch try promote(route, name: name, fixtures: fixtures, chains: chains, chosenByChain: chosenByChain) {
    case .fixture: print("PROMOTED \(name) fixture: saved \(route.expectedSaved) of \(route.population)")
    case .chain: print("PROMOTED \(name) chain: saved \(route.expectedSaved) of \(route.population)")
    case let .kept(reason): print("KEPT \(name): \(reason)")
    }
}

func line(_ name: String, _ population: Int, _ result: LevelResult, _ note: String) -> String {
    guard let route = result.witness else {
        return "UNSOLVED \(name): best saved \(result.partial?.expectedSaved ?? 0) of \(population)\(note); \(result.summary)"
    }
    let level = campaign.levels.first { $0.fingerprint == route.levelSHA256 }!
    let medal = Lemmings2Campaign.medal(saved: route.expectedSaved, total: population, allowedLosses: level.allowedLossesForGold)
    return "SOLVED \(name): saved \(route.expectedSaved) of \(population), \(medal.name), \(route.expectedTicks) ticks, \(route.events?.count ?? 0) events\(note); \(result.summary)"
}

func writePartial(_ name: String, _ result: LevelResult) throws {
    // Keep the best partial route for inspection. It is not an accepted route.
    if let partial = result.partial {
        try encoder.encode(partial).write(to: out.appendingPathComponent(name + ".partial.json"))
    }
}

let depth = option("--depth").flatMap(Int.init)

// solver promote <data-root> <candidate.json>...: replay each candidate twice, then promote it.
if arguments[0] == "promote" {
    var failed = false
    for path in arguments.dropFirst(2) where !path.hasPrefix("--") {
        let url = URL(fileURLWithPath: path)
        let name = String(url.deletingPathExtension().lastPathComponent.prefix(while: { $0 != "." }))
        guard let route = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url)),
              let index = campaign.levels.indices.first(where: { levelName($0, campaign.levels[$0]) == name }),
              campaign.levels[index].fingerprint == route.levelSHA256 else {
            print("ERROR \(name): unreadable candidate or unknown level")
            failed = true
            continue
        }
        let level = campaign.levels[index]
        do {
            let first = try route.run(level: level, style: try style(for: level), masks: masks)
            let second = try route.run(level: level, style: try style(for: level), masks: masks)
            guard first.stateHash == second.stateHash else { throw SolverError.replayMismatch(name) }
            switch try promote(route, name: name, fixtures: fixtures, chains: chains) {
            case .fixture: print("PROMOTED \(name) fixture: saved \(route.expectedSaved) of \(route.population)")
            case .chain: print("PROMOTED \(name) chain: saved \(route.expectedSaved) of \(route.population)")
            case let .kept(reason): print("KEPT \(name): \(reason)")
            }
        } catch {
            print("ERROR \(name): \(error)")
            failed = true
        }
    }
    exit(failed ? 1 : 0)
}

if arguments[0] == "tribe" {
    let tribe = arguments[2].lowercased()
    let indices = campaign.levels.indices.filter { levelName($0, campaign.levels[$0]).hasPrefix(tribe + "-") }
    guard indices.count == 10 else {
        print("ERROR unknown tribe \(tribe)")
        exit(1)
    }
    let extra = option("--seeds").map { URL(fileURLWithPath: $0) }
    var sources: [String: String] = [:]
    let chain: ChainReport
    do {
        // --from resumes a tribe at a level, with the population the verified chain passes to it.
        let from = option("--from").flatMap(Int.init) ?? 1
        chain = try runChain(tribe: tribe, from: from, population: option("--population").flatMap(Int.init) ?? 60, seedSource: { number, population in sources["\(number)-\(population)"] ?? "" },
            solve: { number, population in
                let name = String(format: "\(tribe)-%02d", number)
                let level = campaign.levels[indices[number - 1]]
                let chosen = seed(for: name, level: level, population: population, fixtures: fixtures, chains: chains, extra: extra)
                sources["\(number)-\(population)"] = chosen.source
                let result = try solveLevel(level: level, style: try style(for: level), masks: masks, population: population,
                                            seed: chosen.events, limits: limits, depth: depth)
                if result.witness == nil { try writePartial(name, result) }
                print(line(name, population, result, "; seed \(chosen.source)"))
                return result
            },
            accept: { number, route, backtracked in
                let name = String(format: "\(tribe)-%02d", number)
                if backtracked { print("BACKTRACK \(name): saved \(route.expectedSaved) of \(route.population)") }
                try report(name, route, chosenByChain: backtracked)
            })
    } catch {
        print("ERROR \(tribe): \(error)")
        exit(1)
    }
    let tribes = out.appendingPathComponent("tribes")
    try FileManager.default.createDirectory(at: tribes, withIntermediateDirectories: true)
    try encoder.encode(chain).write(to: tribes.appendingPathComponent(tribe + ".json"))
    let reached = (option("--from").flatMap(Int.init) ?? 1) - 1 + chain.levels.filter { $0.saved != nil }.count
    print("TRIBE \(tribe): \(reached) of 10 levels chained\(chain.brokeAt.map { ", broke at level \($0)" } ?? ", ark ending \(chain.arkReady ? "reached" : "needs 30 on level 10")")")
    if promoting { print("Run python3 Tools/Lemmings2Completion/report.py and the completion gate.") }
    exit(chain.brokeAt == nil ? 0 : 2)
}

let name = arguments[2]
guard let index = campaign.levels.indices.first(where: { levelName($0, campaign.levels[$0]) == name }) else {
    print("ERROR unknown level \(name)")
    exit(1)
}
let level = campaign.levels[index]
let population = option("--population").flatMap(Int.init) ?? 60
var seedEvents: [Lemmings2TimedEvent] = []
var seedNote = ""
if let path = option("--seed") {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let route = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data),
          route.levelSHA256 == level.fingerprint else {
        print("ERROR \(name): the seed is unreadable or belongs to another level")
        exit(1)
    }
    seedEvents = route.timedEvents()
    seedNote = "; from seed saved \(route.expectedSaved) of \(route.population)"
}
do {
    let result = try solveLevel(level: level, style: try style(for: level), masks: masks, population: population,
                                seed: seedEvents, limits: limits, depth: depth)
    print(line(name, population, result, seedNote))
    guard let route = result.witness else {
        try writePartial(name, result)
        exit(2)
    }
    try report(name, route)
} catch {
    print("ERROR \(name): \(error)")
    exit(1)
}
