import Foundation
import NxlvKit

// Adapt existing inputs to the actual survivor count, then verify each variant twice.
// Standalone witnesses are preserved. Failed adaptations stop that tribe's chain.
let args = CommandLine.arguments
let root = URL(fileURLWithPath: args.count > 1 ? args[1] : "Sources/Ports/Lemm2")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
let fixtures = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures")
let output = URL(fileURLWithPath: args.count > 2 ? args[2] : ".build/l2-chain-candidates")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for tribe in 0..<12 {
  let name = tribe == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[tribe].lowercased()
  var population = 60
  for number in 1...10 {
    let file = String(format: "%@-%02d.json", name, number)
    guard let data = try? Data(contentsOf: fixtures.appendingPathComponent(file)) else {
      print("MISSING", file)
      break
    }
    var fields = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data)
    let level = campaign.levels.first { $0.fingerprint == witness.levelSHA256 }!
    let style = try Lemmings2Style(
      data: Data(
        contentsOf: root.appendingPathComponent(
          "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    if population == witness.population {
      let result = try witness.run(level: level, style: style, masks: masks)
      print("EXISTING", file, population, "->", result.saved)
      population = result.saved
      continue
    }
    var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
    let pointers = witness.pointers ?? []
    var command = 0
    var pointer = 0
    var rejected = false
    while !game.isComplete && game.tick <= max(12000, witness.expectedTicks) {
      while pointer < pointers.count && pointers[pointer].tick == game.tick {
        let p = pointers[pointer]
        game.setAim(x: p.fan ? p.fanX : p.x, y: p.fan ? p.fanY : p.y, held: !p.fan)
        game.setFan(x: p.fanX, y: p.fanY, active: p.fan)
        pointer += 1
      }
      while command < witness.inputs.count && witness.inputs[command].tick == game.tick {
        let event = witness.inputs[command]
        guard let slot = game.configuration.skills.firstIndex(where: { $0.rawValue == event.skill })
        else {
          rejected = true
          break
        }
        game.setFan(x: 0, y: 0, active: false)
        if !game.assign(slot: slot, to: event.lemming) {
          rejected = true
          break
        }
        if pointer > 0, pointers[pointer - 1].fan {
          let p = pointers[pointer - 1]
          game.setFan(x: p.fanX, y: p.fanY, active: true)
        }
        command += 1
      }
      if rejected { break }
      game.step()
    }
    guard !rejected, game.didWin, game.isComplete else {
      print("ADAPT FAILED", file, population, game.saved, game.tick, "rejected", rejected)
      break
    }
    fields["population"] = population
    fields["expectedSaved"] = game.saved
    fields["expectedTicks"] = game.tick
    fields["inputs"] = Array((fields["inputs"] as! [[String: Any]]).prefix(command))
    fields["pointers"] = Array((fields["pointers"] as? [[String: Any]] ?? []).prefix(pointer))
    let candidate = try JSONSerialization.data(
      withJSONObject: fields, options: [.sortedKeys, .prettyPrinted])
    let checked = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: candidate)
    let first = try checked.run(level: level, style: style, masks: masks)
    let second = try checked.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash else { fatalError("Replay differs") }
    try candidate.write(to: output.appendingPathComponent(file))
    print("ADAPTED", file, population, "->", first.saved)
    fflush(stdout)
    population = first.saved
  }
}
