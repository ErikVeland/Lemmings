import Foundation
import NxlvKit

func assertOfferedToolDirections(_ game: Lemmings3Runtime, lemming id: Int,
                                 tool: Lemmings3Runtime.Tool, label: String) {
    guard let lemming = game.lemmings.first(where: { $0.id == id }), lemming.tool == tool else {
        fatalError("\(label) did not reach its recorded tool holder")
    }
    let accepted = Set(Lemmings3Runtime.Direction.allCases.filter { direction in
        var trial = game
        let input = L3Replay.Input(tick: game.tick, action: "use", lemming: id, direction: direction.rawValue)
        return L3Replay.apply(input, to: &trial)
    })
    let offered = Set(l3Actions(game, lemming: id).compactMap { choice -> Lemmings3Runtime.Direction? in
        guard choice.count == 1, choice[0].action == "use", let direction = choice[0].direction else { return nil }
        return Lemmings3Runtime.Direction(rawValue: direction)
    })
    guard offered == accepted else {
        fatalError("\(label) solver directions \(offered) differ from accepted directions \(accepted)")
    }
}

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
assertOfferedToolDirections(game, lemming: 8, tool: .bricks, label: "Shadow 08 Brick builder")
let pair = l3Actions(game, lemming: 8).first { $0.count == 2 && $0.allSatisfy { $0.action == "walker" } }
guard let pair else { fatalError("Solver omitted the measured two-Walker branch") }
for input in pair where !L3Replay.apply(input, to: &game) { fatalError("Two-Walker branch was rejected") }
guard let after = game.lemmings.first(where: { $0.id == 8 }),
      after.state == .walking, after.direction == -before.direction,
      !l3Actions(game, lemming: 8).contains(where: { $0.count == 2 }) else {
    fatalError("Two-Walker branch did not stop and turn the builder")
}
let egyptian = try Lemmings3ClassicCampaign(root: root, tribe: .egyptian)
let egyptianLevel = egyptian.levels[0]
let egyptianStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 3)
let egyptianPermanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", egyptianLevel.permanentObjectsReference))))
let egyptianTemporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", egyptianLevel.temporaryObjectsReference))))
var egyptianGame = try Lemmings3Runtime(level: egyptianLevel, style: egyptianStyle,
                                        permanent: egyptianPermanent, temporary: egyptianTemporary, total: 20)
let egyptianFixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/201.json")))
guard egyptianFixture.levelSHA256 == L3Replay.digest(egyptianLevel.rawData),
      egyptianFixture.initialStateHash == L3Replay.stateHash(egyptianGame) else {
    fatalError("Egyptian 01 fixture does not match the exact source level")
}
while egyptianGame.tick < 241 { egyptianGame.step() }
assertOfferedToolDirections(egyptianGame, lemming: 0, tool: .spade, label: "Egyptian 01 Spade holder")

let classic = try Lemmings3ClassicCampaign(root: root, tribe: .classic)
let classicLevel = classic.levels[2]
let classicStyle = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 1)
let classicPermanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", classicLevel.permanentObjectsReference))))
let classicTemporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", classicLevel.temporaryObjectsReference))))
var classicGame = try Lemmings3Runtime(level: classicLevel, style: classicStyle,
                                       permanent: classicPermanent, temporary: classicTemporary, total: 20)
let classicFixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/003.json")))
guard classicFixture.levelSHA256 == L3Replay.digest(classicLevel.rawData),
      classicFixture.initialStateHash == L3Replay.stateHash(classicGame) else {
    fatalError("Classic 03 fixture does not match the exact source level")
}
var classicDetector = L3Detector(toolSiteCell: 64)
_ = classicDetector.update(classicGame)
var offeredAtDig: [Int] = []
var fallbackCoveredNoTool = false
while classicGame.tick < 227 {
    classicGame.step()
    let offered = classicDetector.update(classicGame)
    if classicGame.tick == 150 {
        fallbackCoveredNoTool = (offered ?? []).contains { id in
            classicGame.lemmings.contains { $0.id == id && $0.state == .walking && $0.tool == nil }
        }
    }
    if classicGame.tick == 227 { offeredAtDig = offered ?? [] }
}
guard offeredAtDig.contains(1),
      l3Actions(classicGame, lemming: 1).contains(where: { choice in
          choice.count == 1 && choice[0].action == "use" && choice[0].direction == "down"
      }) else {
    fatalError("Solver cannot offer the known Classic 03 Spade route at a useful site")
}
guard fallbackCoveredNoTool else {
    fatalError("Tool-site decisions suppressed the other walking actors")
}
let dig = L3Replay.Input(tick: classicGame.tick, action: "use", lemming: 1, direction: "down")
guard L3Replay.apply(dig, to: &classicGame) else { fatalError("Classic 03 Spade action was rejected") }
while !classicGame.isComplete && classicGame.tick < 30_000 { classicGame.step() }
guard classicGame.isComplete, classicGame.saved == 10,
      classicGame.lost == 1, classicGame.reserve == 9, classicGame.tick == 640 else {
    fatalError("Classic 03 offered Spade route did not retain its ten-save outcome")
}
let classic06Level = classic.levels[5]
let classic06Permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", classic06Level.permanentObjectsReference))))
let classic06Temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", classic06Level.temporaryObjectsReference))))
let classic06Base = try Lemmings3Runtime(level: classic06Level, style: classicStyle,
                                         permanent: classic06Permanent, temporary: classic06Temporary, total: 13)
let classic06Seed = try JSONDecoder().decode(L3Seed.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3SolverTests/Classic006Seed.json")))
var seedLimits = L3Limits()
seedLimits.toolSiteCell = 64
let classic06Prefix = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
    levelData: classic06Level.rawData, seed: classic06Seed, throughTick: 470, limits: seedLimits)
guard classic06Prefix.game.tick == 470, classic06Prefix.inputs.count == 7,
      let jumper = classic06Prefix.game.lemmings.first(where: { $0.id == 0 }),
      jumper.state == .jumping, jumper.x == 376, jumper.y == 96 else {
    fatalError("Classic 06 seed did not reproduce the measured tick-470 checkpoint")
}
do {
    _ = try l3SeedCandidate(from: classic06Base, levelNumber: 7,
        levelData: classic06Level.rawData, seed: classic06Seed, throughTick: 470, limits: seedLimits)
    fatalError("Classic 06 seed accepted the wrong level")
} catch {}
do {
    _ = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
        levelData: Data([0]), seed: classic06Seed, throughTick: 470, limits: seedLimits)
    fatalError("Classic 06 seed accepted the wrong source")
} catch {}
let wrongInitialState = L3Seed(version: classic06Seed.version, level: classic06Seed.level,
    levelSHA256: classic06Seed.levelSHA256, population: classic06Seed.population,
    initialStateHash: "wrong", inputs: classic06Seed.inputs)
do {
    _ = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
        levelData: classic06Level.rawData, seed: wrongInitialState, throughTick: 470, limits: seedLimits)
    fatalError("Classic 06 seed accepted the wrong initial state")
} catch {}
var outOfOrderInputs = classic06Seed.inputs
outOfOrderInputs.swapAt(0, 1)
let outOfOrder = L3Seed(version: classic06Seed.version, level: classic06Seed.level,
    levelSHA256: classic06Seed.levelSHA256, population: classic06Seed.population,
    initialStateHash: classic06Seed.initialStateHash, inputs: outOfOrderInputs)
do {
    _ = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
        levelData: classic06Level.rawData, seed: outOfOrder, throughTick: 470, limits: seedLimits)
    fatalError("Classic 06 seed accepted unordered inputs")
} catch {}
var rejectedInputs = classic06Seed.inputs
rejectedInputs[6] = .init(tick: 470, action: "jumper", lemming: 999, direction: nil)
let rejected = L3Seed(version: classic06Seed.version, level: classic06Seed.level,
    levelSHA256: classic06Seed.levelSHA256, population: classic06Seed.population,
    initialStateHash: classic06Seed.initialStateHash, inputs: rejectedInputs)
