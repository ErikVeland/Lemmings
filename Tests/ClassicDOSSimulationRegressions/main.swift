import Foundation
import NxlvKit

private struct RegressionFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw RegressionFailure(description: message()) }
}

private func emptyTerrain(width: Int = 64, height: Int = 512) throws -> ClassicDOSTerrain {
    let pixelCount = width * height
    return try ClassicDOSTerrain(
        width: width,
        height: height,
        solidMask: Data(repeating: 0, count: pixelCount),
        steelMask: Data(repeating: 0, count: pixelCount)
    )
}

private func floorTerrain(width: Int = 192, height: Int = 96, floorY: Int = 40) throws -> ClassicDOSTerrain {
    var solid = Data(repeating: 0, count: width * height)
    for x in 0..<width {
        solid[solid.startIndex + floorY * width + x] = 1
    }
    return try ClassicDOSTerrain(
        width: width,
        height: height,
        solidMask: solid,
        steelMask: Data(repeating: 0, count: width * height)
    )
}

private func configuration(
    totalLemmings: Int,
    releaseRate: Int,
    entrances: [ClassicDOSPoint],
    triggers: [ClassicDOSTrigger] = [],
    skills: [ClassicSkill: Int] = [:],
    maximumX: Int = 63,
    maximumY: Int = 511
) -> ClassicDOSConfiguration {
    ClassicDOSConfiguration(
        totalLemmings: totalLemmings,
        requiredToSave: 0,
        timeLimitTicks: nil,
        initialReleaseRate: releaseRate,
        entrances: entrances,
        triggers: triggers,
        initialSkills: skills,
        maximumX: maximumX,
        maximumY: maximumY
    )
}

private func hatchEvents(in events: [ClassicDOSEvent]) -> [(id: Int, entrance: Int)] {
    events.compactMap { event in
        guard case let .hatched(lemmingID, entranceIndex) = event else { return nil }
        return (lemmingID, entranceIndex)
    }
}

private func testReleaseIntervals() throws {
    let expected = [1: 53, 2: 52, 98: 4, 99: 4]
    for releaseRate in expected.keys.sorted() {
        let expectedInterval = try requireValue(expected[releaseRate], "missing release-rate vector")
        try require(
            ClassicDOSRules.releaseInterval(for: releaseRate) == expectedInterval,
            "RR\(releaseRate) interval was not \(expectedInterval)"
        )

        var simulation = try ClassicDOSSimulation(
            terrain: emptyTerrain(),
            configuration: configuration(
                totalLemmings: 3,
                releaseRate: releaseRate,
                entrances: [ClassicDOSPoint(x: 20, y: 0)]
            )
        )
        var hatchTicks: [Int] = []
        while hatchTicks.count < 3, simulation.tickCount < 220 {
            let events = simulation.tick()
            hatchTicks.append(contentsOf: hatchEvents(in: events).map { _ in simulation.tickCount })
        }
        try require(hatchTicks.count == 3, "RR\(releaseRate) did not release three lemmings")
        try require(hatchTicks[0] == 54, "RR\(releaseRate) first release was tick \(hatchTicks[0]), not 54")
        try require(
            hatchTicks[1] - hatchTicks[0] == expectedInterval &&
                hatchTicks[2] - hatchTicks[1] == expectedInterval,
            "RR\(releaseRate) observed intervals were not \(expectedInterval)"
        )
    }
}

private func testHatchOrder() throws {
    let expectedOrders = [
        1: [0, 0, 0, 0],
        2: [0, 1, 1, 0],
        3: [0, 1, 2, 1],
        4: [0, 1, 2, 3],
    ]
    for entranceCount in expectedOrders.keys.sorted() {
        try require(
            ClassicDOSRules.hatchOrder(entranceCount: entranceCount) == expectedOrders[entranceCount],
            "\(entranceCount)-entrance hatch table mismatch"
        )
    }

    let entrances = [
        ClassicDOSPoint(x: 10, y: 0),
        ClassicDOSPoint(x: 20, y: 0),
    ]
    var simulation = try ClassicDOSSimulation(
        terrain: emptyTerrain(),
        configuration: configuration(
            totalLemmings: 8,
            releaseRate: 99,
            entrances: entrances
        )
    )
    var observed: [Int] = []
    while observed.count < 8 {
        observed.append(contentsOf: hatchEvents(in: simulation.tick()).map(\.entrance))
    }
    try require(observed == [0, 1, 1, 0, 0, 1, 1, 0], "two-hatch release sequence mismatch")
}

