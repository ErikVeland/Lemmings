import Foundation
import NxlvKit

private func require(_ condition: Bool, _ message: String) throws {
    guard condition else { throw NSError(domain: "ExtraSkillEngineTests", code: 1,
        userInfo: [NSLocalizedDescriptionKey: message]) }
}

private func classic(limit: Int = 200, skills: [ClassicSkill: Int] = [.climber: 1]) throws -> ClassicDOSSimulation {
    let width = 128, height = 96
    var solid = Data(repeating: 0, count: width * height)
    for y in 80..<height { for x in 0..<width { solid[y * width + x] = 1 } }
    let terrain = try ClassicDOSTerrain(width: width, height: height, solidMask: solid,
        steelMask: Data(repeating: 0, count: solid.count))
    return try ClassicDOSSimulation(terrain: terrain, configuration: .init(totalLemmings: 1,
        requiredToSave: 1, timeLimitTicks: limit, initialReleaseRate: 50,
        entrances: [.init(x: 20, y: 10)], initialSkills: skills, maximumX: width - 1, maximumY: height - 1))
}

private func masks() throws -> Lemmings2TerrainMasks {
    let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [1], opaque: [true])
    return try .init(digger: frame, basher: Array(repeating: frame, count: 8),
        miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
        stacker: [frame, frame], platformer: frame)
}

private func l2() throws -> Lemmings2Runtime {
    let width = 128, height = 80
    var solid = [Bool](repeating: false, count: width * height)
    for y in 60..<height { for x in 0..<width { solid[y * width + x] = true } }
    return try .init(configuration: .init(width: width, height: height,
        pixels: solid.map { $0 ? 6 : 0 }, solid: solid, palette: Array(repeating: 255, count: 1024),
        entrance: .init(x: 20, y: 45, width: 1, height: 1),
        exits: [.init(x: 110, y: 50, width: 8, height: 16)], skills: [.climber, .floater, .unused],
        supplies: [1, 0, 1], total: 1, timeLimit: 120, releaseInterval: 20,
        terrainMasks: masks(), firstReleaseTick: 1))
}

private func l3() throws -> Lemmings3Runtime {
    let width = 128, height = 64
    var attributes = [UInt16](repeating: 0x1000, count: width * height)
    for y in 48..<height { for x in 0..<width { attributes[y * width + x] = 0x20 } }
    return try .init(configuration: .init(width: width, height: height, attributes: attributes,
        entrance: .init(x: 100, y: 40), exits: [.init(x: 110, y: 46)], total: 1,
        releaseInterval: 1000, releaseDelay: 1000,
        pickups: [.init(id: 0, tool: .bricks, x: 20, y: 48)],
        extras: [.init(x: 20, y: 47, direction: 1), .init(x: 60, y: 47, direction: 1)]))
}

private func testClassic() throws {
    var game = try classic()
    try require(!game.canGrantBonusSkill(.builder), "Classic forbids an absent skill")
    while game.lemmings.isEmpty { game.tick() }
    try require(game.assign(.climber, to: 0) == .assigned && game.remainingSkillCount(.climber) == 0,
        "Classic fixture consumes its last supplied skill")
    try require(game.grantBonusSkill(.climber) && game.remainingSkillCount(.climber) == 1,
        "Classic restores exactly one exhausted originally supplied skill")
    try require(game.bonusSkill == .climber && !game.grantBonusSkill(.climber),
        "Classic records the grant and rejects a second grant")
    let copy = try JSONDecoder().decode(ClassicDOSSimulation.self, from: JSONEncoder().encode(game))
    try require(copy == game && copy.bonusSkillUsed, "Classic checkpoints retain the grant")
    var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(classic())) as! [String: Any]
    legacy.removeValue(forKey: "bonusSkill")
    let decoded = try JSONDecoder().decode(ClassicDOSSimulation.self,
        from: JSONSerialization.data(withJSONObject: legacy))
    try require(!decoded.bonusSkillUsed, "Classic checkpoints without bonus state still decode")
    var overflow = try classic(skills: [.climber: Int.max])
    try require(!overflow.grantBonusSkill(.climber), "Classic rejects a stock overflow")
    while !game.isComplete { game.tick() }
    try require(!game.grantBonusSkill(.climber), "Classic rejects grants after completion")
    print("PASS Classic supplied/exhausted skill, one use, checkpoint compatibility and terminal guards")
}

