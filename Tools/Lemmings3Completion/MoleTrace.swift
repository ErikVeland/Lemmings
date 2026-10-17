import Foundation
import NxlvKit

struct MoleSample: Encodable {
    let tick: Int
    let x: Int
    let y: Int
    let direction: Int
    let digDirection: String
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: MoleTrace <L3 resource root>\n", stderr)
    exit(2)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let campaign = try Lemmings3ClassicCampaign(root: root, tribe: .shadow)
let level = campaign.levels[0]
let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 2)
let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
var game = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
    temporary: temporary, total: 22)
var samples: [MoleSample] = []
for _ in 0..<349 {
    game.step()
    guard game.tick >= 2, let mole = game.creatures.first(where: { $0.kind == .mole }) else { continue }
    samples.append(.init(tick: game.tick, x: mole.x, y: mole.y,
        direction: mole.direction, digDirection: mole.digDirection.rawValue))
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(samples))