private func testEntranceOpeningAndFirstSpawn() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: emptyTerrain(),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 20, y: 0)]
        )
    )

    for tick in 1...54 {
        let events = simulation.tick()
        let opened = events.contains { event in
            if case .entrancesOpened = event { return true }
            return false
        }
        let hatched = !hatchEvents(in: events).isEmpty
        try require(opened == (tick == 35), "entrance-open event mismatch at tick \(tick)")
        try require(hatched == (tick == 54), "first-hatch event mismatch at tick \(tick)")
        if tick < 35 {
            try require(!simulation.entrancesAreOpen, "entrances opened before tick 35")
        }
    }
    try require(simulation.entrancesAreOpen, "entrances were closed after tick 35")
    try require(simulation.releasedCount == 1, "first lemming was not released on tick 54")
}

private func testNoOpCommandsClearEvents() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: emptyTerrain(),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 1,
            entrances: [ClassicDOSPoint(x: 20, y: 0)]
        )
    )

    simulation.setReleaseRate(99)
    try require(
        simulation.lastTickEvents == [.releaseRateChanged(99)],
        "a changed release rate did not emit its event"
    )
    simulation.setReleaseRate(99)
    try require(
        simulation.lastTickEvents.isEmpty,
        "a no-op release-rate command retained stale events"
    )

    simulation.beginNuke()
    try require(
        simulation.lastTickEvents == [.nukeStarted],
        "the first nuke command did not emit its event"
    )
    simulation.beginNuke()
    try require(
        simulation.lastTickEvents.isEmpty,
        "a repeated nuke command retained stale events"
    )
}

private func testHalfOpenTriggerBounds() throws {
    let bounds = ClassicDOSRect(x1: 10, y1: 20, x2: 14, y2: 24)
    try require(bounds.contains(ClassicDOSPoint(x: 10, y: 20)), "top-left trigger edge was excluded")
    try require(bounds.contains(ClassicDOSPoint(x: 13, y: 23)), "last interior trigger point was excluded")
    try require(!bounds.contains(ClassicDOSPoint(x: 14, y: 23)), "right trigger edge was included")
    try require(!bounds.contains(ClassicDOSPoint(x: 13, y: 24)), "bottom trigger edge was included")
    try require(!bounds.contains(ClassicDOSPoint(x: 9, y: 20)), "point left of trigger was included")
    try require(!bounds.contains(ClassicDOSPoint(x: 10, y: 19)), "point above trigger was included")
}

private func requireValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw RegressionFailure(description: message) }
    return value
}

private func simulationWithFallDistance(
    _ fallDistance: Int,
    basedOn simulation: ClassicDOSSimulation
) throws -> ClassicDOSSimulation {
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(simulation)
    guard var root = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          var lemmings = root["lemmings"] as? [[String: Any]],
          !lemmings.isEmpty else {
        throw RegressionFailure(description: "could not inspect the Codable simulation snapshot")
    }
    lemmings[0]["action"] = ClassicDOSAction.falling.rawValue
    lemmings[0]["animationFrame"] = 0
    lemmings[0]["fallDistance"] = fallDistance
    root["lemmings"] = lemmings
    let modified = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    return try JSONDecoder().decode(ClassicDOSSimulation.self, from: modified)
}

private func testMaximumSafeFallDistance() throws {
    var seed = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 40, y: 39)],
            maximumX: 191,
            maximumY: 95
        )
    )
    while seed.tickCount < 54 { seed.tick() }
    try require(seed.lemmings.first?.action == .walking, "fall-distance seed did not land")

    var safe = try simulationWithFallDistance(60, basedOn: seed)
    var fatal = try simulationWithFallDistance(61, basedOn: seed)
    safe.tick()
    fatal.tick()
    try require(safe.lemmings.first?.action == .walking, "a 60-pixel fall splatted")
    try require(fatal.lemmings.first?.action == .splatting, "a 61-pixel fall did not splat")
}

private func filledMask(
    width: Int,
    height: Int,
    offsetX: Int = 0,
    offsetY: Int = 0,
    value: UInt8 = 1
) throws -> ClassicDOSMask {
    try ClassicDOSMask(
        width: width,
        height: height,
        offsetX: offsetX,
        offsetY: offsetY,
        pixels: Data(repeating: value, count: width * height)
    )
}

private func destructionMaskSet(explosionValue: UInt8 = 1) throws -> ClassicDOSDestructionMaskSet {
    try ClassicDOSDestructionMaskSet(
        explosion: filledMask(
            width: 16,
            height: 22,
            offsetX: -8,
            offsetY: -11,
            value: explosionValue
        ),
        bashRight: try (0..<4).map { _ in try filledMask(width: 16, height: 10) },
        bashLeft: try (0..<4).map { _ in try filledMask(width: 16, height: 10) },
        mineRight: try (0..<2).map { _ in try filledMask(width: 16, height: 13) },
        mineLeft: try (0..<2).map { _ in try filledMask(width: 16, height: 13) }
    )
}

