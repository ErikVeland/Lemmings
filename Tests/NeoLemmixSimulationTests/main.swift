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

private func testMultipleEntranceOrder() throws {
    let entrances = [
        NeoLemmixEntrance(
            id: 10, position: .init(x: 10, y: 10), lemmingLimit: 1
        ),
        NeoLemmixEntrance(
            id: 20, position: .init(x: 20, y: 10)
        ),
        NeoLemmixEntrance(
            id: 30, position: .init(x: 30, y: 10), lemmingLimit: 2
        ),
    ]
    let preplaced = NeoLemmixPreplacedLemming(position: .init(x: 5, y: 48))
    var simulation = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            total: 7,
            spawnInterval: 4,
            entrances: entrances,
            preplaced: [preplaced]
        )
    )
    var entranceOrder: [Int] = []
    while entranceOrder.count < 6 {
        for event in simulation.tick() {
            if case let .hatched(_, entranceID) = event { entranceOrder.append(entranceID) }
        }
    }
    try require(
        entranceOrder == [10, 20, 30, 20, 30, 20],
        "CE multi-entrance order was \(entranceOrder)."
    )
}

private func testRenderOrder() throws {
    let equal = NeoLemmixRenderOrder.sorted(Array(0..<20)) { _ in 0 }
    try require(
        equal == [14, 13, 12, 11, 10, 19, 18, 17, 16, 15,
                  4, 3, 2, 1, 0, 9, 8, 7, 6, 5],
        "CE equal-priority quicksort permutation was \(equal)."
    )
    try require(
        NeoLemmixRenderOrder.priority(action: .exiting, traits: []) == 24,
        "CE Exiter render priority changed."
    )
    try require(
        NeoLemmixRenderOrder.priority(action: .walking, traits: [.neutral]) == 80,
        "CE Neutral render priority changed."
    )
    try require(
        NeoLemmixRenderOrder.priority(action: .walking, traits: [.zombie]) == 72,
        "CE Zombie render priority changed."
    )
    try require(
        NeoLemmixRenderOrder.priority(
            action: .walking, traits: [.climber], isSelected: true, isHighlighted: true
        ) == 252,
        "CE selected permanent-skill render priority changed."
    )
}

