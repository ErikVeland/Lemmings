import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
    }
}

// The planted level must be proven before a search result on it means anything.
func testPlantedLevel() throws {
    var passive = try fixture(wall: true)
    while !passive.isComplete { passive.step() }
    check(passive.saved == 0, "The synthetic wall level saves \(passive.saved) lemmings without input")
    var planted = try fixture(wall: true)
    let basher = planted.configuration.skills.firstIndex(of: .basher)!
    while planted.tick < 62 { planted.step() }
    check(planted.assign(slot: basher, to: 0), "The planted basher assignment was refused")
    while !planted.isComplete { planted.step() }
    check(planted.saved == 3, "The planted basher route saved \(planted.saved) of 3")
    print("PASS synthetic wall level: 0 of 3 without input, 3 of 3 with a basher on tick 62")
}
try testPlantedLevel()

func testWallAheadFiresInsideBasherWindow() throws {
    var game = try fixture(wall: true)
    var detector = DecisionDetector()
    var found: (tick: Int, decision: Decision)?
    while !game.isComplete && found == nil {
        game.step()
        if let decision = detector.update(TickObservation(game)), decision.trigger == .wallAhead {
            found = (game.tick, decision)
        }
    }
    check(found.map { (60...67).contains($0.tick) && $0.decision.lemmings.first == 0 } == true,
          "Wall ahead fired as \(String(describing: found)), expected lemming 0 inside ticks 60...67")
    print("PASS wall ahead fires on tick \(found?.tick ?? -1) for lemming 0, inside the basher window")
}
try testWallAheadFiresInsideBasherWindow()

func testNoTerrainTriggersOnFlatGround() throws {
    var game = try fixture(wall: false)
    var detector = DecisionDetector()
    var fired: [DecisionTrigger] = []
    while !game.isComplete {
        game.step()
        if let decision = detector.update(TickObservation(game)) { fired.append(decision.trigger) }
    }
    check(!fired.contains(.edgeAhead) && !fired.contains(.wallAhead), "Flat ground fired \(fired)")
    print("PASS flat ground fires no wall or edge trigger (other decisions: \(fired.count))")
}
try testNoTerrainTriggersOnFlatGround()

func testLocationKeys() {
    func lemming(_ id: Int, x: Int, wall: Bool = false, direction: Int = 1) -> LemmingObservation {
        LemmingObservation(id: id, x: x, y: 64, direction: direction, state: .walking, wallAhead: wall, edgeAhead: false)
    }
    var walls = DecisionDetector()
    let first = walls.update(TickObservation(tick: 10, lemmings: [lemming(0, x: 40, wall: true)], nearestToExit: 0))
    let sameWall = walls.update(TickObservation(tick: 20, lemmings: [lemming(1, x: 41, wall: true)], nearestToExit: 1))
    let otherWall = walls.update(TickObservation(tick: 30, lemmings: [lemming(2, x: 200, wall: true)], nearestToExit: 2))
    let laterSameWall = walls.update(TickObservation(tick: 170, lemmings: [lemming(3, x: 40, wall: true)], nearestToExit: 3))
    check(first == Decision(trigger: .wallAhead, lemmings: [0]), "The first wall did not fire for lemming 0")
    check(sameWall == nil, "A second lemming at the same wall fired again inside the re-fire window")
    check(otherWall == Decision(trigger: .wallAhead, lemmings: [2]), "A wall at another location did not fire")
    check(laterSameWall == Decision(trigger: .wallAhead, lemmings: [3]), "The same wall did not fire again after the re-fire window")

    var quiet = DecisionDetector()
    var fallback: (tick: Int, decision: Decision)?
    for tick in 1...200 where fallback == nil {
        if let decision = quiet.update(TickObservation(tick: tick, lemmings: [lemming(9, x: 100)], nearestToExit: 9)) {
            fallback = (tick, decision)
        }
    }
    check(fallback?.tick == 150 && fallback?.decision == Decision(trigger: .fallback, lemmings: [9]),
          "Fallback fired as \(String(describing: fallback)), expected tick 150 offering lemming 9")

    var turns = DecisionDetector()
    _ = turns.update(TickObservation(tick: 1, lemmings: [lemming(4, x: 80, direction: 1)], nearestToExit: 4))
    let turned = turns.update(TickObservation(tick: 2, lemmings: [lemming(4, x: 80, direction: -1)], nearestToExit: 4))
    check(turned == Decision(trigger: .turn, lemmings: [4]), "A turn did not fire for the lemming that turned")

    var crowd = DecisionDetector()
    let many = crowd.update(TickObservation(tick: 5, lemmings: (0..<6).map { lemming($0, x: 400 + 16 * $0, wall: true) }, nearestToExit: 0))
    check(many == Decision(trigger: .wallAhead, lemmings: [0, 1, 2]), "Candidates were not capped at three in id order")
    print("PASS location keys, re-fire window, fallback lemming, turns and the three lemming cap")
}
testLocationKeys()

