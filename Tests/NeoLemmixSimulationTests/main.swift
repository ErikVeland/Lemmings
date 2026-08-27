import Foundation
import NxlvKit

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard try condition() else { throw TestFailure(description: message()) }
}

private func requireValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(description: message) }
    return value
}

private func terrain(
    width: Int = 128,
    height: Int = 96,
    floorY: Int? = 48,
    extraSolid: [NeoLemmixPoint] = [],
    steel: [NeoLemmixPoint] = [],
    oneWay: [(NeoLemmixPoint, NeoLemmixOneWayDirection)] = []
) throws -> NeoLemmixTerrain {
    var result = try NeoLemmixTerrain(width: width, height: height)
    if let floorY {
        for x in 0..<width { result.setSolid(true, x: x, y: floorY) }
    }
    for point in extraSolid { result.setSolid(true, x: point.x, y: point.y) }
    for point in steel { result.setSteel(true, x: point.x, y: point.y) }
    for (point, direction) in oneWay {
        result.setSolid(true, x: point.x, y: point.y)
        result.setOneWay(direction, x: point.x, y: point.y)
    }
    return result
}

private func allSkills(_ supply: NeoLemmixSkillSupply = .infinite)
    -> [NeoLemmixSkill: NeoLemmixSkillSupply] {
    Dictionary(uniqueKeysWithValues: NeoLemmixSkill.allCases.map { ($0, supply) })
}

private func configuration(
    total: Int = 1,
    required: Int = 0,
    spawnInterval: Int = 4,
    entrances: [NeoLemmixEntrance] = [],
    zones: [NeoLemmixZone] = [],
    preplaced: [NeoLemmixPreplacedLemming] = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 48)),
    ],
    skills: [NeoLemmixSkill: NeoLemmixSkillSupply] = allSkills(),
    timeLimitTicks: Int? = nil
) throws -> NeoLemmixConfiguration {
    try NeoLemmixConfiguration(
        totalLemmings: total,
        requiredToSave: required,
        timeLimitTicks: timeLimitTicks,
        spawnInterval: spawnInterval,
        entrances: entrances,
        zones: zones,
        preplacedLemmings: preplaced,
        skills: skills
    )
}

private func walkingSimulation(
    terrain inputTerrain: NeoLemmixTerrain? = nil,
    zones: [NeoLemmixZone] = [],
    traits: Set<NeoLemmixTrait> = [],
    position: NeoLemmixPoint = NeoLemmixPoint(x: 20, y: 48),
    direction: NeoLemmixDirection = .right,
    skills: [NeoLemmixSkill: NeoLemmixSkillSupply] = allSkills()
) throws -> NeoLemmixSimulation {
    let preplaced = NeoLemmixPreplacedLemming(
        position: position,
        direction: direction,
        traits: traits
    )
    var simulation = try NeoLemmixSimulation(
        terrain: inputTerrain ?? terrain(),
        configuration: configuration(
            zones: zones,
            preplaced: [preplaced],
            skills: skills
        )
    )
    simulation.tick()
    return simulation
}

private func lemming(_ simulation: NeoLemmixSimulation, id: Int = 0) throws -> NeoLemmixLemming {
    try requireValue(simulation.lemmings.first { $0.id == id }, "Missing lemming \(id).")
}

private func testRulesAndSpawnTiming() throws {
    try require(NeoLemmixRules.ticksPerSecond == 17, "The tick rate changed.")
    try require(NeoLemmixRules.minimumSpawnInterval == 4, "The minimum spawn interval changed.")
    try require(NeoLemmixRules.maximumSafeFallDistance == 62, "The splat limit changed.")

    let entrance = NeoLemmixEntrance(
        id: 7,
        position: NeoLemmixPoint(x: 20, y: 10),
        direction: .left,
        traits: [.climber]
    )
    var simulation = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            total: 3,
            spawnInterval: 4,
            entrances: [entrance],
            preplaced: []
        )
    )
    var hatchTicks: [Int] = []
    var openedTick: Int?
    while hatchTicks.count < 3 {
        let events = simulation.tick()
        if events.contains(.entrancesOpened) { openedTick = simulation.tickCount }
        for event in events {
            if case .hatched = event { hatchTicks.append(simulation.tickCount) }
        }
    }
    try require(openedTick == 35, "Entrances did not open on tick 35.")
    try require(hatchTicks == [54, 58, 62], "Spawn ticks were \(hatchTicks).")
    let first = try lemming(simulation)
    try require(first.direction == .left, "The entrance direction was not applied.")
    try require(first.traits.contains(.climber), "The entrance trait was not applied.")
}