private func testPreplacedTraitsAndCoreMovement() throws {
    var walkerCycle = try walkingSimulation()
    walkerCycle.run(ticks: 6)
    try require(
        try lemming(walkerCycle).animationFrame == 7,
        "Walker artwork did not retain CE's eight-frame visual cycle."
    )

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

    var clipPoints = wallPoints
    clipPoints.append(NeoLemmixPoint(x: 23, y: 41))
    var clippedClimber = try walkingSimulation(
        terrain: terrain(extraSolid: clipPoints),
        traits: [.climber],
        position: NeoLemmixPoint(x: 20, y: 48)
    )
    for _ in 0..<20 where (try lemming(clippedClimber).action) != .falling {
        clippedClimber.tick()
    }
    let clipped = try lemming(clippedClimber)
    try require(
        clipped.action == .falling
            && clipped.fallDistance == 2
            && clipped.trueFallDistance == 1,
        "A clipped Climber ended as \(clipped.action.rawValue) with fall counters "
            + "\(clipped.fallDistance)/\(clipped.trueFallDistance)."
    )

    var faller = try walkingSimulation(
        terrain: terrain(floorY: 85),
        traits: [.floater],
        position: NeoLemmixPoint(x: 20, y: 10)
    )
    faller.run(ticks: 8)
    try require(try lemming(faller).action == .floating, "The floater did not open after a long fall.")

    var safeFaller = try NeoLemmixSimulation(
        terrain: terrain(floorY: 48),
        configuration: configuration(preplaced: [
            NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 40)),
        ])
    )
    try require(
        try lemming(safeFaller).fallDistance == 1
            && lemming(safeFaller).trueFallDistance == 1,
        "An initial CE Faller did not start with one fallen pixel."
    )
    safeFaller.run(ticks: 7)
    try require(
        try lemming(safeFaller).action == .walking
            && lemming(safeFaller).fallDistance > 0
            && lemming(safeFaller).trueFallDistance > 0,
        "A safe landing did not retain CE's last fall counters."
    )

    var floaterFrame = try NeoLemmixSimulation(
        terrain: terrain(floorY: 85),
        configuration: configuration(preplaced: [
            NeoLemmixPreplacedLemming(
                position: NeoLemmixPoint(x: 20, y: 10),
                traits: [.floater]
            ),
        ])
    )
    floaterFrame.run(ticks: 6)
    try require(
        try lemming(floaterFrame).action == .falling
            && lemming(floaterFrame).position.y == 28,
        "The floater opened partway through a falling physics frame."
    )
    floaterFrame.tick()
    try require(
        try lemming(floaterFrame).action == .floating
            && lemming(floaterFrame).position.y == 28,
        "The floater did not open at the start of the next physics frame."
    )

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

    var wall = try terrain(floorY: nil)
    for x in 0...21 { wall.setSolid(true, x: x, y: 48) }
    for y in 49..<80 { wall.setSolid(true, x: 21, y: y) }
    var wallSlider = try walkingSimulation(terrain: wall)
    try require(wallSlider.assign(skill: .slider, to: 0).wasAssigned,
                "Wall Slider setup failed.")
    wallSlider.run(ticks: 8)
    let resumedSlider = try lemming(wallSlider)
    try require(resumedSlider.action == .sliding,
                "Dehoister did not resume sliding against a continued wall.")
    try require(resumedSlider.dehoistPinY == nil,
                "Dehoister retained CE's temporary terrain pin after entering Slider.")
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
    var reaching = try walkingSimulation()
    try require(reaching.assign(skill: .shimmier, to: 0).wasAssigned,
                "A grounded worker could not start reaching without a ceiling.")
    try require(try lemming(reaching).action == .reaching,
                "A grounded Shimmier assignment did not enter the Reacher action.")
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
    blockers.run(ticks: 5)
    let rightFacingTurn = try lemming(blockers, id: 1)
    try require(rightFacingTurn.direction == .left, "The blocker field did not turn a walker.")
    try require(
        rightFacingTurn.position.x == 26,
        "A right-facing blocker's force lobe did not turn the walker at the CE position."
    )

    let mirrored = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 30, y: 48), direction: .left),
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 40, y: 48), direction: .left),
    ]
    var mirroredBlockers = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: mirrored)
    )
    mirroredBlockers.tick()
    try require(
        mirroredBlockers.assign(skill: .blocker, to: 0).wasAssigned,
        "Mirrored Blocker assignment failed."
    )
    mirroredBlockers.run(ticks: 5)
    let leftFacingTurn = try lemming(mirroredBlockers, id: 1)
    try require(leftFacingTurn.direction == .right, "The mirrored blocker field did not turn a walker.")
    try require(
        leftFacingTurn.position.x == 34,
        "A left-facing blocker's force lobe did not turn the walker at the CE position."
    )

    let builderPair = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 30, y: 48), direction: .right),
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 28, y: 48), direction: .right),
    ]
    var blockerBuilder = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: builderPair)
    )
    try require(blockerBuilder.assign(skill: .blocker, to: 0).wasAssigned,
                "The Builder-exception Blocker assignment failed.")
    try require(blockerBuilder.assign(skill: .builder, to: 1).wasAssigned,
                "The Builder-exception Builder assignment failed.")
    blockerBuilder.tick()
    try require(try lemming(blockerBuilder, id: 1).direction == .right,
                "A newly building lemming was turned by the middle of its Blocker field.")

    let lobeOverlapPair = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 30, y: 48), direction: .right),
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 22, y: 48), direction: .right),
    ]
    var lobeOverlap = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: lobeOverlapPair)
    )
    try require(lobeOverlap.assign(skill: .blocker, to: 0).wasAssigned,
                "The first lobe-overlap Blocker assignment failed.")
    try require(lobeOverlap.assign(skill: .blocker, to: 1).wasAssigned,
                "A force lobe incorrectly counted as the central Blocker overlap band.")

    let ohNoPair = [
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 30, y: 48), direction: .right),
        NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 24, y: 48), direction: .right),
    ]
    var ohNoBlocker = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: ohNoPair)
    )
    try require(ohNoBlocker.assign(skill: .blocker, to: 0).wasAssigned,
                "The Oh-No Blocker assignment failed.")
    try require(ohNoBlocker.assign(skill: .bomber, to: 0).wasAssigned,
                "The Blocker Bomber assignment failed.")
    ohNoBlocker.tick()
    try require(try lemming(ohNoBlocker).action == .ohNo,
                "A grounded Blocker did not enter its Oh-No animation.")
    try require(try lemming(ohNoBlocker, id: 1).direction == .left,
                "A grounded Oh-No Blocker dropped its force field before exploding.")

    var hollowDiggerTerrain = try terrain(floorY: nil)
    for x in 14...26 {
        for y in 47...50 { hollowDiggerTerrain.setSolid(true, x: x, y: y) }
    }
    hollowDiggerTerrain.setSolid(false, x: 20, y: 49)
    var hollowDigger = try walkingSimulation(
        terrain: hollowDiggerTerrain,
        position: NeoLemmixPoint(x: 20, y: 48)
    )
    try require(hollowDigger.assign(skill: .digger, to: 0).wasAssigned,
                "The hollow-foot Digger assignment failed.")
    hollowDigger.tick()
    try require(try lemming(hollowDigger).animationFrame == 1,
                "The first Digger tick delayed CE's visible animation with its physics cycle.")
    try require(!hollowDigger.terrain.isSolid(x: 20, y: 49),
                "The hollow-foot Blocker fixture unexpectedly has a center ground pixel.")
    try require(hollowDigger.assign(skill: .blocker, to: 0).wasAssigned,
                "A working lemming without a center foot pixel could not become a Blocker.")

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
        let expectedShade = skill == .stacker ? UInt8(5) : UInt8(1)
        try require(
            simulation.terrain.constructionShadeMask?.contains(expectedShade) == true,
            "The \(skill.rawValue) did not retain its CE construction gradient step."
        )
        simulation.run(ticks: 240)
        try require(
            try lemming(simulation).bricksRemaining == 0,
            "The \(skill.rawValue) brick counter survived its CE action transition."
        )
    }

    let lowStackTerrain = try terrain(floorY: nil, extraSolid: [.init(x: 20, y: 48)])
    var lowStack = try NeoLemmixSimulation(
        terrain: lowStackTerrain,
        configuration: configuration(preplaced: [
            .init(position: .init(x: 20, y: 48)),
        ])
    )
    try require(lowStack.assign(skill: .stacker, to: 0).wasAssigned,
                "The low Stacker assignment failed.")
    try require(try lemming(lowStack).stackLow == true,
                "The Stacker did not detect an unsupported forward foot pixel.")
    lowStack.run(ticks: 7)
    try require(lowStack.terrain.isSolid(x: 21, y: 48),
                "The low Stacker did not place its first brick at foot height.")
    try require(!lowStack.terrain.isSolid(x: 21, y: 47),
                "The low Stacker placed its first brick one row too high.")

    var blockedTerrain = try terrain()
    for x in 21...23 {
        blockedTerrain.setSolid(true, x: x, y: 47)
        blockedTerrain.setSolid(true, x: x, y: 46)
    }
    var blockedStack = try NeoLemmixSimulation(
        terrain: blockedTerrain,
        configuration: configuration(preplaced: [
            .init(position: .init(x: 20, y: 48)),
        ])
    )
    try require(blockedStack.assign(skill: .stacker, to: 0).wasAssigned,
                "The blocked Stacker assignment failed.")
    blockedStack.run(ticks: 8)
    try require(try lemming(blockedStack).direction == .left,
                "A Stacker that could not place a brick did not turn around.")
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
    let basherStart = try lemming(basher).position
    try require(basher.assign(skill: .basher, to: 0).wasAssigned, "Basher assignment failed.")
    basher.run(ticks: 2)
    try require(basher.terrainRevision > 0, "Basher did not remove terrain.")
    try require(!basher.terrain.isSolid(x: basherStart.x + 5, y: basherStart.y - 9),
                "The first Basher mask did not remove its top span.")
    try require(basher.terrain.isSolid(x: basherStart.x + 6, y: basherStart.y - 9),
                "The first Basher mask exceeded its top span.")
    try require(!basher.terrain.isSolid(x: basherStart.x + 4, y: basherStart.y - 7),
                "The first Basher mask did not remove its middle span.")
    try require(basher.terrain.isSolid(x: basherStart.x + 5, y: basherStart.y - 7),
                "The first Basher mask exceeded its middle span.")
    basher.run(ticks: 3)
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
    let minerStart = try lemming(miner).position
    try require(miner.assign(skill: .miner, to: 0).wasAssigned, "Miner assignment failed.")
    miner.run(ticks: 1)
    try require(miner.terrainRevision > 0, "Miner did not remove terrain.")
    try require(!miner.terrain.isSolid(x: minerStart.x + 7, y: minerStart.y - 10),
                "The first Miner mask did not remove its widest span.")
    try require(miner.terrain.isSolid(x: minerStart.x + 8, y: minerStart.y - 10),
                "The first Miner mask exceeded its widest span.")
    try require(!miner.terrain.isSolid(x: minerStart.x + 2, y: minerStart.y - 6),
                "The first Miner mask did not remove its narrow tail.")
    try require(miner.terrain.isSolid(x: minerStart.x + 3, y: minerStart.y - 6),
                "The first Miner mask exceeded its narrow tail.")

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
    var fallingBomber = try walkingSimulation(
        terrain: terrain(floorY: 70),
        traits: [.climber, .slider, .swimmer, .floater, .disarmer],
        position: .init(x: 20, y: 30)
    )
    let fallingStart = try lemming(fallingBomber).position
    try require(fallingBomber.assign(skill: .bomber, to: 0).wasAssigned,
                "Falling Bomber assignment failed.")
    fallingBomber.tick()
    try require(try lemming(fallingBomber).position == fallingStart,
                "An airborne instant Bomber moved before its explosion frame.")
    try require(try lemming(fallingBomber).action == .exploding,
                "An airborne instant Bomber did not bypass the Oh-No animation.")
    try require(try lemming(fallingBomber).hasBeenOhNo == false,
                "An airborne instant Bomber incorrectly recorded an Oh-No transition.")

    let updraft = NeoLemmixZone(
        id: 40,
        effect: .updraft,
        bounds: NeoLemmixRect(x: 0, y: 0, width: 128, height: 70)
    )
    var updraftBomber = try walkingSimulation(
        terrain: terrain(floorY: 70),
        zones: [updraft],
        position: .init(x: 20, y: 30)
    )
    let updraftStart = try lemming(updraftBomber).position
    try require(updraftBomber.assign(skill: .bomber, to: 0).wasAssigned,
                "Updraft Bomber assignment failed.")
    updraftBomber.tick()
    try require(try lemming(updraftBomber).position == updraftStart,
                "An airborne instant Bomber moved in an updraft before exploding.")

    let steelPixel = NeoLemmixPoint(x: 20, y: 48)
    var blastArea: [NeoLemmixPoint] = []
    for x in 10...32 { for y in 30...50 { blastArea.append(.init(x: x, y: y)) } }
    var bomber = try walkingSimulation(terrain: terrain(extraSolid: blastArea, steel: [steelPixel]))
    let bomberLemming = try lemming(bomber)
    let bomberStart = bomberLemming.position
    try require(bomber.assign(skill: .bomber, to: 0).wasAssigned, "Bomber assignment failed.")
    bomber.run(ticks: 18)
    try require(try lemming(bomber).removalReason == .exploded, "Bomber did not explode.")
    try require(bomber.terrainRevision > 0, "Bomber did not remove terrain.")
    try require(
        bomber.terrain.isSolid(x: steelPixel.x, y: steelPixel.y)
            && bomber.terrain.isSteel(x: steelPixel.x, y: steelPixel.y),
        "Bomber removed steel terrain."
    )
    let bomberLeft = bomberStart.x + (bomberLemming.direction == .right ? 1 : 0) - 8
    let bomberTop = bomberStart.y - 14
    try require(!bomber.terrain.isSolid(x: bomberLeft, y: bomberTop + 10),
                "Bomber did not apply the left edge of its full-width CE mask row at \(bomberLeft),\(bomberTop + 10).")
    try require(!bomber.terrain.isSolid(x: bomberLeft + 15, y: bomberTop + 10),
                "Bomber did not apply the right edge of its full-width CE mask row at \(bomberLeft + 15),\(bomberTop + 10).")
    try require(bomber.terrain.isSolid(x: bomberLeft, y: bomberTop),
                "Bomber removed a transparent corner outside the CE mask.")
    try require(!bomber.terrain.isSolid(x: bomberLeft + 7, y: bomberTop),
                "Bomber did not apply the top CE mask span.")

    var stoner = try walkingSimulation(terrain: terrain(floorY: 70), position: .init(x: 20, y: 30))
    try require(stoner.assign(skill: .stoner, to: 0).wasAssigned, "Stoner assignment failed.")
    stoner.run(ticks: 18)
    let finishedStoner = try lemming(stoner)
    try require(finishedStoner.removalReason == .stoned, "Stoner did not finish.")
    try require(stoner.terrainRevision > 0, "Stoner did not add terrain.")
    let stonerLeft = finishedStoner.position.x + (finishedStoner.direction == .right ? 1 : 0) - 8
    let stonerTop = finishedStoner.position.y - 10
    try require(stoner.terrain.isSolid(x: stonerLeft + 7, y: stonerTop)
                && stoner.terrain.isSolid(x: stonerLeft + 8, y: stonerTop),
                "Stoner did not apply the top CE mask span.")
    try require(
        stoner.terrain.stonerOwnerID(x: stonerLeft + 7, y: stonerTop) == finishedStoner.id
            && stoner.terrain.stonerOwnerID(x: stonerLeft + 8, y: stonerTop) == finishedStoner.id,
        "Stoner terrain did not retain its visual owner."
    )
    try require(
        stoner.terrain.stonerSourceIndex(x: stonerLeft + 7, y: stonerTop) == 7
            && stoner.terrain.stonerSourceIndex(x: stonerLeft + 8, y: stonerTop) == 8,
        "Stoner terrain did not retain its canonical source pixels."
    )
    try require(!stoner.terrain.isSolid(x: stonerLeft + 6, y: stonerTop),
                "Stoner filled a transparent pixel outside the CE mask.")
    var destroyedStonerTerrain = stoner.terrain
    _ = destroyedStonerTerrain.setSolid(false, x: stonerLeft + 7, y: stonerTop)
    try require(destroyedStonerTerrain.stonerOwnerID(x: stonerLeft + 7, y: stonerTop) == nil,
                "Destroyed Stoner terrain retained stale visual provenance.")
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
    try require(try lemming(trapped).removalReason == .trapped, "Trap did not catch a lemming.")
    try require(trapped.disabledZoneIDs.contains(13), "One-shot trap remained enabled.")

    let repeatingTrap = NeoLemmixZone(
        id: 14,
        effect: .trap,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        animationFrames: 4
    )
    let pair = [
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
    ]
    var occupiedTrap = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, zones: [repeatingTrap], preplaced: pair)
    )
    occupiedTrap.tick()
    try require(occupiedTrap.lemmings.filter { $0.removalReason == .trapped }.count == 1,
                "A busy repeating trap caught more than one lemming.")
    try require(occupiedTrap.activeLemmings.count == 1,
                "A busy repeating trap did not let the next lemming pass.")
    try require(occupiedTrap.gadgetAnimationFrames?[14] == 1,
                "A triggered trap did not advance to primary frame 1 on its trigger tick.")
    let savedTrap = try JSONDecoder().decode(
        NeoLemmixSimulation.self, from: JSONEncoder().encode(occupiedTrap)
    )
    try require(savedTrap == occupiedTrap,
                "A trap animation changed after save restoration.")
    occupiedTrap.tick()
    try require(occupiedTrap.gadgetAnimationFrames?[14] == 2,
                "A triggered trap did not advance to primary frame 2.")
    occupiedTrap.tick()
    try require(occupiedTrap.gadgetAnimationFrames?[14] == 3,
                "A triggered trap did not advance to primary frame 3.")
    occupiedTrap.tick()
    try require(occupiedTrap.gadgetAnimationFrames?[14] == 0,
                "A triggered trap did not return to primary frame 0.")

    let staggered = [
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
        NeoLemmixPreplacedLemming(position: .init(x: 16, y: 48)),
    ]
    var reusable = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, zones: [repeatingTrap], preplaced: staggered)
    )
    reusable.run(ticks: 5)
    try require(reusable.lemmings.filter { $0.removalReason == .trapped }.count == 2,
                "A repeating trap was not ready on the first pass after its animation wrapped.")
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
      FLIP_HORIZONTAL
      FLOATER
    $END

    $GADGET
      STYLE default
      PIECE exit
      X 50
      Y 40
    $END

    $GADGET
      STYLE default
      PIECE trap
      X 30
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
            NxlvRenderedGadget(
                style: "default",
                piece: "splat_pad",
                effect: .splatPad,
                x: 20,
                y: 48,
                width: 4,
                height: 1,
                triggerX: 20,
                triggerY: 48,
                triggerWidth: 4,
                triggerHeight: 1
            ),
            NxlvRenderedGadget(
                style: "default",
                piece: "trap",
                effect: .trap,
                x: 30,
                y: 40,
                width: 12,
                height: 16,
                triggerX: 34,
                triggerY: 48,
                triggerWidth: 2,
                triggerHeight: 2,
                animationFrames: 20
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
                "A horizontally flipped NXLV entrance did not spawn left-facing lemmings.")
    try require(simulation.configuration.entrances.first?.traits.contains(.floater) == true,
                "NXLV entrance trait was not converted.")
    try require(simulation.configuration.zones.first?.effect == .exit,
                "Rendered exit was not converted.")
    try require(simulation.configuration.zones.contains(where: { $0.effect == .splatPad }),
                "Rendered splat pad was not converted.")
    try require(
        simulation.configuration.zones.first(where: { $0.effect == .trap })?.animationFrames == 20,
        "A rendered trap did not retain its primary-animation busy cycle."
    )
    try require(simulation.skills[.builder] == .finite(3), "Finite NXLV skill supply was not converted.")
    try require(simulation.skills[.climber] == .infinite, "Infinite NXLV skill supply was not converted.")
    try require(try lemming(simulation).traits.contains(.climber),
                "NXLV preplaced trait was not converted.")
}