private func encodedSubtree(_ simulation: ClassicDOSSimulation, key: String) throws -> Data {
    let encoded = try JSONEncoder().encode(simulation)
    guard let root = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          let value = root[key] else {
        throw RegressionFailure(description: "Codable simulation snapshot has no \(key) field")
    }
    return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}

private func modifiedSimulation(
    _ simulation: ClassicDOSSimulation,
    mutate: (inout [String: Any]) throws -> Void
) throws -> ClassicDOSSimulation {
    let encoded = try JSONEncoder().encode(simulation)
    guard var root = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
        throw RegressionFailure(description: "could not inspect the Codable simulation snapshot")
    }
    try mutate(&root)
    let modified = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    return try JSONDecoder().decode(ClassicDOSSimulation.self, from: modified)
}

private func modifyLemmings(
    in root: inout [String: Any],
    _ body: (inout [[String: Any]]) throws -> Void
) throws {
    guard var lemmings = root["lemmings"] as? [[String: Any]] else {
        throw RegressionFailure(description: "Codable simulation snapshot has no lemmings")
    }
    try body(&lemmings)
    root["lemmings"] = lemmings
}

private func blockerAnchor(in simulation: ClassicDOSSimulation, lemmingIndex: Int) throws -> ClassicDOSPoint? {
    let encoded = try JSONEncoder().encode(simulation)
    guard let root = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
          let lemmings = root["lemmings"] as? [[String: Any]],
          lemmings.indices.contains(lemmingIndex),
          let anchor = lemmings[lemmingIndex]["blockerAnchor"] as? [String: Any],
          let x = anchor["x"] as? Int,
          let y = anchor["y"] as? Int else {
        return nil
    }
    return ClassicDOSPoint(x: x, y: y)
}

private func testImmutableSteelAndDestructionMasks() throws {
    let width = 64
    let height = 48
    var solid = Data(repeating: 1, count: width * height)
    var steel = Data(repeating: 0, count: width * height)
    for y in 9..<31 {
        for x in 23..<39 {
            steel[steel.startIndex + y * width + x] = 1
        }
    }
    var terrain = try ClassicDOSTerrain(width: width, height: height, solidMask: solid, steelMask: steel)
    let originalSteel = terrain.steelMask
    try require(!terrain.removeSolid(x: 23, y: 9), "protected terrain was removed")
    try require(terrain.removeSolid(x: 0, y: 0), "unprotected terrain was not removed")
    try require(terrain.steelMask == originalSteel, "terrain editing changed the steel-protection mask")
    try require(terrain.addSolid(x: 0, y: 0), "removed terrain could not be restored")
    solid = terrain.solidMask

    let masks = try destructionMaskSet()
    var simulation = try ClassicDOSSimulation(
        terrain: terrain,
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 30, y: 20)],
            skills: [.blocker: 1, .bomber: 1],
            maximumX: width - 1,
            maximumY: height - 1
        ),
        destructionMasks: masks
    )
    let encodedMasksBefore = try encodedSubtree(simulation, key: "destructionMasks")
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .blocker)), "blocker replay was not queued")
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .bomber)), "bomber replay was not queued")

    var reachedExplosion = false
    var removedPixels = 0
    for _ in 0..<180 {
        for event in simulation.tick() {
            switch event {
            case let .actionChanged(_, _, action) where action == .exploding:
                reachedExplosion = true
            case let .terrainRemoved(_, _, pixelCount):
                removedPixels += pixelCount
            default:
                break
            }
        }
    }
    try require(reachedExplosion, "the protected-area bomber did not reach its explosion")
    try require(removedPixels == 0, "an explosion removed \(removedPixels) steel-protected pixels")
    try require(simulation.terrain.steelMask == originalSteel, "simulation changed the steel-protection mask")
    let encodedMasksAfter = try encodedSubtree(simulation, key: "destructionMasks")
    try require(
        encodedMasksAfter == encodedMasksBefore,
        "simulation changed its destruction masks"
    )
    for y in 9..<31 {
        for x in 23..<39 {
            try require(simulation.terrain.isSolid(x: x, y: y), "protected pixel (\(x), \(y)) was removed")
        }
    }
    try require(solid.count == width * height, "terrain fixture size changed")
}

