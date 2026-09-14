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
    let recorded = events(for: .aimedAssign(slot: roper, lemming: 0, x: 10, y: 20), tick: 62, skills: game.configuration.skills)
    check(recorded.map(\.event) == [.aim(x: 10, y: 20, held: true), .fan(x: 10, y: 20, active: false),
                                     .assign(skill: Lemmings2Runtime.Skill.roper.rawValue, lemming: 0)]
          && recorded.allSatisfy { $0.tick == 62 }, "An aimed assignment did not record a held aim and the assignment")
    check(events(for: .wait, tick: 62, skills: game.configuration.skills).isEmpty, "Wait recorded events")
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
        // A released fan always applies, so these stand in for recorded input.
        var events = Array(repeating: Lemmings2TimedEvent(tick: 0, event: .fan(x: 0, y: 0, active: false)), count: inputs)
        if let pointerX { events.append(.init(tick: 0, event: .aim(x: pointerX, y: 0, held: true))) }
        var built = Candidate(game: game, events: events)
        // Mark every event as applied, as a candidate that has run past tick 0 would be.
        var cursor = Lemmings2EventCursor()
        var copy = built.game
        _ = cursor.applyDroppingRefused(eventsAt: &copy, events: &built.events)
        built.cursor = cursor
        built.fingerprint = "same"
        return built
    }
    let merged = mergeByFingerprint([candidate(inputs: 3, pointerX: nil), candidate(inputs: 1, pointerX: nil)])
    check(merged.count == 1 && merged[0].cursor.next == 1, "The merge did not keep the shorter route")
    let aims = mergeByFingerprint([candidate(inputs: 1, pointerX: 10), candidate(inputs: 1, pointerX: 20)])
    check(aims.count == 2, "States that differ only in the held pointer were merged")
    let first = aims.map { $0.applied.map { "\($0.event)" } }
    let second = mergeByFingerprint([candidate(inputs: 1, pointerX: 20), candidate(inputs: 1, pointerX: 10)]).map { $0.applied.map { "\($0.event)" } }
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
    // Replay the found events strictly from a fresh runtime through the shared cursor.
    var replay = try fixture(wall: true)
    var cursor = Lemmings2EventCursor()
    let route = best.applied
    while !replay.isComplete {
        try cursor.apply(eventsAt: &replay, events: route)
        replay.step()
    }
    check(cursor.next == route.count, "Not every found event applied on replay")
    check(replay.saved == 3 && replay.tick == best.game.tick && replay.stateFingerprint == best.game.stateFingerprint,
          "The found route did not replay to the same state")
    print("PASS search finds the planted crowd route: 3 of 3 in \(best.game.tick) ticks, \(best.applied.count) events, \(report.expanded) nodes")
}
try testPlantedRouteIsFound()

func testSeedFollowsAfterAction() throws {
    var candidate = Candidate(game: try fixture(wall: true), events: [.init(tick: 200, event: .nuke)])
    while candidate.game.tick < 62 { candidate.game.step() }
    let basher = candidate.game.configuration.skills.firstIndex(of: .basher)!
    apply(.assign(slot: basher, lemming: 0), to: &candidate)
    check(candidate.events.count == 2 && candidate.events[0].tick == 62 && candidate.events[1].event == .nuke,
          "A new action was not inserted before the pending seed events")
    let list = actions(in: candidate.game, candidates: [0, 1], bounds: AimBounds(x: 0...119, y: 0...79),
                       pending: candidate.events, from: candidate.cursor.next)
    check(list.contains(.retime(index: 0, tick: 70)) && list.contains(.retarget(index: 0, lemming: 1)) && list.contains(.drop(index: 0)),
          "The next pending assignment offered no edits")
    check(!list.contains(.retime(index: 0, tick: 54)), "An edit moved an assignment before the current tick")
    apply(.retime(index: 0, tick: 250), to: &candidate)
    check(candidate.events.map(\.tick) == [200, 250], "A retimed assignment broke the event order")
    apply(.drop(index: 1), to: &candidate)
    check(candidate.events.map(\.event) == [.nuke], "Drop did not remove the pending assignment")
    print("PASS actions insert before pending seed events and edits keep the events ordered")
}
try testSeedFollowsAfterAction()

func testSeededSearchRestoresPlantedRoute() throws {
    let game = try fixture(wall: true)
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    // The seed assigns the basher on tick 90, after the winning window closes, so it saves nothing.
    let seed = [Lemmings2TimedEvent(tick: 90, event: .assign(skill: Lemmings2Runtime.Skill.basher.rawValue, lemming: 0))]
    let unchanged = decisionCount(start: game, seed: seed, limits: SearchLimits())
    check(unchanged.ticks > 0, "The seed did not run")
    let report = search(from: game, seed: seed, bounds: bounds, limits: SearchLimits(beamWidth: 16, maxDepth: 6, budgetSeconds: 120))
    check(report.best?.game.saved == 3, "Seeded search saved \(report.best?.game.saved ?? 0) of 3 from a late seed")
    check(report.winners.first?.game.saved == 3, "The winners list does not start with the best route")
    print("PASS seeded search restores the planted route from a late seed")
}
try testSeededSearchRestoresPlantedRoute()

func route(_ saved: Int, population: Int) -> Lemmings2ReplayWitness {
    Lemmings2ReplayWitness(levelSHA256: "x", population: population, expectedSaved: saved, expectedTicks: 10, events: [])
}