do {
    _ = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
        levelData: classic06Level.rawData, seed: rejected, throughTick: 470, limits: seedLimits)
    fatalError("Classic 06 seed accepted a rejected input")
} catch {}
var classic06Continuation = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
    levelData: classic06Level.rawData, seed: classic06Seed, throughTick: 1191, limits: seedLimits)
while l3Advance(&classic06Continuation, limits: seedLimits) {}
guard classic06Continuation.game.isComplete, classic06Continuation.game.saved == 2,
      classic06Continuation.game.lost == 8, classic06Continuation.game.reserve == 3 else {
    fatalError("Classic 06 seed did not retain its two-save continuation")
}
var abortLimits = seedLimits
abortLimits.maxTicks = 1200
abortLimits.maxDepth = 1
abortLimits.beamWidth = 2
abortLimits.budgetSeconds = 1
let abortStart = try l3SeedCandidate(from: classic06Base, levelNumber: 6,
    levelData: classic06Level.rawData, seed: classic06Seed, throughTick: 1192, limits: abortLimits)
guard abortStart.game.saved == 2 else { fatalError("Classic 06 abort checkpoint lost a saved lemming") }
let abortReport = l3Search(from: classic06Base, limits: abortLimits, seed: abortStart)
guard let abortWinner = abortReport.best, abortWinner.inputs.last?.action == "abort" else {
    fatalError("Seeded search did not offer the bounded abort completion")
}
let abortReplay = L3Replay(level: 6, levelSHA256: L3Replay.digest(classic06Level.rawData),
    population: 13, initialStateHash: L3Replay.stateHash(classic06Base),
    inputs: abortWinner.inputs, expected: .init(abortWinner.game))
_ = try abortReplay.replay(from: classic06Base, levelData: classic06Level.rawData)
var endRunTags = [UInt16](repeating: 0x1000, count: 128 * 64)
for y in 40..<64 { for x in 0..<128 { endRunTags[y * 128 + x] = 0x20 } }
var endRunBase = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: endRunTags,
    entrance: .init(x: 96, y: 40), exits: [.init(x: 20, y: 39)], total: 2,
    releaseInterval: 1, releaseDelay: 1000, timeLimit: 60,
    extras: [.init(x: 20, y: 40, direction: 1), .init(x: 96, y: 40, direction: 1)]))
endRunBase.step()
guard endRunBase.assign(.blocker, to: 1) else { fatalError("L3 End Run test could not set its live blocker") }
while (endRunBase.lemmings[0].state != .exiting || endRunBase.lemmings[0].age < 8) && endRunBase.tick < 30 {
    endRunBase.step()
}
guard endRunBase.saved == 0, endRunBase.lemmings[0].state == .exiting,
      endRunBase.lemmings[1].state == .blocking, !endRunBase.isComplete else {
    fatalError("L3 End Run test did not reach a save with one live blocker")
}
var unseededLimits = L3Limits()
unseededLimits.maxTicks = endRunBase.tick + 2
unseededLimits.maxDepth = 1
unseededLimits.budgetSeconds = 1
var saveDecision = L3Candidate(game: endRunBase, detector: L3Detector())
let stoppedAtSave = l3Advance(&saveDecision, limits: unseededLimits)
guard stoppedAtSave,
      saveDecision.game.tick == endRunBase.tick + 1,
      saveDecision.game.saved == 1,
      saveDecision.game.lemmings[1].state == .blocking else {
    fatalError("Solver did not stop at the save with a live blocker")
}
let unseededReport = l3Search(from: endRunBase, limits: unseededLimits)
guard let unseededWinner = unseededReport.best,
      unseededWinner.inputs.count == 1,
      unseededWinner.inputs[0].action == "abort",
      unseededWinner.inputs[0].tick == endRunBase.tick + 1,
      unseededWinner.game.saved == 1, unseededWinner.game.isComplete else {
    fatalError("Unseeded search did not offer End Run after a rescue")
}
let endRunSource = Data("unseeded End Run test".utf8)
let unseededReplay = L3Replay(level: 1, levelSHA256: L3Replay.digest(endRunSource), population: 2,
    initialStateHash: L3Replay.stateHash(endRunBase), inputs: unseededWinner.inputs,
    expected: .init(unseededWinner.game))
