import Foundation
import NxlvKit

let root = URL(fileURLWithPath: "Sources/Ports/LEM3CD")
let campaign = try Lemmings3ClassicCampaign(root: root, tribe: .classic)
let level = campaign.levels[2]
let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 1)
let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
let base = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary, total: 20)
let fixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/003.json")))
let seed = L3GuideSeed(version: fixture.version, level: fixture.level, levelSHA256: fixture.levelSHA256,
                       population: fixture.population, initialStateHash: fixture.initialStateHash, inputs: fixture.inputs)
let result = try L3GuideTrace.replay(seed: seed, from: base, levelData: level.rawData,
                                     throughTick: fixture.expected.ticks)
guard result.entries.count == fixture.inputs.count,
      result.entries.allSatisfy(\.accepted),
      result.final.complete,
      result.final.saved == fixture.expected.saved,
      result.final.lost == fixture.expected.lost,
      result.final.reserve == fixture.expected.reserves,
      result.final.stateHash == fixture.expected.stateHash else {
    fatalError("L3 guide trace did not reproduce the checked Classic 03 replay.")
}
print("L3 guide trace tests passed")