func testActions() throws {
    var game = try fixture(wall: true)
    while game.tick < 62 { game.step() }
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    let list = actions(in: game, candidates: [0, 0], bounds: bounds)
    let basher = game.configuration.skills.firstIndex(of: .basher)!
    check(list.first == .wait, "Wait is not the first action")
    check(list.contains(.assign(slot: basher, lemming: 0)), "The basher assignment is missing at the wall")
    check(Set(list).count == list.count, "Repeated candidates produced repeated actions")
    let aimed = list.compactMap { action -> (Int, Int)? in
        if case let .aimedAssign(_, _, x, y) = action { return (x, y) }
        return nil
    }
    check(aimed.count <= 10, "The roper produced \(aimed.count) aim targets, expected at most 10")
    check(aimed.allSatisfy { bounds.x.contains($0.0) && bounds.y.contains($0.1) }, "An aim target lies outside the witness bounds")
    let roper = game.configuration.skills.firstIndex(of: .roper)!
    let recorded = record(.aimedAssign(slot: roper, lemming: 0, x: 10, y: 20), tick: 62, skills: game.configuration.skills)
    check(recorded.inputs.count == 1 && recorded.pointers.count == 1 && recorded.pointers[0].tick == 62
          && recorded.pointers[0].x == 10 && !recorded.pointers[0].fan,
          "An aimed assignment did not record one input and one held pointer")
    check(record(.wait, tick: 62, skills: game.configuration.skills).inputs.isEmpty, "Wait recorded input")
    print("PASS actions: wait first, basher at the wall, bounded roper aim, no repeats")
}
try testActions()

func testScoring() throws {
    let base = Score(saved: 1, remaining: 50, distance: 100, inputs: 5, fingerprint: "b")
    check(base < Score(saved: 2, remaining: 0, distance: 9999, inputs: 99, fingerprint: "a"), "More saved lemmings did not rank higher")
    check(base < Score(saved: 1, remaining: 51, distance: 9999, inputs: 99, fingerprint: "a"), "Fewer losses did not rank higher")
    check(base < Score(saved: 1, remaining: 50, distance: 99, inputs: 99, fingerprint: "a"), "A shorter crowd distance did not rank higher")
    check(base < Score(saved: 1, remaining: 50, distance: 100, inputs: 4, fingerprint: "c"), "Fewer inputs did not rank higher")
    check(Score(saved: 1, remaining: 50, distance: 100, inputs: 5, fingerprint: "c") < base, "The fingerprint tie break is not fixed")

    let game = try fixture(wall: true)
    func candidate(inputs: Int, pointerX: Int?) -> Candidate {
        Candidate(game: game, cursor: Lemmings2InputCursor(),
                  inputs: Array(repeating: Lemmings2ReplayWitness.Input(tick: 0, lemming: 0, skill: 1), count: inputs),
                  pointers: pointerX.map { [Lemmings2ReplayWitness.Pointer(tick: 0, x: $0, y: 0, fanX: $0, fanY: 0, fan: false)] } ?? [],
                  depth: 0, fingerprint: "same", detector: DecisionDetector(), decision: nil)
    }
    let merged = mergeByFingerprint([candidate(inputs: 3, pointerX: nil), candidate(inputs: 1, pointerX: nil)])
    check(merged.count == 1 && merged[0].inputs.count == 1, "The merge did not keep the shorter route")
    let aims = mergeByFingerprint([candidate(inputs: 1, pointerX: 10), candidate(inputs: 1, pointerX: 20)])
    check(aims.count == 2, "States that differ only in the held pointer were merged")
    let first = aims.map { $0.pointers[0].x }
    let second = mergeByFingerprint([candidate(inputs: 1, pointerX: 20), candidate(inputs: 1, pointerX: 10)]).map { $0.pointers[0].x }
    check(first == second, "The merge order depends on input order")
    print("PASS scoring order, fixed tie break and fingerprint merge")
}
try testScoring()

func testPlantedRouteIsFound() throws {
    let game = try fixture(wall: true)
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    let report = search(from: game, bounds: bounds, limits: SearchLimits(beamWidth: 16, maxDepth: 6, budgetSeconds: 120))
    guard let best = report.best else {
        check(false, "The search found no winning route on the planted level"); return
    }
    check(best.game.saved == 3, "The search saved \(best.game.saved) of 3 on the planted level, expected the crowd route")
    // Replay the found input from a fresh runtime through the shared cursor.
    var replay = try fixture(wall: true)
    var cursor = Lemmings2InputCursor()
    while !replay.isComplete {
        try cursor.apply(inputsAt: &replay, inputs: best.inputs, pointers: best.pointers)
        replay.step()
    }
    check(replay.saved == 3 && replay.tick == best.game.tick && replay.stateFingerprint == best.game.stateFingerprint,
          "The found route did not replay to the same state")
    print("PASS search finds the planted crowd route: 3 of 3 in \(best.game.tick) ticks, \(best.inputs.count) inputs, \(report.expanded) nodes")
}
try testPlantedRouteIsFound()