let firstEndRun = try unseededReplay.replay(from: endRunBase, levelData: endRunSource)
let secondEndRun = try unseededReplay.replay(from: endRunBase, levelData: endRunSource)
guard firstEndRun.saved == 1, firstEndRun.lost == 1,
      L3Replay.Outcome(firstEndRun) == L3Replay.Outcome(secondEndRun) else {
    fatalError("Unseeded End Run did not replay to the same result twice")
}
guard !L3Limits().pairedActors else { fatalError("Paired actors must remain opt-in") }
let shadow02Level = campaign.levels[1]
let shadow02Permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", shadow02Level.permanentObjectsReference))))
let shadow02Temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", shadow02Level.temporaryObjectsReference))))
var shadow02Game = try Lemmings3Runtime(level: shadow02Level, style: style, permanent: shadow02Permanent,
                                        temporary: shadow02Temporary, total: 20)
let shadow02Fixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/102.json")))
guard shadow02Fixture.levelSHA256 == L3Replay.digest(shadow02Level.rawData),
      shadow02Fixture.initialStateHash == L3Replay.stateHash(shadow02Game) else {
    fatalError("Shadow 02 fixture does not match the exact source level")
}
var shadow02Cursor = 0
var shadow02Detector = L3Detector()
_ = shadow02Detector.update(shadow02Game)
var shadow02Offered: [Int] = []
while shadow02Game.tick < 1594 {
    while shadow02Cursor < shadow02Fixture.inputs.count && shadow02Fixture.inputs[shadow02Cursor].tick == shadow02Game.tick {
        guard L3Replay.apply(shadow02Fixture.inputs[shadow02Cursor], to: &shadow02Game) else {
            fatalError("Shadow 02 prefix failed")
        }
        shadow02Cursor += 1
    }
    shadow02Game.step()
    shadow02Offered = shadow02Detector.update(shadow02Game) ?? []
}
guard shadow02Offered.contains(2), shadow02Offered.contains(4) else {
    fatalError("Shadow 02 did not offer both actors at tick 1594")
}
let shadow02Choices = shadow02Offered.map { l3Actions(shadow02Game, lemming: $0) }
let shadow02Pair = l3PairedActions(shadow02Game, actorChoices: shadow02Choices).first { inputs in
    inputs.count == 2 && inputs.contains { $0.lemming == 2 && $0.action == "jumper" } &&
    inputs.contains { $0.lemming == 4 && $0.action == "walker" }
}
guard let shadow02Pair else { fatalError("Solver omitted the Shadow 02 same-tick two-actor pair") }
var expectedPairState = shadow02Game
for input in shadow02Fixture.inputs where input.tick == 1594 {
    guard L3Replay.apply(input, to: &expectedPairState) else { fatalError("Shadow 02 fixture pair failed") }
}
for input in shadow02Pair {
    guard L3Replay.apply(input, to: &shadow02Game) else { fatalError("Shadow 02 solver pair failed") }
}
guard L3Replay.stateHash(shadow02Game) == L3Replay.stateHash(expectedPairState) else {
    fatalError("Shadow 02 solver pair changed the retained state")
}
print("PASS L3 solver offers accepted Brick and Spade directions from retained routes")
print("PASS L3 solver offers a useful tool site on Classic 03")
print("PASS L3 solver offers the retained Shadow 08 same-tick builder turn")
print("PASS L3 solver offers the retained Shadow 02 same-tick two-actor pair")
print("PASS L3 solver validates and continues the Classic 06 exact-state seed")
print("PASS L3 solver replay-verifies a seeded abort completion")
print("PASS L3 solver replay-verifies an unseeded End Run after a rescue")