private func testGadgetLemmingCaps() throws {
    let text = """
    TITLE Gadget Caps
    LEMMINGS 5
    SAVE_REQUIREMENT 4
    WIDTH 64
    HEIGHT 64

    $GADGET
      STYLE default
      PIECE hatch
      X 10
      Y 8
      LEMMINGS 2
    $END

    $GADGET
      STYLE default
      PIECE exit
      X 50
      Y 40
      LEMMINGS 1
    $END
    """
    let level = try requireValue(NxlvLevel(text: text), "Gadget-cap fixture did not parse.")
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
                style: "default", piece: "hatch", effect: .entrance,
                x: 10, y: 8, width: 16, height: 16,
                triggerX: 12, triggerY: 10, triggerWidth: 1, triggerHeight: 1
            ),
            NxlvRenderedGadget(
                style: "default", piece: "exit", effect: .exit,
                x: 50, y: 40, width: 12, height: 16,
                triggerX: 52, triggerY: 45, triggerWidth: 4, triggerHeight: 3
            ),
        ]
    )
    let adapted = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
    try require(adapted.configuration.totalLemmings == 2,
                "Finite entrance capacity did not lower the CE lemming total.")
    try require(adapted.configuration.requiredToSave == 1,
                "Finite exit capacity did not lower the CE rescue target.")
    try require(adapted.configuration.entrances.first?.lemmingLimit == 2,
                "Entrance capacity was not retained.")
    try require(adapted.configuration.zones.first?.lemmingLimit == 1,
                "Exit capacity was not retained.")

    let zeroCap = NeoLemmixEntrance(
        id: 0,
        position: NeoLemmixPoint(x: 10, y: 10),
        lemmingLimit: 0
    )
    try require(zeroCap.lemmingLimit == nil, "A zero gadget cap was not treated as unlimited.")

    let finiteExit = NeoLemmixZone(
        id: 0,
        effect: .exit,
        bounds: NeoLemmixRect(x: 20, y: 40, width: 2, height: 10),
        lemmingLimit: 1
    )
    var capped = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            total: 2,
            required: 1,
            zones: [finiteExit],
            preplaced: [
                .init(position: .init(x: 20, y: 48)),
                .init(position: .init(x: 20, y: 48)),
            ]
        )
    )
    capped.tick()
    try require(capped.lemmings.filter { $0.action == .exiting }.count == 1,
                "A finite exit accepted more lemmings than its capacity.")
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
    try require(simulation.disabledZoneIDs.contains(20), "Disarmer did not disable the trap immediately.")
    simulation.run(ticks: 42)
    try require(simulation.disabledZoneIDs.contains(20), "Disarmed trap was re-enabled.")

    var convoy = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            total: 2,
            zones: [trap],
            preplaced: [
                .init(position: .init(x: 20, y: 48), traits: [.disarmer]),
                .init(position: .init(x: 18, y: 48)),
            ]
        )
    )
    convoy.run(ticks: 6)
    try require(convoy.disabledZoneIDs.contains(20), "The first lemming did not disarm the trap.")
    try require(try lemming(convoy, id: 1).removalReason != .trapped,
                "The trap caught a following lemming during the fixing animation.")
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
    try require(NeoLemmixRules.unsupportedSkills.isEmpty,
                "A current NeoLemmix skill is still marked unsupported.")
}