private func testPreplacedTraitsAndCoreMovement() throws {
    var wallPoints: [NeoLemmixPoint] = []
    for y in 36...48 { wallPoints.append(NeoLemmixPoint(x: 24, y: y)) }
    var simulation = try walkingSimulation(
        terrain: terrain(extraSolid: wallPoints),
        traits: [.climber, .floater],
        position: NeoLemmixPoint(x: 20, y: 48)
    )
    try require(try lemming(simulation).action == .walking, "The preplaced lemming did not land.")
    simulation.run(ticks: 4)
    let climber = try lemming(simulation)
    try require(
        climber.action == .climbing || climber.action == .hoisting,
        "The climber did not use the wall."
    )

    var faller = try walkingSimulation(
        terrain: terrain(floorY: 85),
        traits: [.floater],
        position: NeoLemmixPoint(x: 20, y: 10)
    )
    faller.run(ticks: 8)
    try require(try lemming(faller).action == .floating, "The floater did not open after a long fall.")

    var glider = try walkingSimulation(
        terrain: terrain(floorY: 85),
        traits: [.glider],
        position: NeoLemmixPoint(x: 20, y: 10)
    )
    glider.run(ticks: 5)
    try require(try lemming(glider).action == .gliding, "The glider did not open after a long fall.")

    var shimmyCeiling: [NeoLemmixPoint] = []
    for x in 0..<128 { shimmyCeiling.append(.init(x: x, y: 39)) }
    let shimmyPreplaced = NeoLemmixPreplacedLemming(
        position: .init(x: 20, y: 48),
        traits: [.shimmier]
    )
    let preplacedShimmier = try NeoLemmixSimulation(
        terrain: terrain(extraSolid: shimmyCeiling),
        configuration: configuration(preplaced: [shimmyPreplaced])
    )
    try require(
        try lemming(preplacedShimmier).action == .shimmying,
        "A supported preplaced shimmier did not start shimmying."
    )
}

private func testPermanentSkillAssignments() throws {
    let vectors: [(NeoLemmixSkill, NeoLemmixTrait)] = [
        (.slider, .slider),
        (.climber, .climber),
        (.swimmer, .swimmer),
        (.floater, .floater),
        (.glider, .glider),
        (.disarmer, .disarmer),
    ]
    for (skill, trait) in vectors {
        var simulation = try walkingSimulation()
        let result = simulation.assign(skill: skill, to: 0)
        try require(result.wasAssigned, "The \(skill.rawValue) assignment failed.")
        try require(
            try lemming(simulation).traits.contains(trait),
            "The \(skill.rawValue) trait was not stored."
        )
        let duplicate = simulation.assign(skill: skill, to: 0)
        try require(
            duplicate == .rejected(
                lemmingID: 0,
                skill: skill,
                reason: .duplicatePermanentSkill
            ),
            "The duplicate \(skill.rawValue) assignment was not rejected."
        )
    }

    var conflict = try walkingSimulation()
    try require(conflict.assign(skill: .floater, to: 0).wasAssigned, "Floater setup failed.")
    try require(
        conflict.assign(skill: .glider, to: 0) == .rejected(
            lemmingID: 0,
            skill: .glider,
            reason: .conflictingPermanentSkill
        ),
        "Floater and glider were not mutually exclusive."
    )

    var ledge = try terrain(floorY: nil)
    for x in 0...21 { ledge.setSolid(true, x: x, y: 48) }
    var slider = try walkingSimulation(terrain: ledge)
    try require(slider.assign(skill: .slider, to: 0).wasAssigned, "Slider setup failed.")
    slider.tick()
    try require(
        try lemming(slider).action == .dehoisting,
        "Slider did not start dehoisting at a supported ledge."
    )
}

