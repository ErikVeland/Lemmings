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

let chainFixtures = ProcessInfo.processInfo.environment["L2_COMPLETION_CHAINS"].map {
    URL(fileURLWithPath: $0)
} ?? fixtures.deletingLastPathComponent().appendingPathComponent("Chains")
let variantFiles = (try? FileManager.default.contentsOfDirectory(at: chainFixtures,
    includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "json" } ?? []
for url in variantFiles where !FileManager.default.fileExists(atPath: fixtures.appendingPathComponent(url.lastPathComponent).path) {
    print("FAIL orphan carry-over witness: \(url.lastPathComponent)")
    exit(1)
}
var verifiedRoutes: [String: [Lemmings2ReplayWitness]] = [:]
var variantCount = 0
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
var verified = 0
var missing: [String] = []
for (index, level) in campaign.levels.enumerated() {
    let name = String(format: "\(tribeName(level.style))-%02d", index % 10 + 1)
    let url = fixtures.appendingPathComponent(name + ".json")
    guard FileManager.default.fileExists(atPath: url.path) else { missing.append(name); continue }
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    let variant = chainFixtures.appendingPathComponent(name + ".json")
    let inputs = [url] + (FileManager.default.fileExists(atPath: variant.path) ? [variant] : [])
    for input in inputs {
        let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: input))
        guard witness.version == 1, (1...60).contains(witness.population),
              (1...witness.population).contains(witness.expectedSaved), witness.expectedTicks > 0,
              !(verifiedRoutes[name] ?? []).contains(where: { $0.population == witness.population }) else {
            print("FAIL invalid or ambiguous witness: \(input.path)")
            exit(1)
        }
        let first: Lemmings2WitnessOutcome, second: Lemmings2WitnessOutcome
        do {
            first = try witness.run(level: level, style: style, masks: masks)
            second = try witness.run(level: level, style: style, masks: masks)
        } catch {
            print("FAIL \(input.path): \(error)")
            exit(1)
        }
        guard first.stateHash == second.stateHash, first.saved == second.saved, first.ticks == second.ticks else {
            print("FAIL \(name): two runs of the route disagree")
            exit(1)
        }
        verifiedRoutes[name, default: []].append(witness)
        let carryOver = input == variant
        if carryOver { variantCount += 1 }
        print("PASS \(name)\(carryOver ? " carry-over" : ""): \(first.saved)/\(witness.population) \(first.medal.name) in \(first.ticks) ticks")
    }
    verified += 1
}
print("Verified \(verified); missing \(missing.count).")
print("Verified carry-over variants: \(variantCount).")

// Population carries over: a level starts with the saved count of the level
// before it. A route only proves the population it was recorded with, so the
// chain uses equality, matching the runtime suite's carry-over check.
var fullyChained = 0
for tribe in 0..<12 {
    let name = tribeName(tribe)
    var expected = 60, chained = 0
    for number in 1...10 {
        let key = String(format: "\(name)-%02d", number)
        guard let route = verifiedRoutes[key]?.first(where: { $0.population == expected }) else { break }
        chained += 1
        expected = route.expectedSaved
    }
    if chained == 10 { fullyChained += 1 }
    print("CHAIN \(name): \(chained)/10 levels\(chained == 10 ? ", complete" : "")")
}
print("Tribes chained through all ten levels: \(fullyChained) of 12.")
if requireAll && (!missing.isEmpty || fullyChained != 12) {
    print("MISSING \(missing.joined(separator: ", "))")
    print("Strict completion requires all twelve continuous tribe runs.")
    exit(1)
}