private func testFencer() throws {
    var wall: [NeoLemmixPoint] = []
    for x in 24...36 {
        for y in 38...48 { wall.append(.init(x: x, y: y)) }
    }
    var simulation = try walkingSimulation(
        terrain: terrain(extraSolid: wall),
        skills: [.fencer: .finite(1)]
    )
    try require(simulation.assign(skill: .fencer, to: 0).wasAssigned,
                "Fencer assignment failed.")
    try require(try lemming(simulation).action == .fencing,
                "Fencer did not enter its action.")
    try require(simulation.skills[.fencer] == .finite(0),
                "Fencer inventory was not consumed.")
    let startX = try lemming(simulation).position.x

    simulation.run(ticks: 5)
    try require(!simulation.terrain.isSolid(x: startX + 4, y: 38),
                "The highest Fencer mask span was not removed.")
    try require(!simulation.terrain.isSolid(x: startX + 6, y: 40),
                "The widest Fencer mask span was not removed.")
    try require(simulation.terrain.isSolid(x: startX + 3, y: 38),
                "The Fencer mask removed a pixel before its highest span.")
    try require(simulation.terrain.isSolid(x: startX + 7, y: 40),
                "The Fencer mask removed a pixel beyond its widest span.")

    var protectedTerrain = try terrain(
        extraSolid: wall,
        steel: [.init(x: 25, y: 38)],
        oneWay: [(.init(x: 27, y: 40), .down)]
    )
    protectedTerrain.setOneWay(.up, x: 26, y: 40)
    var protected = try walkingSimulation(
        terrain: protectedTerrain,
        skills: [.fencer: .infinite]
    )
    try require(protected.assign(skill: .fencer, to: 0).wasAssigned,
                "Protected-terrain Fencer assignment failed.")
    protected.run(ticks: 5)
    try require(protected.terrain.isSolid(x: 25, y: 38),
                "Fencer removed steel.")
    try require(protected.terrain.isSolid(x: 27, y: 40),
                "Fencer removed down one-way terrain.")
    try require(!protected.terrain.isSolid(x: 26, y: 40),
                "Up one-way terrain incorrectly stopped a Fencer.")

    var open = try walkingSimulation(skills: [.fencer: .infinite])
    try require(open.assign(skill: .fencer, to: 0).wasAssigned,
                "Open-terrain Fencer assignment failed.")
    open.run(ticks: 5)
    try require(try lemming(open).action == .walking,
                "A Fencer continued without terrain to remove.")
}