private func testWalkerJumperAndShimmier() throws {
    var walker = try walkingSimulation()
    let beforeDirection = try lemming(walker).direction
    try require(walker.assign(skill: .walker, to: 0).wasAssigned, "Walker assignment failed.")
    try require(try lemming(walker).direction == beforeDirection.opposite, "Walker did not turn.")

    var jumper = try walkingSimulation()
    let start = try lemming(jumper).position
    try require(jumper.assign(skill: .jumper, to: 0).wasAssigned, "Jumper assignment failed.")
    jumper.tick()
    let jumped = try lemming(jumper)
    try require(jumped.position.x > start.x, "Jumper did not move forward.")
    try require(jumped.position.y < start.y, "Jumper did not move upward.")

    var ceiling: [NeoLemmixPoint] = []
    for x in 0..<128 { ceiling.append(NeoLemmixPoint(x: x, y: 38)) }
    var shimmier = try walkingSimulation(terrain: terrain(extraSolid: ceiling))
    try require(shimmier.assign(skill: .shimmier, to: 0).wasAssigned, "Shimmier assignment failed.")
    shimmier.run(ticks: 2)
    try require(
        [.reaching, .shimmying].contains(try lemming(shimmier).action),
        "The shimmier did not reach the ceiling."
    )
}

private func testBlockerAndConstructiveSkills() throws {
    let two = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 30, y: 48), direction: .right),
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 48), direction: .right),
    ]
    var blockers = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: two)
    )
    blockers.tick()
    try require(blockers.assign(skill: .blocker, to: 0).wasAssigned, "Blocker assignment failed.")
    blockers.run(ticks: 8)
    try require(try lemming(blockers, id: 1).direction == .left, "The blocker field did not turn a walker.")

    let constructive: [(NeoLemmixSkill, Int)] = [(.builder, 9), (.platformer, 9), (.stacker, 7)]
    for (skill, ticks) in constructive {
        var skillTerrain = try terrain()
        if skill == .platformer {
            skillTerrain = try terrain(floorY: nil)
            for x in 0...20 { skillTerrain.setSolid(true, x: x, y: 48) }
        }
        let start = skill == .platformer
            ? NeoLemmixPoint(x: 19, y: 48) : NeoLemmixPoint(x: 20, y: 48)
        var simulation = try walkingSimulation(terrain: skillTerrain, position: start)
        let revision = simulation.terrainRevision
        try require(simulation.assign(skill: skill, to: 0).wasAssigned, "\(skill.rawValue) assignment failed.")
        simulation.run(ticks: ticks)
        try require(
            simulation.terrainRevision > revision,
            "The \(skill.rawValue) did not add terrain."
        )
    }
}

private func testDestructiveSkillsAndMaterials() throws {
    var wall: [NeoLemmixPoint] = []
    for x in 22...45 {
        for y in 38...48 { wall.append(NeoLemmixPoint(x: x, y: y)) }
    }
    let protectedLeft = NeoLemmixPoint(x: 23, y: 43)
    let unprotectedRight = NeoLemmixPoint(x: 24, y: 43)
    let protectedDown = NeoLemmixPoint(x: 25, y: 43)
    var basher = try walkingSimulation(terrain: terrain(
        extraSolid: wall,
        oneWay: [
            (protectedLeft, .left),
            (unprotectedRight, .right),
            (protectedDown, .down),
        ]
    ))
    try require(basher.assign(skill: .basher, to: 0).wasAssigned, "Basher assignment failed.")
    basher.run(ticks: 5)
    try require(basher.terrainRevision > 0, "Basher did not remove terrain.")
    try require(
        basher.terrain.isSolid(x: protectedLeft.x, y: protectedLeft.y),
        "Left one-way terrain did not protect against a right-facing basher."
    )
    try require(
        !basher.terrain.isSolid(x: unprotectedRight.x, y: unprotectedRight.y),
        "Right one-way terrain incorrectly protected against a right-facing basher."
    )
    try require(
        basher.terrain.isSolid(x: protectedDown.x, y: protectedDown.y),
        "Down one-way terrain did not protect against a basher."
    )

    var miner = try walkingSimulation(terrain: terrain(extraSolid: wall))
    try require(miner.assign(skill: .miner, to: 0).wasAssigned, "Miner assignment failed.")
    miner.run(ticks: 2)
    try require(miner.terrainRevision > 0, "Miner did not remove terrain.")

    var filledRows: [NeoLemmixPoint] = []
    for x in 0..<128 { filledRows.append(NeoLemmixPoint(x: x, y: 47)) }
    var digger = try walkingSimulation(terrain: terrain(extraSolid: filledRows))
    try require(digger.assign(skill: .digger, to: 0).wasAssigned, "Digger assignment failed.")
    digger.run(ticks: 8)
    try require(digger.terrainRevision > 0, "Digger did not remove terrain.")

    let steelPoint = NeoLemmixPoint(x: 21, y: 48)
    var steelDigger = try walkingSimulation(terrain: terrain(steel: [steelPoint]))
    try require(
        steelDigger.assign(skill: .digger, to: 0) == .rejected(
            lemmingID: 0,
            skill: .digger,
            reason: .blockedBySteelOrOneWay
        ),
        "Steel did not reject the digger."
    )

    var oneWayDigger = try walkingSimulation(
        terrain: terrain(oneWay: [(steelPoint, .up)])
    )
    try require(
        oneWayDigger.assign(skill: .digger, to: 0) == .rejected(
            lemmingID: 0,
            skill: .digger,
            reason: .blockedBySteelOrOneWay
        ),
        "Up one-way terrain did not reject the digger."
    )
}

