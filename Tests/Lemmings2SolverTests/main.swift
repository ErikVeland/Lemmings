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