private func testBombedBlockerOnSteelSuppressesExplosion() throws {
    let width = 96
    let height = 80
    var solid = Data(repeating: 0, count: width * height)
    for x in 0..<width { solid[40 * width + x] = 1 }
    var steel = Data(repeating: 0, count: width * height)
    steel[40 * width + 33] = 1
    let terrain = try ClassicDOSTerrain(
        width: width,
        height: height,
        solidMask: solid,
        steelMask: steel
    )
    var simulation = try ClassicDOSSimulation(
        terrain: terrain,
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            skills: [.blocker: 1, .bomber: 1],
            maximumX: width - 1,
            maximumY: height - 1
        ),
        destructionMasks: destructionMaskSet()
    )
    try require(
        simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .blocker)),
        "steel blocker command was not queued"
    )
    try require(
        simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .bomber)),
        "steel bomber command was not queued"
    )

    var removedPixels = 0
    while simulation.tickCount < 180 {
        for event in simulation.tick() {
            if case let .terrainRemoved(_, .bomber, count) = event { removedPixels += count }
        }
    }
    try require(removedPixels == 0, "a steel-centered blocker bomb removed \(removedPixels) pixels")
    try require(simulation.terrain.isSolid(x: 25, y: 40), "the suppressed mask removed adjacent terrain")
    try require(
        simulation.lemmings.first?.hasActiveBlockerField == false,
        "the exploding blocker retained its field"
    )
    let clearedAnchor = try blockerAnchor(in: simulation, lemmingIndex: 0)
    try require(clearedAnchor == nil, "the exploding blocker retained its anchor")
}

private func testBlockerCenterSuppressesAndUncoversExit() throws {
    // This checks that a blocker hides the exit under it and that clearing the
    // blocker reveals it again. The walker below steps from 39 to 40, so the
    // zone starts three pixels earlier than 40: a lemming enters an exit three
    // pixels in, and the point of interest here is the blocker at 40, not the
    // pixel the exit accepts on.
    let trigger = ClassicDOSTrigger(
        id: 7,
        effect: .exit,
        bounds: ClassicDOSRect(x1: 37, y1: 40, x2: 44, y2: 44)
    )
    var seed = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 2,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            triggers: [trigger],
            maximumX: 191,
            maximumY: 95
        )
    )
    while seed.tickCount < 58 { seed.tick() }
    seed = try modifiedSimulation(seed) { root in
        try modifyLemmings(in: &root) { lemmings in
            lemmings[0]["foot"] = ["x": 40, "y": 40]
            lemmings[0]["action"] = ClassicDOSAction.blocking.rawValue
            lemmings[0]["animationFrame"] = 0
            lemmings[0]["ownsBlockerField"] = true
            lemmings[0]["blockerAnchor"] = ["x": 40, "y": 40]
            lemmings[1]["foot"] = ["x": 39, "y": 40]
            lemmings[1]["direction"] = ClassicDOSDirection.right.rawValue
            lemmings[1]["action"] = ClassicDOSAction.walking.rawValue
            lemmings[1]["animationFrame"] = 0
        }
    }

    seed.tick()
    try require(seed.lemmings[1].action == .walking, "a blocker center leaked its underlying exit")

    var uncovered = try modifiedSimulation(seed) { root in
        try modifyLemmings(in: &root) { lemmings in
            lemmings[0]["ownsBlockerField"] = false
            lemmings[0].removeValue(forKey: "blockerAnchor")
            lemmings[1]["foot"] = ["x": 39, "y": 40]
            lemmings[1]["direction"] = ClassicDOSDirection.right.rawValue
            lemmings[1]["action"] = ClassicDOSAction.walking.rawValue
            lemmings[1]["animationFrame"] = 0
        }
    }
    uncovered.tick()
    try require(uncovered.lemmings[1].action == .exiting, "a cleared blocker did not uncover the exit")
}

private func testFallingOhNoKeepsFixedBlockerAnchor() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            skills: [.blocker: 1, .bomber: 1],
            maximumX: 191,
            maximumY: 95
        ),
        destructionMasks: destructionMaskSet(explosionValue: 0)
    )
    try require(
        simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .blocker)),
        "falling Oh-No blocker command was not queued"
    )
    try require(
        simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .bomber)),
        "falling Oh-No bomber command was not queued"
    )
    while simulation.tickCount < 55 { simulation.tick() }
    let originalAnchor = try requireValue(
        blockerAnchor(in: simulation, lemmingIndex: 0),
        "the assigned blocker had no anchor"
    )
    let emptyTerrainJSON = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(emptyTerrain(width: 192, height: 96))
    )
    simulation = try modifiedSimulation(simulation) { root in
        root["terrain"] = emptyTerrainJSON
        try modifyLemmings(in: &root) { lemmings in
            lemmings[0]["bomberCountdown"] = 1
        }
    }

    simulation.tick()
    simulation.tick()
    try require(simulation.lemmings[0].action == .ohNo, "the blocker did not enter Oh-No")
    try require(simulation.lemmings[0].foot.y > originalAnchor.y, "the Oh-No blocker did not fall")
    let fallingAnchor = try blockerAnchor(in: simulation, lemmingIndex: 0)
    try require(fallingAnchor == originalAnchor, "a falling Oh-No moved its blocker anchor")

    let checkpoint = try JSONEncoder().encode(simulation)
    var restored = try JSONDecoder().decode(ClassicDOSSimulation.self, from: checkpoint)
    try require(restored == simulation, "a falling blocker anchor changed during Codable restoration")
    for _ in 0..<30 where simulation.lemmings[0].hasActiveBlockerField {
        let events = simulation.tick()
        let restoredEvents = restored.tick()
        try require(events == restoredEvents && simulation == restored, "falling blocker continuation diverged")
    }
    try require(!simulation.lemmings[0].hasActiveBlockerField, "the exploded Oh-No retained its blocker field")
    let explodedAnchor = try blockerAnchor(in: simulation, lemmingIndex: 0)
    try require(explodedAnchor == nil, "the exploded Oh-No retained its blocker anchor")
}