private func testBomberAndStoner() throws {
    let steelPixel = NeoLemmixPoint(x: 20, y: 48)
    var bomber = try walkingSimulation(terrain: terrain(steel: [steelPixel]))
    try require(bomber.assign(skill: .bomber, to: 0).wasAssigned, "Bomber assignment failed.")
    bomber.run(ticks: 18)
    try require(try lemming(bomber).removalReason == .exploded, "Bomber did not explode.")
    try require(bomber.terrainRevision > 0, "Bomber did not remove terrain.")
    try require(
        bomber.terrain.isSolid(x: steelPixel.x, y: steelPixel.y)
            && bomber.terrain.isSteel(x: steelPixel.x, y: steelPixel.y),
        "Bomber removed steel terrain."
    )

    var stoner = try walkingSimulation(terrain: terrain(floorY: 70), position: .init(x: 20, y: 30))
    try require(stoner.assign(skill: .stoner, to: 0).wasAssigned, "Stoner assignment failed.")
    stoner.run(ticks: 18)
    try require(try lemming(stoner).removalReason == .stoned, "Stoner did not finish.")
    try require(stoner.terrainRevision > 0, "Stoner did not add terrain.")
}

private func testSwimmingAndHazards() throws {
    let water = NeoLemmixZone(
        id: 10,
        effect: .water,
        bounds: NeoLemmixRect(x: 22, y: 40, width: 12, height: 12)
    )
    var swimmer = try walkingSimulation(zones: [water])
    try require(swimmer.assign(skill: .swimmer, to: 0).wasAssigned, "Swimmer assignment failed.")
    swimmer.run(ticks: 2)
    try require(try lemming(swimmer).action == .swimming, "Swimmer drowned in water.")

    var drowner = try walkingSimulation(zones: [water])
    drowner.run(ticks: 2)
    try require(try lemming(drowner).action == .drowning, "Water did not drown a non-swimmer.")

    let fire = NeoLemmixZone(
        id: 11,
        effect: .fire,
        bounds: NeoLemmixRect(x: 22, y: 40, width: 5, height: 12)
    )
    var burned = try walkingSimulation(zones: [fire])
    burned.run(ticks: 2)
    try require(try lemming(burned).action == .vaporizing, "Fire did not vaporize a lemming.")

    let exit = NeoLemmixZone(
        id: 12,
        effect: .exit,
        bounds: NeoLemmixRect(x: 22, y: 40, width: 5, height: 12)
    )
    var exiting = try walkingSimulation(zones: [exit])
    exiting.run(ticks: 2)
    try require(try lemming(exiting).action == .exiting, "Exit did not accept a lemming.")
    exiting.run(ticks: 8)
    try require(exiting.savedCount == 1 && exiting.didWin, "Exit did not save the lemming.")

    let trap = NeoLemmixZone(
        id: 13,
        effect: .oneShotTrap,
        bounds: NeoLemmixRect(x: 22, y: 40, width: 5, height: 12),
        isDisarmable: true
    )
    var trapped = try walkingSimulation(zones: [trap])
    trapped.run(ticks: 2)
    try require(try lemming(trapped).action == .vaporizing, "Trap did not catch a lemming.")
    try require(trapped.disabledZoneIDs.contains(13), "One-shot trap remained enabled.")
}

