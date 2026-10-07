import Foundation
import NxlvKit

func mark(_ section: String) {
    FileHandle.standardError.write(Data("L3 solver test: \(section)\n".utf8))
}

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
mark("Shadow 08")
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
while !game.isComplete && game.tick < 560 {
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
mark("Egyptian 01")
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
while !egyptianGame.isComplete && egyptianGame.tick < 241 { egyptianGame.step() }
assertOfferedToolDirections(egyptianGame, lemming: 0, tool: .spade, label: "Egyptian 01 Spade holder")

let classic = try Lemmings3ClassicCampaign(root: root, tribe: .classic)
mark("Classic 03")
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
var classicCursor = 0
var offeredSpadeSite = false
var fallbackCoveredNoTool = false
while !classicGame.isComplete && classicGame.tick < 198 {
    while classicCursor < classicFixture.inputs.count && classicFixture.inputs[classicCursor].tick == classicGame.tick {
        guard L3Replay.apply(classicFixture.inputs[classicCursor], to: &classicGame) else {
            fatalError("Classic 03 fixture prefix failed")
        }
        classicCursor += 1
    }
    classicGame.step()
    let offered = classicDetector.update(classicGame)
    if (offered ?? []).contains(1), classicGame.lemmings.first(where: { $0.id == 1 })?.tool == .spade {
        offeredSpadeSite = true
    }
    if classicGame.tick == 150 {
        fallbackCoveredNoTool = (offered ?? []).contains { id in
            classicGame.lemmings.contains { $0.id == id && $0.state == .walking && $0.tool == nil }
        }
    }
}
guard offeredSpadeSite, classicCursor == 1,
      l3Actions(classicGame, lemming: 1).contains(where: { choice in
          choice.count == 1 && choice[0].action == "use" && choice[0].direction == "down"
      }) else {
    fatalError("Solver cannot offer the known Classic 03 Spade route at a useful site")
}
guard fallbackCoveredNoTool else {
    fatalError("Tool-site decisions suppressed the other walking actors")
}
let dig = classicFixture.inputs[classicCursor]
guard L3Replay.apply(dig, to: &classicGame) else { fatalError("Classic 03 Spade action was rejected") }
while !classicGame.isComplete && classicGame.tick < 30_000 { classicGame.step() }
guard classicGame.isComplete, L3Replay.Outcome(classicGame) == classicFixture.expected else {
    fatalError("Classic 03 offered Spade route differs from its retained fixture")
}
let classic06Level = classic.levels[5]
mark("Classic 06")
let classic06Permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", classic06Level.permanentObjectsReference))))
let classic06Temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", classic06Level.temporaryObjectsReference))))
let classic06Base = try Lemmings3Runtime(level: classic06Level, style: classicStyle,
                                         permanent: classic06Permanent, temporary: classic06Temporary, total: 13)
let classic06Data = try Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CampaignTests/Fixtures/006-13.json"))
let classic06Seed = try JSONDecoder().decode(L3Seed.self, from: classic06Data)
let classic06Replay = try JSONDecoder().decode(L3Replay.self, from: classic06Data)
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
var continuationCursor = classic06Continuation.inputs.count
while !classic06Continuation.game.isComplete && classic06Continuation.game.tick <= classic06Replay.expected.ticks {
    while continuationCursor < classic06Seed.inputs.count &&
          classic06Seed.inputs[continuationCursor].tick == classic06Continuation.game.tick {
        guard L3Replay.apply(classic06Seed.inputs[continuationCursor], to: &classic06Continuation.game) else {
            fatalError("Classic 06 seeded continuation rejected a retained input")
        }
        continuationCursor += 1
    }
    if !classic06Continuation.game.isComplete { classic06Continuation.game.step() }
}
guard continuationCursor == classic06Seed.inputs.count, classic06Continuation.game.isComplete,
      L3Replay.Outcome(classic06Continuation.game) == classic06Replay.expected else {
    fatalError("Classic 06 seed did not retain its lossless continuation")
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
mark("End Run")
for y in 40..<64 { for x in 0..<128 { endRunTags[y * 128 + x] = 0x20 } }
var endRunBase = try Lemmings3Runtime(configuration: .init(width: 128, height: 64, attributes: endRunTags,
    entrance: .init(x: 96, y: 40), exits: [.init(x: 20, y: 39)], total: 2,
    releaseInterval: 1, releaseDelay: 1000, timeLimit: 60,
    extras: [.init(x: 20, y: 40, direction: 1), .init(x: 96, y: 40, direction: 1)]))
endRunBase.step()
guard endRunBase.assign(.blocker, to: 1) else { fatalError("L3 End Run test could not set its live blocker") }
while !endRunBase.isComplete &&
      (endRunBase.lemmings[0].state != .exiting || endRunBase.lemmings[0].age < 8) && endRunBase.tick < 30 {
    endRunBase.step()
}
guard endRunBase.saved == 0, endRunBase.lemmings[0].state == .exiting,
      endRunBase.lemmings[1].state == .blocking, !endRunBase.isComplete else {
    fatalError("L3 End Run test did not reach a save with one live blocker")
}
let heldScore = L3Score(L3Candidate(game: endRunBase, detector: L3Detector()),
    field: L3DistanceField(endRunBase))
var releasedBlocker = endRunBase
guard releasedBlocker.assign(.walker, to: 1) else {
    fatalError("L3 Walker could not release the held blocker")
}
let releasedScore = L3Score(L3Candidate(game: releasedBlocker, detector: L3Detector()),
    field: L3DistanceField(endRunBase))
guard heldScore.remaining == releasedScore.remaining, heldScore.remaining == 2 else {
    fatalError("Solver treated a releasable blocker as a lost survivor")
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
mark("Egyptian 18 pair")
let egyptian18Level = egyptian.levels[17]
let egyptian18Permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/PERM%03d.OBS", egyptian18Level.permanentObjectsReference))))
let egyptian18Temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
    String(format: "LEVELS/TEMP%03d.OBS", egyptian18Level.temporaryObjectsReference))))
