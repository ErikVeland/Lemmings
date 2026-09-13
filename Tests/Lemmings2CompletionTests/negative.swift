import Foundation
import NxlvKit

// Damages one field of a known-good route at a time and requires the shared
// witness to reject it. A case that the gate accepts is a hole in the gate.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Ports/Lemm2")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
let good = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures/beach-01.json")
let base = try JSONSerialization.jsonObject(with: Data(contentsOf: good)) as! [String: Any]
let level = campaign.levels.first { $0.fingerprint == base["levelSHA256"] as! String }!
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
    "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))

var accepted: [String] = []

@MainActor func run(_ fields: [String: Any]) throws -> Lemmings2WitnessOutcome {
    let data = try JSONSerialization.data(withJSONObject: fields)
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data)
    return try witness.run(level: level, style: style, masks: masks)
}

@MainActor func expectFailure(_ label: String, _ change: (inout [String: Any]) -> Void) {
    var damaged = base
    change(&damaged)
    if (try? run(damaged)) != nil {
        print("FAIL \(label): the gate accepted damaged evidence")
        accepted.append(label)
    } else {
        print("PASS \(label) rejected")
    }
}

// The undamaged route must pass, or every rejection below proves nothing.
guard (try? run(base)) != nil else { print("FAIL the undamaged base route does not pass"); exit(1) }
print("PASS undamaged base route accepted")

expectFailure("changed starting population") { $0["population"] = ($0["population"] as! Int) - 1 }
expectFailure("changed level hash") { $0["levelSHA256"] = String(repeating: "0", count: 64) }
expectFailure("changed saved count") { $0["expectedSaved"] = ($0["expectedSaved"] as! Int) + 1 }
expectFailure("changed tick count") { $0["expectedTicks"] = ($0["expectedTicks"] as! Int) + 1 }
expectFailure("rejected input") {
    var inputs = $0["inputs"] as! [[String: Any]]
    inputs[0]["skill"] = 999
    $0["inputs"] = inputs
}
expectFailure("out-of-order inputs") {
    var inputs = $0["inputs"] as! [[String: Any]]
    inputs.reverse()
    $0["inputs"] = inputs
}
expectFailure("pointer outside the viewport") {
    $0["pointers"] = [["tick": 0, "x": -9999, "y": -9999, "fanX": -9999, "fanY": -9999, "fan": false]]
}

if accepted.isEmpty {
    print("PASS seven damaged Lemmings 2 routes rejected")
} else {
    print("GATE HOLE: accepted \(accepted.count): \(accepted.joined(separator: ", "))")
    exit(1)
}