private func testNxlvAdapter() throws {
    let text = """
    TITLE Simulation Adapter
    LEMMINGS 2
    SAVE_REQUIREMENT 1
    TIME_LIMIT 120
    MAX_SPAWN_INTERVAL 12
    WIDTH 64
    HEIGHT 64

    $SKILLSET
      BUILDER 3
      CLIMBER INFINITE
    $END

    $GADGET
      STYLE default
      PIECE hatch
      X 10
      Y 8
      DIRECTION LEFT
      FLOATER
    $END

    $GADGET
      STYLE default
      PIECE exit
      X 50
      Y 40
    $END

    $LEMMING
      X 20
      Y 48
      CLIMBER
    $END
    """
    let level = try requireValue(NxlvLevel(text: text), "NXLV adapter fixture did not parse.")
    let baseTerrain = try terrain(width: 64, height: 64, floorY: 48)
    let rendered = NxlvRenderedLevel(
        width: 64,
        height: 64,
        rgba: Array(repeating: 0, count: 64 * 64 * 4),
        solidMask: baseTerrain.solidMask,
        steelMask: baseTerrain.steelMask,
        oneWayMask: baseTerrain.oneWayMask,
        oneWayEligibleMask: Array(repeating: 0, count: 64 * 64),
        gadgets: [
            NxlvRenderedGadget(
                style: "default",
                piece: "hatch",
                effect: .entrance,
                x: 10,
                y: 8,
                width: 16,
                height: 16,
                triggerX: 12,
                triggerY: 10,
                triggerWidth: 1,
                triggerHeight: 1
            ),
            NxlvRenderedGadget(
                style: "default",
                piece: "exit",
                effect: .exit,
                x: 50,
                y: 40,
                width: 12,
                height: 16,
                triggerX: 52,
                triggerY: 45,
                triggerWidth: 4,
                triggerHeight: 3
            ),
        ]
    )
    let simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
    try require(simulation.configuration.totalLemmings == 2, "NXLV total count was not converted.")
    try require(simulation.configuration.requiredToSave == 1, "NXLV save count was not converted.")
    try require(
        simulation.configuration.timeLimitTicks == 120 * NeoLemmixRules.ticksPerSecond,
        "NXLV time limit was not converted."
    )
    try require(simulation.configuration.entrances.first?.position == .init(x: 12, y: 10),
                "Rendered entrance trigger position was not used.")
    try require(simulation.configuration.entrances.first?.direction == .left,
                "NXLV entrance direction was not converted.")
    try require(simulation.configuration.entrances.first?.traits.contains(.floater) == true,
                "NXLV entrance trait was not converted.")
    try require(simulation.configuration.zones.first?.effect == .exit,
                "Rendered exit was not converted.")
    try require(simulation.skills[.builder] == .finite(3), "Finite NXLV skill supply was not converted.")
    try require(simulation.skills[.climber] == .infinite, "Infinite NXLV skill supply was not converted.")
    try require(try lemming(simulation).traits.contains(.climber),
                "NXLV preplaced trait was not converted.")
}

private func testDisarmer() throws {
    let trap = NeoLemmixZone(
        id: 20,
        effect: .trap,
        bounds: NeoLemmixRect(x: 22, y: 40, width: 5, height: 12),
        isDisarmable: true
    )
    var simulation = try walkingSimulation(zones: [trap])
    try require(simulation.assign(skill: .disarmer, to: 0).wasAssigned, "Disarmer assignment failed.")
    simulation.run(ticks: 2)
    try require(try lemming(simulation).action == .disarming, "Disarmer did not start fixing the trap.")
    simulation.run(ticks: 42)
    try require(simulation.disabledZoneIDs.contains(20), "Disarmer did not disable the trap.")
}