var egyptian18Game = try Lemmings3Runtime(level: egyptian18Level, style: egyptianStyle,
                                          permanent: egyptian18Permanent, temporary: egyptian18Temporary, total: 20)
let egyptian18Fixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: URL(fileURLWithPath:
    "Tests/Lemmings3CompletionTests/Fixtures/218.json")))
guard egyptian18Fixture.levelSHA256 == L3Replay.digest(egyptian18Level.rawData),
      egyptian18Fixture.initialStateHash == L3Replay.stateHash(egyptian18Game) else {
    fatalError("Egyptian 18 fixture does not match the exact source level")
}
var egyptian18Cursor = 0
while !egyptian18Game.isComplete && egyptian18Game.tick < 30 {
    while egyptian18Cursor < egyptian18Fixture.inputs.count &&
          egyptian18Fixture.inputs[egyptian18Cursor].tick == egyptian18Game.tick {
        guard L3Replay.apply(egyptian18Fixture.inputs[egyptian18Cursor], to: &egyptian18Game) else {
            fatalError("Egyptian 18 prefix failed")
        }
        egyptian18Cursor += 1
    }
    egyptian18Game.step()
}
let egyptian18Choices = [0, 5].map { l3Actions(egyptian18Game, lemming: $0) }
let egyptian18Pair = l3PairedActions(egyptian18Game, actorChoices: egyptian18Choices).first { inputs in
    inputs.count == 2 && inputs.contains { $0.lemming == 0 && $0.action == "jumper" } &&
    inputs.contains { $0.lemming == 5 && $0.action == "walker" }
}
guard let egyptian18Pair else { fatalError("Solver omitted the Egyptian 18 same-tick two-actor pair") }
var expectedPairState = egyptian18Game
for input in egyptian18Fixture.inputs where input.tick == 30 {
    guard L3Replay.apply(input, to: &expectedPairState) else { fatalError("Egyptian 18 fixture pair failed") }
}
for input in egyptian18Pair {
    guard L3Replay.apply(input, to: &egyptian18Game) else { fatalError("Egyptian 18 solver pair failed") }
}
guard L3Replay.stateHash(egyptian18Game) == L3Replay.stateHash(expectedPairState) else {
    fatalError("Egyptian 18 solver pair changed the retained state")
}
let multiHatchTags = [UInt16](repeating: 0x1000, count: 128 * 64)
mark("multiple hatches")
var multiHatchGame = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
    attributes: multiHatchTags, entrance: .init(x: 20, y: 20), exits: [.init(x: 20, y: 20)],
    total: 5, releaseInterval: 100, releaseDelay: 1, timeLimit: 60,
    additionalEntrances: [.init(x: 100, y: 20)]))