private func testBlockerClearingUsesLemmingOrder() throws {
    var seed = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 2,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            maximumX: 191,
            maximumY: 95
        ),
        destructionMasks: destructionMaskSet(explosionValue: 0)
    )
    while seed.tickCount < 58 { seed.tick() }

    func setWalker(_ lemming: inout [String: Any]) {
        lemming["foot"] = ["x": 45, "y": 40]
        lemming["direction"] = ClassicDOSDirection.left.rawValue
        lemming["action"] = ClassicDOSAction.walking.rawValue
        lemming["animationFrame"] = 0
        lemming["ownsBlockerField"] = false
        lemming.removeValue(forKey: "blockerAnchor")
    }
    func setExplodingBlocker(_ lemming: inout [String: Any]) {
        lemming["foot"] = ["x": 40, "y": 40]
        lemming["direction"] = ClassicDOSDirection.right.rawValue
        lemming["action"] = ClassicDOSAction.exploding.rawValue
        lemming["animationFrame"] = 0
        lemming["ownsBlockerField"] = true
        lemming["blockerAnchor"] = ["x": 40, "y": 40]
    }

    var clearsFirst = try modifiedSimulation(seed) { root in
        try modifyLemmings(in: &root) { lemmings in
            setExplodingBlocker(&lemmings[0])
            setWalker(&lemmings[1])
        }
    }
    clearsFirst.tick()
    try require(
        clearsFirst.lemmings[1].direction == .left,
        "a later lemming saw a blocker field after the earlier owner cleared it"
    )

    var clearsLast = try modifiedSimulation(seed) { root in
        try modifyLemmings(in: &root) { lemmings in
            setWalker(&lemmings[0])
            setExplodingBlocker(&lemmings[1])
        }
    }
    clearsLast.tick()
    try require(
        clearsLast.lemmings[0].direction == .right,
        "an earlier lemming missed a blocker field that cleared later in the tick"
    )
}

private func testActiveBombedBlockerCodableContinuation() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            skills: [.blocker: 1, .bomber: 1],
            maximumX: 191,
            maximumY: 95
        ),
        destructionMasks: destructionMaskSet(explosionValue: 0)
    )
    try require(simulation.schedule(.init(tick: 55, lemmingID: 0, skill: .blocker)), "blocker was not queued")
    try require(simulation.schedule(.init(tick: 55, lemmingID: 0, skill: .bomber)), "bomber was not queued")
    while simulation.tickCount < 90 { simulation.tick() }
    try require(simulation.lemmings[0].hasActiveBlockerField, "checkpoint blocker field was inactive")
    let checkpointAnchor = try blockerAnchor(in: simulation, lemmingIndex: 0)
    try require(checkpointAnchor != nil, "checkpoint blocker anchor was absent")

    var restored = try JSONDecoder().decode(
        ClassicDOSSimulation.self,
        from: JSONEncoder().encode(simulation)
    )
    try require(restored == simulation, "active bombed blocker changed during Codable restoration")
    for tick in 1...100 {
        let events = simulation.tick()
        let restoredEvents = restored.tick()
        try require(events == restoredEvents, "bombed blocker events diverged at continuation tick \(tick)")
        try require(simulation == restored, "bombed blocker state diverged at continuation tick \(tick)")
    }
}

private func testReleaseRateZeroCanBeRestored() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: emptyTerrain(),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 0,
            entrances: [ClassicDOSPoint(x: 20, y: 0)]
        )
    )
    simulation.setReleaseRate(99)
    simulation.setReleaseRate(0)
    try require(simulation.releaseRate == 0, "an RR-0 level could not restore its initial rate")
    try require(simulation.lastTickEvents == [.releaseRateChanged(0)], "restoring RR 0 emitted wrong events")
}

