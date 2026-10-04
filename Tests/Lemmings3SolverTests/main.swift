import Foundation
import NxlvKit

let root = URL(fileURLWithPath: "Sources/Ports/LEM3CD")
let campaign = try Lemmings3ClassicCampaign(root: root, tribe: .shadow)
let level = campaign.levels[7]
let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 2)
let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
var game = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary, total: 20)
let fixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/108.json")))
guard fixture.levelSHA256 == L3Replay.digest(level.rawData),
      fixture.initialStateHash == L3Replay.stateHash(game) else {
    fatalError("Shadow 08 fixture does not match the exact source level")
}
var cursor = 0
var detector = L3Detector()
_ = detector.update(game)
var offeredAtTurn: [Int] = []
while game.tick < 560 {
    while cursor < fixture.inputs.count && fixture.inputs[cursor].tick == game.tick {
        guard L3Replay.apply(fixture.inputs[cursor], to: &game) else { fatalError("Shadow 08 prefix failed") }
        cursor += 1
    }
    game.step()
    let offered = detector.update(game)
    if game.tick == 560 { offeredAtTurn = offered ?? [] }
}
guard offeredAtTurn.contains(8) else { fatalError("Solver did not revisit the builder at its work step") }
guard let before = game.lemmings.first(where: { $0.id == 8 }), before.state == .building else {
    fatalError("Shadow 08 no longer reaches its measured builder decision")
}
let pair = l3Actions(game, lemming: 8).first { $0.count == 2 && $0.allSatisfy { $0.action == "walker" } }
guard let pair else { fatalError("Solver omitted the measured two-Walker branch") }
for input in pair where !L3Replay.apply(input, to: &game) { fatalError("Two-Walker branch was rejected") }
guard let after = game.lemmings.first(where: { $0.id == 8 }),
      after.state == .walking, after.direction == -before.direction,
      !l3Actions(game, lemming: 8).contains(where: { $0.count == 2 }) else {
    fatalError("Two-Walker branch did not stop and turn the builder")
}
print("PASS L3 solver offers the retained Shadow 08 same-tick builder turn")