private func testLaserer() throws {
    var targetBlock: [NeoLemmixPoint] = []
    for x in 22...32 {
        for y in 34...44 { targetBlock.append(.init(x: x, y: y)) }
    }
    var simulation = try walkingSimulation(
        terrain: terrain(extraSolid: targetBlock),
        skills: [.laserer: .finite(1)]
    )
    let origin = try lemming(simulation).position
    try require(simulation.assign(skill: .laserer, to: 0).wasAssigned,
                "Laserer assignment failed.")
    simulation.tick()
    let laserer = try lemming(simulation)
    try require(laserer.action == .lasering && laserer.laserHitPoint != nil,
                "Laserer did not retain its hit point.")
    let hit = try requireValue(laserer.laserHitPoint, "Laserer hit point was missing.")
    try require(!simulation.terrain.isSolid(x: hit.x, y: hit.y - 4),
                "The top of the Laserer mask was not removed.")
    try require(!simulation.terrain.isSolid(x: hit.x + 4, y: hit.y),
                "The side of the Laserer mask was not removed.")
    try require(simulation.terrain.isSolid(x: hit.x + 4, y: hit.y - 4),
                "The Laserer mask removed a pixel outside its shape.")
    try require(simulation.skills[.laserer] == .finite(0),
                "Laserer inventory was not consumed.")
    try require(laserer.position == origin, "Laserer moved while firing.")

    var steelTerrain = try terrain(extraSolid: targetBlock)
    for point in targetBlock { steelTerrain.setSteel(true, x: point.x, y: point.y) }
    var blocked = try walkingSimulation(
        terrain: steelTerrain,
        skills: [.laserer: .infinite]
    )
    try require(blocked.assign(skill: .laserer, to: 0).wasAssigned,
                "Steel-facing Laserer assignment failed.")
    blocked.run(ticks: 10)
    try require(try lemming(blocked).action == .walking,
                "A Laserer did not stop after ten blocked ticks.")
    try require(blocked.terrain.isSolid(x: 24, y: 40),
                "Laserer removed steel.")
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

private func testSplatPadLanding() throws {
    let landing = NeoLemmixRect(x: 20, y: 48, width: 1, height: 1)
    let splat = NeoLemmixZone(id: 1, effect: .splatPad, bounds: landing)
    let antiSplat = NeoLemmixZone(id: 2, effect: .antiSplatPad, bounds: landing)
    let preplaced = NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 40))

    var forced = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(zones: [splat], preplaced: [preplaced])
    )
    for _ in 0..<5 where try lemming(forced).action == .falling { forced.tick() }
    try require(try lemming(forced).action == .splatting,
                "A splat pad did not make a short fall fatal.")

    var protected = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(zones: [splat, antiSplat], preplaced: [preplaced])
    )
    for _ in 0..<5 where try lemming(protected).action == .falling { protected.tick() }
    try require(try lemming(protected).action == .walking,
                "An anti-splat pad did not override a splat pad at the landing point.")

    let deepLanding = NeoLemmixRect(x: 20, y: 100, width: 1, height: 1)
    var longFall = try NeoLemmixSimulation(
        terrain: terrain(height: 128, floorY: 100),
        configuration: configuration(
            zones: [NeoLemmixZone(id: 3, effect: .antiSplatPad, bounds: deepLanding)],
            preplaced: [NeoLemmixPreplacedLemming(position: NeoLemmixPoint(x: 20, y: 20))]
        )
    )
    for _ in 0..<40 where try lemming(longFall).action == .falling { longFall.tick() }
    try require(try lemming(longFall).action == .walking,
                "An anti-splat pad did not protect a long fall.")
}

private func testSkillPickup() throws {
    let pickup = NeoLemmixZone(
        id: 21,
        effect: .pickupSkill,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        skill: .builder,
        skillCount: 5
    )
    let simulation = try walkingSimulation(
        zones: [pickup], skills: [.builder: .finite(96)]
    )
    try require(simulation.skills[.builder] == .finite(99),
                "A pickup did not apply the CE finite-stock cap.")
    try require(simulation.disabledZoneIDs.contains(21),
                "A used pickup remained available.")
    try require(simulation.lastTickEvents.contains(.skillPickedUp(
        lemmingID: 0, zoneID: 21, skill: .builder, count: 5
    )), "A pickup did not report its skill and count.")
    let saved = try JSONEncoder().encode(simulation)
    let restored = try JSONDecoder().decode(NeoLemmixSimulation.self, from: saved)
    try require(restored == simulation, "A used pickup changed after save restoration.")

    let zombie = try walkingSimulation(
        zones: [pickup], traits: [.zombie], skills: [.builder: .finite(0)]
    )
    try require(zombie.skills[.builder] == .finite(0),
                "A zombie collected a pickup.")
    try require(!zombie.disabledZoneIDs.contains(21),
                "A zombie consumed a pickup.")

    let topPickup = NeoLemmixZone(
        id: 22, effect: .pickupSkill,
        bounds: pickup.bounds, skill: .miner, skillCount: 2
    )
    let overlap = try walkingSimulation(
        zones: [pickup, topPickup], skills: [.builder: .finite(0), .miner: .finite(0)]
    )
    try require(overlap.disabledZoneIDs == [22] && overlap.skills[.miner] == .finite(2),
                "The topmost overlapping pickup did not take priority.")
}