/// A lemming drops into an exit at the middle of the hole, whichever way it is
/// walking.
///
/// An earlier version measured a fixed depth from the near edge of the trigger.
/// That cannot work: trigger zones are four pixels wide in most styles and
/// eight in others, and they do not sit at the middle of the exit either. The
/// same depth therefore landed centrally in one style and at the edge in
/// another, and it landed on opposite sides depending on the way the lemming
/// walked.
private func testExitTakesTheLemmingAtTheMiddle() throws {
    /// Walks a lemming in from one side and reports where it vanished.
    func entryPoint(zone: ClassicDOSRect, from startX: Int, facing: ClassicDOSDirection) throws -> Int? {
        let exitTrigger = ClassicDOSTrigger(id: 1, effect: .exit, bounds: zone)
        var simulation = try ClassicDOSSimulation(
            terrain: floorTerrain(floorY: 40),
            configuration: configuration(
                totalLemmings: 1, releaseRate: 99,
                entrances: [ClassicDOSPoint(x: 32, y: 39)],
                triggers: [exitTrigger], maximumX: 191, maximumY: 95))
        while simulation.tickCount < 58 { simulation.tick() }
        simulation = try modifiedSimulation(simulation) { root in
            try modifyLemmings(in: &root) { lemmings in
                for index in lemmings.indices {
                    lemmings[index]["foot"] = ["x": startX, "y": 40]
                    lemmings[index]["direction"] = facing.rawValue
                    lemmings[index]["action"] = ClassicDOSAction.walking.rawValue
                    lemmings[index]["animationFrame"] = 0
                }
            }
        }
        // Walk until it enters, and report the x it entered at.
        for _ in 0..<40 {
            let x = simulation.lemmings.first?.foot.x
            let entered = simulation.tick().contains {
                if case let .actionChanged(_, _, to) = $0, to == .exiting { return true }
                return false
            }
            if entered { return (x ?? 0) + facing.delta }
        }
        return nil
    }

    // A four pixel zone and an eight pixel zone, which both occur in the games.
    for zone in [
        ClassicDOSRect(x1: 20, y1: 40, x2: 24, y2: 44),
        ClassicDOSRect(x1: 20, y1: 40, x2: 28, y2: 44),
    ] {
        let middle = (zone.x1 + zone.x2) / 2
        let fromLeft = try entryPoint(zone: zone, from: zone.x1 - 6, facing: .right)
        let fromRight = try entryPoint(zone: zone, from: zone.x2 + 5, facing: .left)
        try require(
            fromLeft == middle,
            "walking right, the lemming entered at \(fromLeft.map(String.init) ?? "never") "
                + "rather than the middle at \(middle)")
        try require(
            fromRight == middle,
            "walking left, the lemming entered at \(fromRight.map(String.init) ?? "never") "
                + "rather than the middle at \(middle)")
    }

    // A zone one pixel wide still has to accept a lemming.
    let narrow = ClassicDOSRect(x1: 20, y1: 40, x2: 21, y2: 44)
    let narrowEntry = try entryPoint(zone: narrow, from: 17, facing: .right)
    try require(
        narrowEntry != nil, "a one pixel exit rejected a lemming walking into it")
    print("PASS a lemming enters an exit at its middle from either direction")
}

private func testCoolingTrapEmitsOneActivation() throws {
    let trigger = ClassicDOSTrigger(
        id: 3,
        effect: .triggeredTrap,
        bounds: ClassicDOSRect(x1: 20, y1: 40, x2: 24, y2: 44),
        trapResetTicks: 3
    )
    var simulation = try ClassicDOSSimulation(
        terrain: floorTerrain(floorY: 40),
        configuration: configuration(
            totalLemmings: 2,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            triggers: [trigger],
            maximumX: 191,
            maximumY: 95
        )
    )
    while simulation.tickCount < 58 { simulation.tick() }
    simulation = try modifiedSimulation(simulation) { root in
        try modifyLemmings(in: &root) { lemmings in
            for index in lemmings.indices {
                lemmings[index]["foot"] = ["x": 19, "y": 40]
                lemmings[index]["direction"] = ClassicDOSDirection.right.rawValue
                lemmings[index]["action"] = ClassicDOSAction.walking.rawValue
                lemmings[index]["animationFrame"] = 0
            }
        }
    }
    let events = simulation.tick()
    let activations = events.filter {
        if case .triggerActivated(_, 3, .triggeredTrap) = $0 { return true }
        return false
    }
    try require(activations.count == 1, "a cooling trap emitted \(activations.count) activation events")
    try require(simulation.lemmings[0].outcome == .lost, "the first trap target survived")
    try require(simulation.lemmings[1].outcome == .active, "the cooling trap killed the second target")
}