func result(_ winners: [Int], population: Int) -> LevelResult {
    let routes = winners.map { route($0, population: population) }
    return LevelResult(status: routes.isEmpty ? .unsolved : .solved, witness: routes.first, partial: nil,
                       winners: routes, summary: "")
}

func testChainPassesPopulationAndBacktracks() throws {
    var calls: [(level: Int, population: Int)] = []
    var accepted: [(level: Int, saved: Int, backtracked: Bool)] = []
    // Level 2 at 30 lemmings wins saving 30 or 25. Level 3 wins only with 25, so the chain
    // must go back to level 2's second route. Level 4 never wins.
    let chain = runChain(tribe: "classic", solve: { number, population in
        calls.append((number, population))
        switch number {
        case 1: return result([30], population: population)
        case 2: return result([30, 25], population: population)
        case 3: return result(population == 25 ? [20] : [], population: population)
        default: return result([], population: population)
        }
    }, accept: { number, route, backtracked in accepted.append((number, route.expectedSaved, backtracked)) })
    check(calls.map(\.population) == [60, 30, 30, 25, 20], "Population did not pass forward: \(calls)")
    check(chain.levels.map(\.saved) == [30, 25, 20, nil], "The chain levels are wrong: \(chain.levels)")
    check(chain.levels[1].backtracked && !chain.levels[2].backtracked, "The backtracked level is not marked")
    check(accepted.map(\.saved) == [30, 30, 25, 20] && accepted[2].backtracked, "Accepted routes are wrong: \(accepted)")
    check(chain.brokeAt == 4 && !chain.arkReady, "The chain did not break at level 4")

    let full = runChain(tribe: "classic", solve: { _, population in result([min(population, 40)], population: population) },
                        accept: { _, _, _ in })
    check(full.brokeAt == nil && full.arkReady && full.levels.count == 10, "A full chain did not reach the ark")
    print("PASS chain passes population forward, backtracks one level and records the break")
}
try testChainPassesPopulationAndBacktracks()

func testPromotionRules() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("l2-promote-\(UUID())")
    let fixtures = directory.appendingPathComponent("Fixtures"), chains = directory.appendingPathComponent("Chains")
    try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    func promoted(_ route: Lemmings2ReplayWitness, chosen: Bool = false) throws -> PromotionOutcome {
        try promote(route, name: "classic-02", fixtures: fixtures, chains: chains, chosenByChain: chosen)
    }
    check(try promoted(route(30, population: 12)) != .chain, "A chain route was promoted without a fixture")
    check(try promoted(route(10, population: 60)) == .fixture, "A new 60 route was not promoted")
    check(try promoted(route(5, population: 60)) != .fixture, "A worse 60 route replaced a better one")
    check(try promoted(route(5, population: 60), chosen: true) != .fixture, "A tribe run made a fixture worse")
    check(try promoted(route(12, population: 60)) == .fixture, "A better 60 route was not promoted")
    check(try promoted(route(4, population: 30)) == .chain, "A carry-over route was not promoted")
    check(try promoted(route(3, population: 30)) != .chain, "A worse carry-over route replaced a better one")
    check(try promoted(route(3, population: 30), chosen: true) == .chain, "A tribe run's backtracked route was not promoted")
    check(try promoted(route(2, population: 20)) == .chain, "A carry-over route at a new population was not promoted")
    print("PASS promotion never makes a fixture worse and follows the tribe run for chain routes")
}
try testPromotionRules()

func testClassicRecovery() throws {
    let data = URL(fileURLWithPath: "Sources/Ports/Lemm2")
    guard FileManager.default.fileExists(atPath: data.appendingPathComponent("LEVELS/LEVEL000.DAT").path) else {
        print("SKIP classic-01 recovery: game data not present")
        return
    }
    let campaign = try Lemmings2Campaign(root: data)
    let masks = try Lemmings2TerrainMasks(root: data)
    let fixture = try JSONDecoder().decode(Lemmings2ReplayWitness.self,
        from: Data(contentsOf: URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures/classic-01.json")))
    guard let level = campaign.levels.first(where: { $0.fingerprint == fixture.levelSHA256 }) else {
        check(false, "classic-01 level not found")
        return
    }
    let style = try Lemmings2Style(data: Data(contentsOf: data.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    let events = fixture.timedEvents()
    // Remove each assignment in turn, from the last, and keep the first removal that loses lemmings.
    var damaged: [Lemmings2TimedEvent]?
    var damagedSaved = 0
    for index in events.indices.reversed() {
        guard case .assign = events[index].event else { continue }
        var trial = events
        trial.remove(at: index)
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: 60)
        var cursor = Lemmings2EventCursor()
        while !game.isComplete {
            _ = cursor.applyDroppingRefused(eventsAt: &game, events: &trial)
            game.step()
        }
        if game.saved < 60 {
            damaged = events.enumerated().filter { $0.offset != index }.map(\.element)
            damagedSaved = game.saved
            break
        }
    }
    guard let damaged else {
        check(false, "No single removal damaged classic-01")
        return
    }
    let budget = Double(ProcessInfo.processInfo.environment["L2_RECOVERY_BUDGET"] ?? "") ?? 900
    let result = try solveLevel(level: level, style: style, masks: masks, population: 60, seed: damaged,
                                limits: SearchLimits(budgetSeconds: budget))
    check(result.witness?.expectedSaved == 60,
          "Seeded search recovered \(result.witness?.expectedSaved ?? 0) of 60 from a seed saving \(damagedSaved); \(result.summary)")
    print("PASS classic-01 recovery: a seed saving \(damagedSaved) of 60 restored to 60 of 60; \(result.summary)")
}
try testClassicRecovery()