private func testTriggeredAnimationsAndSecondaries() throws {
    let busySecondary = NeoLemmixSecondaryAnimationDefinition(
        frameCount: 3,
        initialState: .pause,
        initiallyVisible: false,
        triggers: [
            NxlvRenderedAnimationTrigger(condition: .busy, state: .play, isVisible: true),
        ]
    )
    let triggered = NeoLemmixZone(
        id: 70,
        effect: .animation,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        animationFrames: 4,
        visualGadgetID: 9,
        secondaryAnimations: [busySecondary]
    )
    var simulation = try walkingSimulation(zones: [triggered])
    try require(simulation.gadgetAnimationFrames?[70] == 1,
                "A triggered animation did not enter primary frame 1.")
    try require(simulation.secondaryAnimationStates?[9] == [
        NeoLemmixSecondaryAnimationState(frame: 1, state: .play, isVisible: true),
    ], "A BUSY secondary did not become visible and advance.")

    let encoded = try JSONEncoder().encode(simulation)
    var restored = try JSONDecoder().decode(NeoLemmixSimulation.self, from: encoded)
    try require(restored == simulation,
                "A trigger-controlled secondary changed during recovery.")
    simulation.tick()
    restored.tick()
    try require(restored == simulation,
                "A recovered trigger-controlled secondary diverged.")
    simulation.run(ticks: 2)
    try require(simulation.gadgetAnimationFrames?[70] == 0,
                "A triggered animation did not return to frame zero.")
    try require(simulation.secondaryAnimationStates?[9] == [
        NeoLemmixSecondaryAnimationState(frame: 0, state: .pause, isVisible: false),
    ], "A BUSY secondary did not return to its hidden base state.")

    let exhaustedSecondary = NeoLemmixSecondaryAnimationDefinition(
        frameCount: 1,
        initialState: .pause,
        initiallyVisible: false,
        triggers: [
            NxlvRenderedAnimationTrigger(
                condition: .disabled, state: .pause, isVisible: true
            ),
            NxlvRenderedAnimationTrigger(
                condition: .busy, state: .play, isVisible: true
            ),
            NxlvRenderedAnimationTrigger(
                condition: .exhausted, state: .pause, isVisible: false
            ),
        ]
    )
    let once = NeoLemmixZone(
        id: 71,
        effect: .animationOnce,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        animationFrames: 4,
        visualGadgetID: 10,
        secondaryAnimations: [exhaustedSecondary]
    )
    var oneShot = try walkingSimulation(zones: [once])
    try require(oneShot.disabledZoneIDs.contains(71),
                "ANIMATIONONCE remained triggerable after activation.")
    try require(oneShot.gadgetAnimationFrames?[71] == 2,
                "ANIMATIONONCE did not advance from its CE frame-one idle state.")
    try require(oneShot.secondaryAnimationStates?[10]?.first?.state == .play,
                "The later BUSY trigger did not override DISABLED while ANIMATIONONCE played.")
    oneShot.run(ticks: 2)
    try require(oneShot.gadgetAnimationFrames?[71] == 0,
                "ANIMATIONONCE did not settle on exhausted frame zero.")
    try require(oneShot.secondaryAnimationStates?[10]?.first?.isVisible == false,
                "The later EXHAUSTED trigger did not override the other one-shot states.")
}

private func testLockedExitButtons() throws {
    let first = NeoLemmixZone(
        id: 30, effect: .unlockButton,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1)
    )
    let second = NeoLemmixZone(
        id: 31, effect: .unlockButton,
        bounds: NeoLemmixRect(x: 23, y: 48, width: 1, height: 1)
    )
    let exit = NeoLemmixZone(
        id: 32, effect: .lockedExit,
        bounds: NeoLemmixRect(x: 22, y: 48, width: 3, height: 1)
    )
    var simulation = try walkingSimulation(zones: [first, second, exit])
    try require(simulation.disabledZoneIDs == [30], "The first button was not consumed.")
    simulation.tick()
    try require(try lemming(simulation).action == .walking,
                "The locked exit accepted a lemming before all buttons were pressed.")
    let restored = try JSONDecoder().decode(
        NeoLemmixSimulation.self, from: JSONEncoder().encode(simulation)
    )
    try require(restored == simulation, "Button state changed after save restoration.")
    let events = simulation.tick()
    try require(events.contains(.buttonPressed(lemmingID: 0, zoneID: 31)),
                "The second button did not activate.")
    try require(try lemming(simulation).action == .exiting,
                "The final button did not unlock the exit on the same tick.")

    let zombie = try walkingSimulation(zones: [first], traits: [.zombie])
    try require(zombie.disabledZoneIDs.isEmpty, "A zombie pressed an exit button.")

    var noButtons = try walkingSimulation(zones: [exit])
    noButtons.tick()
    try require(try lemming(noButtons).action == .exiting,
                "A locked exit with no buttons did not start open.")

    let animatedButton = NeoLemmixZone(
        id: 33, effect: .unlockButton,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        animationFrames: 4
    )
    let animatedExit = NeoLemmixZone(
        id: 34, effect: .lockedExit,
        bounds: NeoLemmixRect(x: 80, y: 48, width: 1, height: 1),
        animationFrames: 4
    )
    var animated = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(zones: [animatedButton, animatedExit])
    )
    try require(animated.gadgetAnimationFrames == [33: 1, 34: 1],
                "Buttons and locked exits did not start on CE frame 1.")
    animated.tick()
    try require(animated.gadgetAnimationFrames == [33: 2, 34: 2],
                "The press tick did not advance button and exit animations to frame 2.")
    let midAnimation = try JSONDecoder().decode(
        NeoLemmixSimulation.self, from: JSONEncoder().encode(animated)
    )
    try require(midAnimation == animated,
                "A gadget transition changed after save restoration.")
    animated.tick()
    try require(animated.gadgetAnimationFrames == [33: 3, 34: 3],
                "Button and exit animations did not advance to frame 3.")
    animated.tick()
    try require(animated.gadgetAnimationFrames == [33: 0, 34: 0],
                "Button and exit animations did not settle permanently on frame 0.")
}

private func testForceFieldsAndSplitter() throws {
    let force = NeoLemmixZone(
        id: 40,
        effect: .forceRight,
        bounds: NeoLemmixRect(x: 19, y: 48, width: 1, height: 1)
    )
    let forced = try walkingSimulation(zones: [force], direction: .left)
    try require(try lemming(forced).direction == .right,
                "A right force field did not turn a left-facing lemming.")

    let jumpForce = NeoLemmixZone(
        id: 42,
        effect: .forceRight,
        bounds: NeoLemmixRect(x: 13, y: 0, width: 2, height: 100)
    )
    var jumper = try walkingSimulation(zones: [jumpForce], direction: .left)
    try require(jumper.assign(skill: .jumper, to: 0).wasAssigned,
                "Jumper assignment failed before the force-field check.")
    jumper.run(ticks: 3)
    let turnedJumper = try lemming(jumper)
    try require(turnedJumper.direction == .right && turnedJumper.position.x > 13,
                "A force field did not turn a Jumper before its next microstep.")

    let splitter = NeoLemmixZone(
        id: 41,
        effect: .splitter,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        direction: .left
    )
    let preplaced = [
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
    ]
    var split = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, zones: [splitter], preplaced: preplaced)
    )
    split.tick()
    try require(try lemming(split, id: 0).direction == .left,
                "The splitter did not use its initial direction.")
    try require(try lemming(split, id: 1).direction == .right,
                "The splitter did not alternate its direction.")
    try require(split.splitterDirections?[41] == .left,
                "The splitter did not retain its next direction.")
    let restored = try JSONDecoder().decode(
        NeoLemmixSimulation.self, from: JSONEncoder().encode(split)
    )
    try require(restored == split, "Splitter state changed after save restoration.")
}