let multiHatchField = L3DistanceField(multiHatchGame)
let firstHatchDistance = multiHatchField.distance(x: 20, y: 20)
let secondHatchDistance = multiHatchField.distance(x: 100, y: 20)
let initialHatchScore = L3Score(L3Candidate(game: multiHatchGame, detector: L3Detector()),
    field: multiHatchField)
guard secondHatchDistance != firstHatchDistance,
      initialHatchScore.distance == 3 * firstHatchDistance + 2 * secondHatchDistance else {
    fatalError("Solver scored every unreleased actor from the first hatch")
}
multiHatchGame.step()
let activeDistance = multiHatchGame.lemmings.filter(\.active).reduce(0) {
    $0 + multiHatchField.distance(x: $1.x, y: $1.y)
}
let nextHatchScore = L3Score(L3Candidate(game: multiHatchGame, detector: L3Detector()),
    field: multiHatchField)
guard multiHatchGame.released == 1,
      nextHatchScore.distance == activeDistance + 2 * firstHatchDistance + 2 * secondHatchDistance else {
    fatalError("Solver lost the release-order offset after the first actor")
}
var quotaGame = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
    attributes: multiHatchTags, entrance: .init(x: 20, y: 20), exits: [.init(x: 20, y: 20)],
    total: 20, releaseInterval: 100, releaseDelay: 1, timeLimit: 60,
    additionalEntrances: [.init(x: 100, y: 20)]))
let quotaField = L3DistanceField(quotaGame)
let quotaScore = L3Score(L3Candidate(game: quotaGame, detector: L3Detector()), field: quotaField)
guard quotaGame.reserve == 20, quotaGame.pendingReleases == 10,
      quotaScore.distance == 5 * firstHatchDistance + 5 * secondHatchDistance else {
    fatalError("Solver treated protected reserve actors as pending hatch releases")
}
quotaGame.step()
let quotaActiveDistance = quotaGame.lemmings.filter(\.active).reduce(0) {
    $0 + quotaField.distance(x: $1.x, y: $1.y)
}
let nextQuotaScore = L3Score(L3Candidate(game: quotaGame, detector: L3Detector()), field: quotaField)
guard quotaGame.reserve == 19, quotaGame.pendingReleases == 9,
      nextQuotaScore.distance == quotaActiveDistance + 4 * firstHatchDistance + 5 * secondHatchDistance else {
    fatalError("Solver scored unreleased reserve actors beyond the current release quota")
}
print("PASS L3 solver offers accepted Brick and Spade directions from retained routes")
print("PASS L3 solver offers a useful tool site on Classic 03")
print("PASS L3 solver offers the retained Shadow 08 same-tick builder turn")
print("PASS L3 solver offers the retained Egyptian 18 same-tick two-actor pair")
print("PASS L3 solver validates and continues the Classic 06 exact-state seed")
print("PASS L3 solver replay-verifies a seeded abort completion")
print("PASS L3 solver replay-verifies an unseeded End Run after a rescue")
print("PASS L3 solver retains releasable blockers in its survivor score")
print("PASS L3 solver scores unreleased actors from their release-order hatches")
print("PASS L3 solver excludes protected reserve actors from hatch distance")
