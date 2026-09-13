import Foundation
import NxlvKit

// The Lemmings 2 completion gate. Every recorded route is replayed twice from a
// fresh runtime through the shared witness, and both runs must agree.
let args = CommandLine.arguments.dropFirst()
let requireAll = args.contains("--require-all")
let rootPath = args.first { !$0.hasPrefix("--") } ?? "Sources/Ports/Lemm2"
let root = URL(fileURLWithPath: rootPath)
let fixtures = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L2_COMPLETION_FIXTURES"]
    ?? "Tests/Lemmings2CompletionTests/Fixtures")

func tribeName(_ style: Int) -> String {
    style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[style].lowercased()
}

let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
var verified = 0
var missing: [String] = []
for (index, level) in campaign.levels.enumerated() {
    let name = String(format: "\(tribeName(level.style))-%02d", index % 10 + 1)
    let url = fixtures.appendingPathComponent(name + ".json")
    guard FileManager.default.fileExists(atPath: url.path) else { missing.append(name); continue }
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url))
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    let first: Lemmings2WitnessOutcome, second: Lemmings2WitnessOutcome
    do {
        first = try witness.run(level: level, style: style, masks: masks)
        second = try witness.run(level: level, style: style, masks: masks)
    } catch {
        print("FAIL \(name): \(error)")
        exit(1)
    }
    guard first.stateHash == second.stateHash, first.saved == second.saved, first.ticks == second.ticks else {
        print("FAIL \(name): two runs of the route disagree")
        exit(1)
    }
    print("PASS \(name): \(first.saved)/\(witness.population) \(first.medal.name) in \(first.ticks) ticks")
    verified += 1
}
print("Verified \(verified); missing \(missing.count).")

// Population carries over: a level starts with the saved count of the level
// before it. A route only proves the population it was recorded with, so the
// chain uses equality, matching the runtime suite's carry-over check.
var fullyChained = 0
for tribe in 0..<12 {
    let name = tribeName(tribe)
    var expected = 60, chained = 0
    for number in 1...10 {
        let url = fixtures.appendingPathComponent(String(format: "\(name)-%02d.json", number))
        guard let data = try? Data(contentsOf: url),
              let route = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data),
              route.population == expected else { break }
        chained += 1
        expected = route.expectedSaved
    }
    if chained == 10 { fullyChained += 1 }
    print("CHAIN \(name): \(chained)/10 levels\(chained == 10 ? ", complete" : "")")
}
print("Tribes chained through all ten levels: \(fullyChained) of 12.")
if requireAll && !missing.isEmpty {
    print("MISSING \(missing.joined(separator: ", "))")
    exit(1)
}