private func testTeleporter() throws {
    let teleporter = NeoLemmixZone(
        id: 50,
        effect: .teleporter,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        pairing: 7,
        flipsLemming: true,
        animationFrames: 2
    )
    let receiver = NeoLemmixZone(
        id: 51,
        effect: .receiver,
        bounds: NeoLemmixRect(x: 70, y: 48, width: 2, height: 2),
        pairing: 7,
        animationFrames: 2
    )
    var simulation = try walkingSimulation(zones: [teleporter, receiver])
    try require(try lemming(simulation).action == .teleporting,
                "A teleporter did not hide its lemming.")
    try require(try lemming(simulation).direction == .left,
                "A flipped teleporter did not turn its lemming.")
    try require(simulation.gadgetAnimationFrames?[50] == 1
                && simulation.gadgetAnimationFrames?[51] == 0,
                "A teleporter did not begin before its receiver.")
    simulation.tick()
    try require(simulation.gadgetAnimationFrames?[50] == 0
                && simulation.gadgetAnimationFrames?[51] == 0,
                "A teleporter did not hand its lemming to the receiver at frame completion.")
    try require(try lemming(simulation).position == .init(x: 70, y: 48),
                "A hidden lemming did not move at the teleporter transfer frame.")
    simulation.tick()
    try require(simulation.gadgetAnimationFrames?[51] == 1,
                "A receiver did not start on the tick after teleporter transfer.")
    simulation.tick()
    let arrived = try lemming(simulation)
    try require(arrived.action == .walking,
                "A receiver did not return control after its animation delay.")
    try require(arrived.position == .init(x: 69, y: 48),
                "A receiver did not resume walking from its trigger origin.")

    let earlierReceiver = NeoLemmixZone(
        id: 49,
        effect: .receiver,
        bounds: NeoLemmixRect(x: 70, y: 48, width: 2, height: 2),
        pairing: 7,
        animationFrames: 2
    )
    var reversedOrder = try walkingSimulation(zones: [earlierReceiver, teleporter])
    reversedOrder.tick()
    try require(reversedOrder.gadgetAnimationFrames?[49] == 1
                && lemming(reversedOrder).action == .teleporting,
                "An earlier receiver did not advance on the transfer tick.")
    reversedOrder.tick()
    try require(try lemming(reversedOrder).action == .walking,
                "An earlier receiver did not release one tick sooner.")

    let zeroKeyTeleporter = NeoLemmixZone(
        id: 54,
        effect: .teleporter,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        pairing: 9,
        animationFrames: 2,
        keyFrame: 0
    )
    let zeroKeyReceiver = NeoLemmixZone(
        id: 55,
        effect: .receiver,
        bounds: NeoLemmixRect(x: 70, y: 48, width: 2, height: 2),
        pairing: 9,
        animationFrames: 2,
        keyFrame: 0
    )
    var zeroKey = try walkingSimulation(zones: [zeroKeyTeleporter, zeroKeyReceiver])
    try require(try lemming(zeroKey).position != .init(x: 70, y: 48),
                "KEY_FRAME 0 transferred before the teleporter animation finished.")
    zeroKey.tick()
    try require(try lemming(zeroKey).position == .init(x: 70, y: 48)
                && lemming(zeroKey).action == .teleporting,
                "KEY_FRAME 0 did not transfer at the end of the teleporter animation.")
    zeroKey.tick()
    try require(try lemming(zeroKey).action == .teleporting,
                "KEY_FRAME 0 released before the receiver animation finished.")
    zeroKey.tick()
    try require(try lemming(zeroKey).action == .walking,
                "KEY_FRAME 0 did not release after the receiver animation.")

    let restored = try JSONDecoder().decode(
        NeoLemmixSimulation.self,
        from: JSONEncoder().encode(try walkingSimulation(zones: [teleporter, receiver]))
    )
    try require(try lemming(restored).action == .teleporting,
                "Save restoration lost an in-flight teleport.")

    let constructiveTeleporter = NeoLemmixZone(
        id: 56,
        effect: .teleporter,
        bounds: NeoLemmixRect(x: 22, y: 48, width: 1, height: 1),
        pairing: 10,
        animationFrames: 2
    )
    let constructiveReceiver = NeoLemmixZone(
        id: 57,
        effect: .receiver,
        bounds: NeoLemmixRect(x: 70, y: 48, width: 2, height: 2),
        pairing: 10,
        animationFrames: 2
    )
    let bridgeFloor = (0...21).map { NeoLemmixPoint(x: $0, y: 48) }
        + (70..<128).map { NeoLemmixPoint(x: $0, y: 48) }
    var constructive = try walkingSimulation(
        terrain: terrain(floorY: nil, extraSolid: bridgeFloor),
        zones: [constructiveTeleporter, constructiveReceiver]
    )
    try require(constructive.assign(skill: .platformer, to: 0).wasAssigned,
                "Platformer assignment failed before the teleport check.")
    for _ in 0..<40 {
        if try lemming(constructive).action == .teleporting { break }
        constructive.tick()
    }
    let hiddenConstructor = try lemming(constructive)
    try require(hiddenConstructor.action == .teleporting
                && hiddenConstructor.teleportReturnBricksRemaining != nil,
                "The teleporter did not retain the Platformer's brick count.")
    for _ in 0..<8 {
        if try lemming(constructive).action != .teleporting { break }
        constructive.tick()
    }
    let resumedConstructor = try lemming(constructive)
    try require(resumedConstructor.action == .platforming
                && resumedConstructor.bricksRemaining <= hiddenConstructor.teleportReturnBricksRemaining!
                && resumedConstructor.bricksRemaining >= hiddenConstructor.teleportReturnBricksRemaining! - 1
                && resumedConstructor.animationFrame == (hiddenConstructor.teleportReturnAnimationFrame! + 1) % 16,
                "The receiver restarted an active Platformer instead of resuming it.")

    let pair = [
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
        NeoLemmixPreplacedLemming(position: .init(x: 20, y: 48)),
    ]
    var occupied = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(
            total: 2,
            zones: [teleporter, receiver],
            preplaced: pair
        )
    )
    occupied.tick()
    try require(occupied.lemmings.filter { $0.action == .teleporting }.count == 1,
                "A busy teleporter accepted more than one lemming.")
    try require(occupied.lemmings.filter { $0.action == .walking }.count == 1,
                "A busy teleporter did not let the next lemming pass.")

    let instantTeleporter = NeoLemmixZone(
        id: 52,
        effect: .teleporter,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        pairing: 8,
        animationFrames: 1
    )
    let instantReceiver = NeoLemmixZone(
        id: 53,
        effect: .receiver,
        bounds: NeoLemmixRect(x: 80, y: 48, width: 1, height: 1),
        pairing: 8,
        animationFrames: 1
    )
    var instant = try walkingSimulation(zones: [instantTeleporter, instantReceiver])
    let instantTransferred = try lemming(instant)
    try require(instantTransferred.action == .teleporting
                && instantTransferred.position == .init(x: 80, y: 48),
                "A one-frame teleporter did not transfer on its trigger tick.")
    instant.tick()
    try require(try lemming(instant).action == .walking,
                "A one-frame receiver did not release on the next tick.")
}

