import Foundation
import NxlvKit

// solve-level <data-root> <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
let arguments = Array(CommandLine.arguments.dropFirst())

@MainActor func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

guard arguments.count >= 2 else {
    print("usage: solve-level <data-root> <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]")
    exit(1)
}
let root = URL(fileURLWithPath: arguments[0])
let name = arguments[1]
let population = option("--population").flatMap(Int.init) ?? 60
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
guard let index = campaign.levels.indices.first(where: { levelName($0, campaign.levels[$0]) == name }) else {
    print("ERROR unknown level \(name)")
    exit(1)
}
let level = campaign.levels[index]
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
    "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
let start = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
// Decision density on a run without input. A dense level points to detector tuning.
var passive = Candidate(game: start, cursor: Lemmings2InputCursor(), inputs: [], pointers: [], depth: 0,
                        fingerprint: "", detector: DecisionDetector(cell: limits.cell, refire: limits.refire), decision: nil)
var passivePoints = 0
while (try? advance(&passive)) != nil { passivePoints += 1 }
let density = String(format: "%.1f", Double(passivePoints) * 100 / Double(max(1, passive.game.tick)))
// A depth of 40 decision points stopped every real-level search early. Let the search branch
// through every decision point a run without input meets, plus a margin for new terrain.
limits.maxDepth = option("--depth").flatMap(Int.init) ?? passivePoints + 40
let report = search(from: start, bounds: AimBounds(level: level), limits: limits)
let summary = "density \(density) per 100 ticks, decision points \(report.decisionPoints) (fallback \(report.fallbackPoints)), expanded \(report.expanded), \(Int(report.seconds)) s, depth \(limits.maxDepth)"

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

guard let best = report.best else {
    // Keep the best partial route for inspection. It is not an accepted route.
    if let partial = report.bestPartial.map(finish) {
        let record = Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population,
            expectedSaved: partial.game.saved, expectedTicks: partial.game.tick,
            inputs: partial.inputs, pointers: partial.pointers)
        try encoder.encode(record).write(to: out.appendingPathComponent(name + ".partial.json"))
    }
    print("UNSOLVED \(name): best saved \(report.bestPartial?.game.saved ?? 0) of \(population); \(summary)")
    exit(2)
}
let witness = Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population,
    expectedSaved: best.game.saved, expectedTicks: best.game.tick, inputs: best.inputs, pointers: best.pointers)
let file = out.appendingPathComponent(name + ".json")
try encoder.encode(witness).write(to: file)

// Accept the route only when the written file replays twice to the solver's outcome.
do {
    let written = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: file))
    let first = try written.run(level: level, style: style, masks: masks)
    let second = try written.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash, first.saved == best.game.saved, first.ticks == best.game.tick else {
        print("ERROR \(name): the written route does not replay to the solver's outcome")
        exit(1)
    }
    print("SOLVED \(name): saved \(first.saved) of \(population), \(first.medal.name), \(first.ticks) ticks, \(best.inputs.count) inputs; \(summary)")
} catch {
    print("ERROR \(name): the written route failed replay: \(error)")
    exit(1)
}