private func testSplatterWaterUsesZeroHorizontalVelocity() throws {
    let width = 64
    let height = 80
    var solid = Data(repeating: 0, count: width * height)
    solid[40 * width + 32] = 1
    let terrain = try ClassicDOSTerrain(
        width: width,
        height: height,
        solidMask: solid,
        steelMask: Data(repeating: 0, count: width * height)
    )
    let water = ClassicDOSTrigger(
        id: 5,
        effect: .water,
        bounds: ClassicDOSRect(x1: 28, y1: 40, x2: 36, y2: 44)
    )
    var simulation = try ClassicDOSSimulation(
        terrain: terrain,
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 20)],
            triggers: [water],
            maximumX: width - 1,
            maximumY: height - 1
        )
    )
    while simulation.tickCount < 54 { simulation.tick() }
    simulation = try modifiedSimulation(simulation) { root in
        try modifyLemmings(in: &root) { lemmings in
            lemmings[0]["foot"] = ["x": 32, "y": 39]
            lemmings[0]["direction"] = ClassicDOSDirection.right.rawValue
            lemmings[0]["action"] = ClassicDOSAction.falling.rawValue
            lemmings[0]["animationFrame"] = 0
            lemmings[0]["fallDistance"] = 61
            lemmings[0]["hasZeroHorizontalVelocity"] = false
        }
    }
    simulation.tick()
    try require(simulation.lemmings[0].action == .drowning, "the splatter did not enter water")
    let landedX = simulation.lemmings[0].foot.x
    simulation.tick()
    try require(
        simulation.lemmings[0].foot.x == landedX,
        "a splatter carried horizontal velocity into drowning"
    )
}

private func testDeterministicCodableContinuation() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: floorTerrain(),
        configuration: configuration(
            totalLemmings: 4,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            skills: [.climber: 4, .floater: 4],
            maximumX: 191,
            maximumY: 95
        )
    )
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 65, lemmingID: 0, skill: .climber)), "future climber command was not queued")
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 65, lemmingID: 1, skill: .floater)), "future floater command was not queued")
    while simulation.tickCount < 62 { simulation.tick() }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let checkpoint = try encoder.encode(simulation)
    var restored = try JSONDecoder().decode(ClassicDOSSimulation.self, from: checkpoint)
    try require(restored == simulation, "Codable round trip changed the simulation checkpoint")

    for continuationTick in 1...200 {
        let originalEvents = simulation.tick()
        let restoredEvents = restored.tick()
        try require(originalEvents == restoredEvents, "event divergence at continuation tick \(continuationTick)")
        try require(simulation == restored, "state divergence at continuation tick \(continuationTick)")
        let originalEncoding = try encoder.encode(simulation)
        let restoredEncoding = try encoder.encode(restored)
        let originalRoundTrip = try JSONDecoder().decode(ClassicDOSSimulation.self, from: originalEncoding)
        let restoredRoundTrip = try JSONDecoder().decode(ClassicDOSSimulation.self, from: restoredEncoding)
        try require(
            originalRoundTrip == restoredRoundTrip,
            "Codable-state divergence at continuation tick \(continuationTick)"
        )
    }
}

private func testReplayInsertionOrdering() throws {
    var simulation = try ClassicDOSSimulation(
        terrain: floorTerrain(),
        configuration: configuration(
            totalLemmings: 1,
            releaseRate: 99,
            entrances: [ClassicDOSPoint(x: 32, y: 39)],
            skills: [.climber: 2, .floater: 2],
            maximumX: 191,
            maximumY: 95
        )
    )
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .floater)), "first replay command was not queued")
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .climber)), "second replay command was not queued")
    try require(simulation.schedule(ClassicDOSSkillCommand(tick: 55, lemmingID: 0, skill: .floater)), "third replay command was not queued")
    try require(
        simulation.pendingSkillCommands.map(\.skill) == [.floater, .climber, .floater],
        "same-tick queued commands lost insertion order"
    )

    while simulation.tickCount < 54 { simulation.tick() }
    let events = simulation.tick()
    var skillResults: [String] = []
    for event in events {
        switch event {
        case let .skillAssigned(_, skill):
            skillResults.append("assigned:\(skill.rawValue)")
        case let .skillAssignmentRejected(_, skill, result):
            skillResults.append("rejected:\(skill.rawValue):\(result.rawValue)")
        default:
            break
        }
    }
    try require(
        skillResults == ["assigned:floater", "assigned:climber", "rejected:floater:alreadyHasSkill"],
        "same-tick replay results were \(skillResults)"
    )
    try require(simulation.pendingSkillCommands.isEmpty, "applied replay commands remained queued")
}