private func testUpdraftAndZombieInfection() throws {
    let updraft = NeoLemmixZone(
        id: 60,
        effect: .updraft,
        bounds: NeoLemmixRect(x: 19, y: 10, width: 3, height: 39)
    )
    let falling = NeoLemmixPreplacedLemming(position: .init(x: 20, y: 20))
    var lifted = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(zones: [updraft], preplaced: [falling])
    )
    lifted.tick()
    try require(try lemming(lifted).position.y == 22,
                "An updraft did not reduce falling speed to two pixels.")
    try require(try lemming(lifted).fallDistance == 0,
                "An updraft did not reset splat distance.")
    lifted.run(ticks: 30)
    try require(try lemming(lifted).action == .walking,
                "A fall through an updraft still splatted.")

    let pair = [
        NeoLemmixPreplacedLemming(
            position: .init(x: 20, y: 48),
            direction: .right,
            traits: [.zombie]
        ),
        NeoLemmixPreplacedLemming(position: .init(x: 21, y: 48), direction: .right),
    ]
    var infected = try NeoLemmixSimulation(
        terrain: terrain(),
        configuration: configuration(total: 2, preplaced: pair)
    )
    infected.tick()
    try require(try lemming(infected, id: 1).traits.contains(.zombie),
                "A nearby zombie did not infect a normal lemming.")
}

private func testStateChangers() throws {
    let bounds = NeoLemmixRect(x: 21, y: 48, width: 1, height: 1)
    let neutralized = try walkingSimulation(zones: [
        NeoLemmixZone(id: 70, effect: .neutralizer, bounds: bounds),
    ])
    try require(try lemming(neutralized).traits.contains(.neutral),
                "A neutralizer did not make a lemming neutral.")

    let deneutralized = try walkingSimulation(
        zones: [NeoLemmixZone(id: 71, effect: .deneutralizer, bounds: bounds)],
        traits: [.neutral]
    )
    try require(!lemming(deneutralized).traits.contains(.neutral),
                "A deneutralizer did not restore a neutral lemming.")

    let added = try walkingSimulation(zones: [
        NeoLemmixZone(id: 72, effect: .addSkill, bounds: bounds, skill: .climber),
    ])
    try require(try lemming(added).traits.contains(.climber),
                "A skill-adder did not grant its permanent skill.")

    let removed = try walkingSimulation(
        zones: [NeoLemmixZone(id: 73, effect: .removeSkills, bounds: bounds)],
        traits: [.slider, .climber, .swimmer, .disarmer]
    )
    let remaining = try lemming(removed).traits
    try require(remaining.isDisjoint(with: [.slider, .climber, .swimmer, .disarmer]),
                "A skill-remover left a permanent skill assigned.")
}

private func testPortals() throws {
    let source = NeoLemmixZone(
        id: 80,
        effect: .portal,
        bounds: NeoLemmixRect(x: 21, y: 48, width: 1, height: 1),
        pairing: 9
    )
    let destination = NeoLemmixZone(
        id: 81,
        effect: .portal,
        bounds: NeoLemmixRect(x: 70, y: 44, width: 5, height: 5),
        pairing: 9
    )
    let overlappingExit = NeoLemmixZone(
        id: 82,
        effect: .exit,
        bounds: source.bounds
    )
    var simulation = try walkingSimulation(zones: [overlappingExit, source, destination])
    try require(try lemming(simulation).portalWarpFrame == 1,
                "A portal did not start its warp sequence.")
    try require(try lemming(simulation).action != .exiting,
                "An overlapping exit ran before the CE portal trigger.")
    simulation.run(ticks: 3)
    try require(try lemming(simulation).position == .init(x: 72, y: 48),
                "A portal did not use the destination centre and bottom.")
    try require(try lemming(simulation).portalWarpFrame == 4,
                "A portal moved on the wrong warp frame.")
    simulation.run(ticks: 3)
    try require(try lemming(simulation).portalWarpFrame == nil,
                "A portal did not release its lemming on frame seven.")
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
    ("multiple entrance order", testMultipleEntranceOrder),
    ("CE lemming render order", testRenderOrder),
    ("preplaced traits and core movement", testPreplacedTraitsAndCoreMovement),
    ("permanent skills", testPermanentSkillAssignments),
    ("walker, jumper, and shimmier", testWalkerJumperAndShimmier),
    ("blocker and constructive skills", testBlockerAndConstructiveSkills),
    ("destructive skills and materials", testDestructiveSkillsAndMaterials),
    ("bomber and stoner", testBomberAndStoner),
    ("swimming and hazards", testSwimmingAndHazards),
    ("NXLV adapter", testNxlvAdapter),
    ("gadget lemming caps", testGadgetLemmingCaps),
    ("disarmer", testDisarmer),
    ("cloner", testCloner),
    ("fencer", testFencer),
    ("laserer", testLaserer),
    ("unsupported skill diagnostics", testUnsupportedSkillsAreExplicit),
    ("replay order and inventory", testReplayOrderAndInventory),
    ("splat pad landing", testSplatPadLanding),
    ("skill pickup", testSkillPickup),
    ("triggered animations and secondaries", testTriggeredAnimationsAndSecondaries),
    ("locked exits and buttons", testLockedExitButtons),
    ("force fields and splitter", testForceFieldsAndSplitter),
    ("teleporter", testTeleporter),
    ("updraft and zombie infection", testUpdraftAndZombieInfection),
    ("state changers", testStateChangers),
    ("portals", testPortals),
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
            + "21 implemented skills, 0 explicit unsupported skills."
    )
} catch {
    fputs("NeoLemmix simulation test failed: \(error)\n", stderr)
    exit(1)
}