private func testClassicRewindReplay() throws {
    let initial = try classic(limit: 20)
    var history = ClassicDOSRewind(simulation: initial, keyframeInterval: 2)
    for _ in 0..<5 { history.tick() }
    try require(history.grantBonusSkill(.climber), "Classic history accepts its first grant")
    for _ in 0..<3 { history.tick() }
    try require(history.seek(toTick: 3) && !history.simulation.bonusSkillUsed,
        "Classic seek before the grant restores original stock")
    try require(history.bonusSkillWasSpent && !history.canGrantBonusSkill(.climber),
        "Classic rewind retains the spent token latch")
    history = try JSONDecoder().decode(ClassicDOSRewind.self, from: JSONEncoder().encode(history))
    try require(history.bonusSkillWasSpent && !history.grantBonusSkill(.climber),
        "Classic history checkpoint retains the spent token latch")
    try require(history.seek(toTick: 8) && history.simulation.remainingSkillCount(.climber) == 2,
        "Classic forward seek replays the grant once")
    while !history.simulation.isComplete { history.tick() }
    let replay = history.replay(rank: "Test", number: 1, title: "Bonus",
        initialStateHash: ClassicDOSReplayRecorder.stateHash(of: initial))
    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial)
    try require(outcome.stateHash == ClassicDOSReplayRecorder.stateHash(of: history.simulation),
        "Classic exported replay reproduces the granted state")
    try require(history.seek(toTick: 3), "Classic history returns before the grant")
    history.resumeFromCurrentTick()
    for _ in 0..<5 { history.tick() }
    try require(history.bonusSkillWasSpent && history.simulation.remainingSkillCount(.climber) == 1
        && !history.grantBonusSkill(.climber), "Classic abandoned grant cannot be spent again")
    print("PASS Classic rewind, branch, checkpoint and deterministic bonus replay")
}

private func testNeo() throws {
    var terrain = try NeoLemmixTerrain(width: 64, height: 32)
    terrain.setSolid(true, x: 10, y: 20)
    let configuration = try NeoLemmixConfiguration(totalLemmings: 1, requiredToSave: 1,
        spawnInterval: 4, entrances: [], preplacedLemmings: [.init(position: .init(x: 10, y: 20))],
        skills: [.builder: .finite(2), .walker: .infinite, .digger: .finite(0)])
    var game = try NeoLemmixSimulation(terrain: terrain, configuration: configuration)
    try require(!game.grantBonusSkill(.walker) && !game.grantBonusSkill(.digger)
        && !game.grantBonusSkill(.climber), "Neo rejects unlimited, zero and absent skills")
    try require(game.grantBonusSkill(.builder) && game.skills[.builder] == .finite(3)
        && !game.grantBonusSkill(.builder), "Neo adds exactly one finite use once")
    let copy = try JSONDecoder().decode(NeoLemmixSimulation.self, from: JSONEncoder().encode(game))
    try require(copy == game && copy.bonusSkill == .builder, "Neo checkpoints retain bonus provenance")
    print("PASS Neo finite original skill eligibility and checkpoint provenance")
}

private func testL2() throws {
    var game = try l2()
    try require(!game.grantBonusSkill(slot: -1) && !game.grantBonusSkill(slot: 3)
        && !game.grantBonusSkill(slot: 1) && !game.grantBonusSkill(slot: 2),
        "L2 rejects absent, zero-supply and unused slots")
    game.step()
    try require(game.assign(slot: 0, to: 0) && game.supplies[0] == 0,
        "L2 fixture exhausts its supplied climber")
    let event = Lemmings2RouteEvent.bonusSkill(skill: Lemmings2Runtime.Skill.climber.rawValue)
    let encoded = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(Lemmings2RouteEvent.self, from: encoded)
    try require(Lemmings2EventCursor.perform(decoded, on: &game) && game.supplies[0] == 1,
        "L2 recorded bonus restores one existing exhausted slot")
    try require(game.bonusSkillSlot == 0 && !game.grantBonusSkill(slot: 0), "L2 rejects a second grant")
    var replay = try l2()
    replay.step()
    try require(replay.assign(slot: 0, to: 0) && Lemmings2EventCursor.perform(decoded, on: &replay)
        && replay.stateFingerprint == game.stateFingerprint, "L2 bonus event reconstructs the same state")
    print("PASS L2 original slots, exact charge, ordered bonus event and deterministic state")
}

private func testL3() throws {
    var game = try l3()
    try require(!game.grantBonusTool(to: 0) && !game.grantBonusTool(to: 999),
        "L3 rejects empty and absent carriers")
    game.step(); game.step()
    try require(game.lemmings[0].tool == .bricks && game.lemmings[0].quantity == 8,
        "L3 fixture collects its original eight-brick pickup")
    try require(!game.grantBonusTool(to: 1), "L3 cannot create a tool on an empty carrier")
    try require(game.grantBonusTool(to: 0) && game.lemmings[0].quantity == 9,
        "L3 grants one charge rather than another pickup box")
    try require(game.bonusTool == .bricks && game.bonusToolLemmingID == 0
        && !game.grantBonusTool(to: 0), "L3 retains carrier provenance and prevents a second grant")
    var copy = game
    copy.abort()
    try require(!copy.grantBonusTool(to: 0), "L3 rejects grants after completion")
    print("PASS L3 held tool eligibility, one charge, carrier provenance and terminal guard")
}

do {
    try testClassic()
    try testClassicRewindReplay()
    try testNeo()
    try testL2()
    try testL3()
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error.localizedDescription)\n".utf8))
    exit(1)
}