private struct CampaignSoakResult {
    let levels: Int
    let tickCalls: Int
    let released: Int
    let active: Int
    let saved: Int
    let lost: Int
}

private func soakOfficialCampaign(dataDirectory: URL) throws -> CampaignSoakResult {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: dataDirectory)
    try require(campaign.levels.count == 120, "official campaign has \(campaign.levels.count) levels, not 120")
    let mainDATAssets = try ClassicMainDATAssets.load(from: dataDirectory)

    var groundSets: [Int: ClassicGroundSet] = [:]
    for style in Set(campaign.levels.map(\.level.groundStyle)) {
        groundSets[style] = try ClassicGroundSet.load(style: style, from: dataDirectory)
    }
    var specialGraphics: [Int: ClassicSpecialGraphic] = [:]
    for index in Set(campaign.levels.compactMap { item in
        item.level.specialStyle == 0 ? nil : item.level.specialStyle - 1
    }) {
        specialGraphics[index] = try ClassicSpecialGraphic.load(index: index, from: dataDirectory)
    }

    var totals = CampaignSoakResult(levels: 0, tickCalls: 0, released: 0, active: 0, saved: 0, lost: 0)
    for item in campaign.levels {
        let level = item.level
        let groundSet = try requireValue(
            groundSets[level.groundStyle],
            "missing decoded ground style \(level.groundStyle)"
        )
        let specialGraphic = level.specialStyle == 0 ? nil : try requireValue(
            specialGraphics[level.specialStyle - 1],
            "missing decoded special style \(level.specialStyle - 1)"
        )
        let rendered = try ClassicLevelRenderer.render(
            level,
            groundSet: groundSet,
            specialGraphic: specialGraphic
        )
        var simulation = try ClassicDOSSimulation(
            level: level,
            renderedLevel: rendered,
            mainDATAssets: mainDATAssets
        )
        for _ in 0..<500 { simulation.tick() }

        try require(simulation.releasedCount <= level.lemmingCount, "\(item.rank) \(item.number) over-released")
        try require(
            simulation.activeCount + simulation.savedCount + simulation.lostCount == simulation.releasedCount,
            "\(item.rank) \(item.number) lemming counters are inconsistent"
        )
        try require(simulation.skills.values.allSatisfy { $0 >= 0 }, "\(item.rank) \(item.number) has a negative skill count")

        totals = CampaignSoakResult(
            levels: totals.levels + 1,
            tickCalls: totals.tickCalls + 500,
            released: totals.released + simulation.releasedCount,
            active: totals.active + simulation.activeCount,
            saved: totals.saved + simulation.savedCount,
            lost: totals.lost + simulation.lostCount
        )
    }
    return totals
}

private func run() throws {
    guard CommandLine.arguments.count == 2 else {
        throw RegressionFailure(description: "usage: ClassicDOSSimulationRegressions CLASSIC_DATA_DIRECTORY")
    }
    let dataDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

    try testReleaseIntervals()
    try testHatchOrder()
    try testEntranceOpeningAndFirstSpawn()
    try testNoOpCommandsClearEvents()
    try testHalfOpenTriggerBounds()
    try testMaximumSafeFallDistance()
    try testImmutableSteelAndDestructionMasks()
    try testBombedBlockerOnSteelSuppressesExplosion()
    try testBlockerCenterSuppressesAndUncoversExit()
    try testFallingOhNoKeepsFixedBlockerAnchor()
    try testBlockerClearingUsesLemmingOrder()
    try testActiveBombedBlockerCodableContinuation()
    try testReleaseRateZeroCanBeRestored()
    try testCoolingTrapEmitsOneActivation()
    try testExitTakesTheLemmingAtTheMiddle()
    try testSplatterWaterUsesZeroHorizontalVelocity()
    try testDeterministicCodableContinuation()
    try testReplayInsertionOrdering()
    let soak = try soakOfficialCampaign(dataDirectory: dataDirectory)

    print("Classic DOS rules: RR1=53, RR2=52, RR98=4, RR99=4; entrance tick=35; first hatch tick=54.")
    print("Classic DOS edge cases: hatch tables, half-open triggers, fall 60/61, fixed blocker overlays, trap cooldown, RR0, zero-dx splats, immutable masks, Codable continuation, and replay ordering passed.")
    print("Official campaign soak: \(soak.levels) levels, \(soak.tickCalls) tick calls, \(soak.released) released, \(soak.active) active, \(soak.saved) saved, \(soak.lost) lost.")
    print("Classic DOS simulation regressions passed.")
}

do {
    try run()
} catch {
    fputs("Classic DOS simulation regressions failed: \(error)\n", stderr)
    exit(1)
}