private func testCloner() throws {
    var simulation = try walkingSimulation()
    let sourceDirection = try lemming(simulation).direction
    try require(simulation.assign(skill: .cloner, to: 0).wasAssigned, "Cloner assignment failed.")
    try require(simulation.lemmings.count == 2 && simulation.clonedCount == 1, "Cloner count mismatch.")
    let clone = try lemming(simulation, id: 1)
    try require(clone.direction == sourceDirection.opposite, "Clone did not face the other direction.")
    try require(clone.cloneParentID == 0, "Clone parent ID was not stored.")
}

private func testUnsupportedSkillsAreExplicit() throws {
    for skill in [NeoLemmixSkill.fencer, .laserer] {
        var simulation = try walkingSimulation()
        try require(
            simulation.assign(skill: skill, to: 0) == .rejected(
                lemmingID: 0,
                skill: skill,
                reason: .unsupportedSkill
            ),
            "\(skill.rawValue) did not return an unsupported result."
        )
    }
}

private func testReplayOrderAndInventory() throws {
    let preplaced = NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 48))
    var simulation = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            spawnInterval: 10,
            preplaced: [preplaced],
            skills: [.walker: .finite(2), .builder: .finite(1)]
        )
    )
    simulation.tick()
    simulation.enqueueReplay([
        NeoLemmixReplayCommand(tick: 2, sequence: 20, command: .setSpawnInterval(5)),
        NeoLemmixReplayCommand(tick: 2, sequence: 10, command: .setSpawnInterval(8)),
        NeoLemmixReplayCommand(tick: 2, sequence: 30, command: .assign(lemmingID: 0, skill: .walker)),
    ])
    simulation.tick()
    try require(simulation.spawnInterval == 5, "Replay commands did not use sequence order.")
    try require(simulation.skills[.walker] == .finite(1), "Replay assignment did not consume inventory.")
}

private func testCodableContinuation() throws {
    var original = try walkingSimulation()
    original.enqueue(.assign(lemmingID: 0, skill: .builder), atTick: 3)
    original.enqueue(.setSpawnInterval(4), atTick: 4)
    original.run(ticks: 3)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(original)
    var decoded = try JSONDecoder().decode(NeoLemmixSimulation.self, from: data)
    try require(decoded == original, "Codable did not preserve the simulation state.")
    original.run(ticks: 80)
    decoded.run(ticks: 80)
    try require(decoded == original, "Decoded simulation continuation diverged.")
    try require(decoded.snapshot() == original.snapshot(), "Decoded snapshot diverged.")
}

private func testNukeAndCompletion() throws {
    var simulation = try walkingSimulation()
    simulation.enqueue(.nuke)
    let events = simulation.tick()
    try require(events.contains(.nukeStarted), "Nuke command was not processed.")
    try require(try lemming(simulation).bomberCountdown != nil, "Nuke did not arm the lemming.")
    simulation.run(ticks: 110)
    try require(simulation.isComplete, "Nuked level did not complete.")
}

private let tests: [(String, () throws -> Void)] = [
    ("rules and spawn timing", testRulesAndSpawnTiming),
    ("preplaced traits and core movement", testPreplacedTraitsAndCoreMovement),
    ("permanent skills", testPermanentSkillAssignments),
    ("walker, jumper, and shimmier", testWalkerJumperAndShimmier),
    ("blocker and constructive skills", testBlockerAndConstructiveSkills),
    ("destructive skills and materials", testDestructiveSkillsAndMaterials),
    ("bomber and stoner", testBomberAndStoner),
    ("swimming and hazards", testSwimmingAndHazards),
    ("NXLV adapter", testNxlvAdapter),
    ("disarmer", testDisarmer),
    ("cloner", testCloner),
    ("unsupported skill diagnostics", testUnsupportedSkillsAreExplicit),
    ("replay order and inventory", testReplayOrderAndInventory),
    ("Codable continuation", testCodableContinuation),
    ("nuke and completion", testNukeAndCompletion),
]

do {
    for (name, test) in tests {
        try test()
        print("PASS \(name)")
    }
    print(
        "NeoLemmix simulation tests passed: \(tests.count) groups, "
            + "19 implemented skills, 2 explicit unsupported skills."
    )
} catch {
    fputs("NeoLemmix simulation test failed: \(error)\n", stderr)
    exit(1)
}
