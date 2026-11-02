import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible { let description: String }

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

/// The turned lemming sits closer to the click but already faces away from
/// it. The approaching lemming is one step behind, still walking toward it.
private func testApproachingLemmingPreferred() throws {
    let turned = Lemmings3TargetCandidate(id: 0, x: 50, y: 40, direction: -1, tool: nil, isBuilding: false, active: true)
    let approaching = Lemmings3TargetCandidate(id: 1, x: 48, y: 40, direction: 1, tool: nil, isBuilding: false, active: true)

    let favored = Lemmings3Targeting.nearest(
        among: [turned, approaching], x: 52, y: 40, selected: 0, favorApproaching: true)
    try require(favored?.id == approaching.id,
        "favorApproaching should pick the lemming still walking toward the click")
    try require(Lemmings3Targeting.nearest(among: [turned, approaching], x: 50, y: 32,
        selected: 0, favorApproaching: true)?.id == approaching.id,
        "A centred click must not hide the approaching alternative")

    let plain = Lemmings3Targeting.nearest(
        among: [turned, approaching], x: 52, y: 40, selected: 0, favorApproaching: false)
    try require(plain?.id == turned.id,
        "Without the setting, nearest-distance picking should keep choosing the turned lemming")

    let onlyTurned = Lemmings3Targeting.nearest(
        among: [turned], x: 52, y: 40, selected: 0, favorApproaching: true)
    try require(onlyTurned?.id == turned.id,
        "With no approaching candidate, targeting should fall back to the nearest one")

    print("PASS Lemmings 3 targeting prefers the lemming still walking toward the click")
}

private func testCrowdedWallTargets() throws {
    for direction in [-1, 1] {
        let returning = (0..<6).map {
            Lemmings3TargetCandidate(id: $0, x: 50 + ($0 % 3) * direction, y: 40,
                direction: -direction, tool: .spade, isBuilding: false, active: true)
        }
        let incoming = Lemmings3TargetCandidate(id: 6, x: 50 - 3 * direction, y: 40,
            direction: direction, tool: .spade, isBuilding: false, active: true)
        let wall: (Int, Int) -> Bool = { x, y in (x - 50) * direction >= 5 && y < 40 }
        for selected in [0, 3] {
            try require(Lemmings3Targeting.nearest(among: returning + [incoming], x: 50, y: 32,
                selected: selected, favorApproaching: true, terrainIsSolid: wall)?.id == incoming.id,
                "A returning crowd must not hide the single wall-facing lemming")
            try require(Lemmings3Targeting.nearest(among: returning + [incoming], x: 50, y: 32,
                selected: selected, favorApproaching: false, terrainIsSolid: wall)?.id != incoming.id,
                "Wall targeting opt-out must restore nearest selection")
        }
        var unavailable = incoming
        unavailable.canAssignSelected = false
        try require(Lemmings3Targeting.nearest(among: returning + [unavailable], x: 50, y: 32,
            selected: 3, favorApproaching: true, terrainIsSolid: wall)?.id != incoming.id,
            "Wall preference must not bypass tool eligibility")
        try require(Lemmings3Targeting.nearest(among: returning + [incoming], x: 50, y: 32,
            selected: 3, favorApproaching: true, manualCarrierID: returning[0].id, terrainIsSolid: wall)?.id == returning[0].id,
            "Wall preference must preserve manual carrier selection")
    }
    print("PASS mirrored L3 crowded walls, tool eligibility, opt-out and manual carrier priority")
}

/// Two candidates facing the SAME direction must not be reordered by the
/// approaching preference, even when the nearer one technically fails the
/// "approaching" check because the click landed one pixel behind it.
private func testSameDirectionCandidatesKeepNearestPick() throws {
    let leader = Lemmings3TargetCandidate(id: 0, x: 51, y: 40, direction: 1, tool: nil, isBuilding: false, active: true)
    let follower = Lemmings3TargetCandidate(id: 1, x: 46, y: 40, direction: 1, tool: nil, isBuilding: false, active: true)

    let favored = Lemmings3Targeting.nearest(
        among: [leader, follower], x: 50, y: 40, selected: 0, favorApproaching: true)
    try require(favored?.id == leader.id,
        "Same-direction candidates must not be reordered by the approaching preference")

    let plain = Lemmings3Targeting.nearest(
        among: [leader, follower], x: 50, y: 40, selected: 0, favorApproaching: false)
    try require(plain?.id == leader.id,
        "Plain targeting should also pick the nearer, same-direction leader")

    print("PASS same-direction Lemmings 3 candidates keep the plain nearest pick")
}

/// When `selected >= 3` (the "Use" action), a lemming that already holds a
/// tool must be picked over a nearer-approaching lemming with no tool —
/// the tool-holding tier must not be overridden by the approaching tier.
private func testToolHolderBeatsApproachingCandidate() throws {
    let holder = Lemmings3TargetCandidate(id: 0, x: 55, y: 40, direction: -1, tool: .bricks, isBuilding: false, active: true)
    let toolless = Lemmings3TargetCandidate(id: 1, x: 51, y: 40, direction: 1, tool: nil, isBuilding: false, active: true)

    let result = Lemmings3Targeting.nearest(
        among: [holder, toolless], x: 52, y: 40, selected: 3, favorApproaching: true)
    try require(result?.id == holder.id,
        "A tool-holding candidate must win even when a toolless candidate is nearer and approaching")

    print("PASS tool-holding tier still beats an approaching toolless candidate")
}

private func testManualCarrierSelection() throws {
    let carrier = Lemmings3TargetCandidate(id: 4, x: 45, y: 40, direction: 1, tool: .bricks, isBuilding: false, active: true)
    let nearer = Lemmings3TargetCandidate(id: 5, x: 50, y: 40, direction: 1, tool: .spade, isBuilding: false, active: true)
    let selected = Lemmings3Targeting.nearest(among: [carrier, nearer], x: 51, y: 40, selected: 3,
        favorApproaching: true, manualCarrierID: carrier.id)
    try require(selected?.id == carrier.id,
        "A manually highlighted carrier in the clicked group must take precedence")

    let first = Lemmings3Targeting.carrier(among: [carrier, nearer], x: 10, y: 10, after: nil)
    let next = Lemmings3Targeting.carrier(among: [carrier, nearer], x: 10, y: 10, after: first?.id)
    try require(first?.id == carrier.id && next?.id == nearer.id,
        "A mid-air right click must cycle active tool carriers in actor order")

    let direct = Lemmings3Targeting.carrier(among: [carrier, nearer], x: 50, y: 40, after: carrier.id)
    try require(direct?.id == nearer.id,
        "A right click on a carrier must select that nearby carrier before cycling")
    print("PASS Lemmings 3 manual carrier selection and cycling")
}

private func testFollowerBeatsBuilder() throws {
    let builder = Lemmings3TargetCandidate(id: 0, x: 50, y: 40, direction: 1, tool: .bricks, isBuilding: true, active: true)
    let follower = Lemmings3TargetCandidate(id: 1, x: 46, y: 40, direction: 1, tool: nil, isBuilding: false, active: true)
    let result = Lemmings3Targeting.nearest(
        among: [builder, follower], x: 52, y: 40, selected: 0, favorApproaching: true)
    try require(result?.id == follower.id,
        "A follower approaching a bridge builder should receive the selected skill")
    let plain = Lemmings3Targeting.nearest(
        among: [builder, follower], x: 52, y: 40, selected: 0, favorApproaching: false)
    try require(plain?.id == builder.id,
        "Turning the setting off should keep the nearest bridge builder")
    print("PASS Lemmings 3 targeting favours a follower behind a builder")
}

private func testActiveWorkerPriority() throws {
    let worker = Lemmings3TargetCandidate(id: 4, x: 46, y: 40, direction: -1, tool: .spade,
        isBuilding: false, active: true, isPerformingSkill: true)
    let walker = Lemmings3TargetCandidate(id: 5, x: 51, y: 40, direction: 1, tool: .bricks,
        isBuilding: false, active: true)
    let wall: (Int, Int) -> Bool = { x, y in x >= 53 && y < 40 }
    for selected in [0, 1, 2, 3, 4] {
        try require(Lemmings3Targeting.nearest(among: [walker, worker], x: 52, y: 32,
            selected: selected, favorApproaching: true, favorBuilders: true,
            terrainIsSolid: wall)?.id == worker.id,
            "An eligible active worker must beat a closer walker and the approaching-wall preference")
        try require(Lemmings3Targeting.nearest(among: [walker, worker], x: 52, y: 32,
            selected: selected, favorApproaching: true, favorBuilders: false)?.id == walker.id,
            "Worker opt-out must restore ordinary crowd targeting")
        var unavailable = worker
        unavailable.canAssignSelected = false
        try require(Lemmings3Targeting.nearest(among: [walker, unavailable], x: 52, y: 32,
            selected: selected, favorApproaching: true, favorBuilders: true)?.id == walker.id,
            "An unavailable worker must not hide an eligible walker")
    }
    try require(Lemmings3Targeting.nearest(among: [worker, walker], x: 52, y: 32,
        selected: 0, favorApproaching: true, favorBuilders: true,
        manualCarrierID: walker.id)?.id == walker.id,
        "Manual carrier selection must remain authoritative over active-worker preference")
    let outside = Lemmings3TargetCandidate(id: 6, x: 42, y: 40, direction: 1, tool: .spade,
        isBuilding: false, active: true, isPerformingSkill: true)
    try require(Lemmings3Targeting.nearest(among: [outside, walker], x: 52, y: 32,
        selected: 0, favorApproaching: true, favorBuilders: true)?.id == walker.id,
        "Worker preference must preserve the existing pick bounds")
    let left = Lemmings3TargetCandidate(id: 7, x: 48, y: 40, direction: 1, tool: .spade,
        isBuilding: false, active: true, isPerformingSkill: true)
    let right = Lemmings3TargetCandidate(id: 3, x: 56, y: 40, direction: -1, tool: .spade,
        isBuilding: false, active: true, isPerformingSkill: true)
    for candidates in [[left, right, walker], [walker, right, left]] {
        try require(Lemmings3Targeting.nearest(among: candidates, x: 52, y: 32,
            selected: 0, favorApproaching: true, favorBuilders: true)?.id == right.id,
            "Equidistant workers must retain deterministic actor-ID ordering")
    }
    let builder = Lemmings3TargetCandidate(id: 8, x: 50, y: 40, direction: 1, tool: .bricks,
        isBuilding: true, active: true)
    let follower = Lemmings3TargetCandidate(id: 9, x: 46, y: 40, direction: 1, tool: nil,
        isBuilding: false, active: true)
    try require(Lemmings3Targeting.nearest(among: [builder, follower], x: 52, y: 32,
        selected: 0, favorApproaching: true, favorBuilders: true)?.id == builder.id,
        "An approaching follower must not steal an active builder when another action is selected")
    print("PASS L3 active-worker priority, eligibility, opt-out, bounds, stable ties and manual selection")
}

private func testWorkerToolPriorities() throws {
    let walker = Lemmings3TargetCandidate(id: 0, x: 51, y: 40, direction: 1, tool: .spade,
        isBuilding: false, active: true)
    let toolless = Lemmings3TargetCandidate(id: 1, x: 52, y: 40, direction: 1, tool: nil,
        isBuilding: false, active: true, canAssignSelected: false, isPerformingSkill: true)
    for selected in [3, 4] {
        try require(Lemmings3Targeting.nearest(among: [toolless, walker], x: 52, y: 32,
            selected: selected, favorApproaching: true, favorBuilders: true)?.id == walker.id,
            "Use and Drop must retain native tool eligibility before worker preference")
    }
    for tool: Lemmings3Runtime.Tool in [.bomb, .grenade] {
        let blocker = Lemmings3TargetCandidate(id: 2, x: 46, y: 40, direction: 1, tool: tool,
            isBuilding: false, active: true, isBlocking: true)
        try require(Lemmings3Targeting.nearest(among: [blocker, walker], x: 52, y: 32,
            selected: 3, favorApproaching: true, favorBombBlockers: false, favorBuilders: true)?.id == walker.id,
            "Worker preference must preserve the independent bomb-blocker opt-out for Use")
        try require(Lemmings3Targeting.nearest(among: [blocker, walker], x: 52, y: 32,
            selected: 0, favorApproaching: true, favorBombBlockers: false, favorBuilders: true)?.id == blocker.id,
            "A blocker remains an active worker when assigning Walker")
        let builder = Lemmings3TargetCandidate(id: 3, x: 49, y: 40, direction: 1, tool: .bricks,
            isBuilding: true, active: true)
        try require(Lemmings3Targeting.nearest(among: [blocker, builder, walker], x: 52, y: 32,
            selected: 3, favorApproaching: true, favorBombBlockers: true, favorBuilders: true)?.id == blocker.id,
            "Explicit bomb-blocker priority must remain above active builders")
    }
    let digger = Lemmings3TargetCandidate(id: 4, x: 51, y: 40, direction: 1, tool: .spade,
        isBuilding: false, active: true, isPerformingSkill: true)
    let builder = Lemmings3TargetCandidate(id: 5, x: 46, y: 40, direction: 1, tool: .bricks,
        isBuilding: true, active: true)
    try require(Lemmings3Targeting.nearest(among: [digger, builder], x: 52, y: 32,
        selected: 3, favorApproaching: true, favorBuilders: true)?.id == builder.id,
        "Repeat-brick priority must remain above the general active-worker tier")
    print("PASS L3 tool eligibility, independent bomb opt-out and retained explicit tool priorities")
}

private func testNativeDiggerSelection() throws {
    let width = 128, height = 64
    var terrain = [UInt16](repeating: 0x1000, count: width * height)
    for y in 48..<height {
        for x in 0..<width where x < 70 || y >= 60 { terrain[y * width + x] = 0x20 }
    }
    var game = try Lemmings3Runtime(configuration: .init(width: width, height: height,
        attributes: terrain, entrance: .init(x: 100, y: 40), exits: [.init(x: 110, y: 46)],
        total: 1, releaseInterval: 1, releaseDelay: 1000,
        pickups: [.init(id: 0, tool: .spade, x: 46, y: 40)],
        extras: [.init(x: 46, y: 48, direction: 1), .init(x: 51, y: 48, direction: 1)]))
    game.step()
    try require(game.lemmings.count == 2 && game.lemmings[0].tool == .spade,
        "The native fixture must supply a spade to the first worker")
    try require(game.useTool(to: 0, direction: .right) && game.lemmings[0].state == .digging,
        "The native fixture must start a real digging action")
    let before = game.lemmings
    let walker = game.lemmings[1]
    for selected in [0, 3, 4] {
        let target = game.target(x: walker.x, y: walker.y - 8, selected: selected,
            favorApproaching: true, favorBombBlockers: true, favorBuilders: true)
        try require(target?.id == 0 && target?.isPerformingSkill == true && target?.canAssignSelected == true,
            "Runtime targeting must classify the real digger and preserve action/tool eligibility")
    }
    try require(game.lemmings == before, "Target selection must not mutate the runtime")
    try require(game.target(x: walker.x, y: walker.y - 8, selected: 0,
        favorApproaching: false, favorBombBlockers: false, favorBuilders: false)?.id == walker.id,
        "Worker opt-out must restore the directly aimed walker")
    let target = game.target(x: walker.x, y: walker.y - 8, selected: 0,
        favorApproaching: true, favorBombBlockers: true, favorBuilders: true)
    try require(target != nil && game.assign(.walker, to: target!.id),
        "The selected active digger must accept the native Walker action")
    try require(game.lemmings[0].state == .walking && game.lemmings[1] == walker,
        "Assignment must stop the digger without changing the closer walker")
    try require(game.lemmings[0].hasSkillTargetPriority,
        "The stopped digger must retain worker preference while walking")
    try require(game.target(x: walker.x, y: walker.y - 8, selected: 0,
        favorApproaching: true, favorBombBlockers: true, favorBuilders: true)?.id == 0,
        "The walking former digger must remain preferred over the closer untouched walker")
    let beforeFall = game
    for _ in 0..<100 {
        game.step()
        if game.lemmings[0].state == .falling { break }
    }
    try require(game.lemmings[0].state == .falling && !game.lemmings[0].hasSkillTargetPriority,
        "Walking off the ledge must clear retained targeting priority on the falling tick")
    for _ in 0..<40 {
        game.step()
        if game.lemmings[0].state == .walking { break }
    }
    try require(game.lemmings[0].state == .walking && !game.lemmings[0].hasSkillTargetPriority,
        "Landing must not restore the previous digger's targeting priority")
    try require(beforeFall.lemmings[0].hasSkillTargetPriority,
        "The copied runtime must retain the pre-fall targeting history")
    print("PASS native L3 digger selection, walking continuity, falling reset and copied runtime history")
}

do {
    let builder = Lemmings3TargetCandidate(id: 0, x: 46, y: 40, direction: 1, tool: .bricks, isBuilding: true, active: true)
    let walker = Lemmings3TargetCandidate(id: 1, x: 51, y: 40, direction: 1, tool: .bricks, isBuilding: false, active: true)
    try require(Lemmings3Targeting.nearest(among: [builder, walker], x: 52, y: 32, selected: 3,
        favorApproaching: true, favorBuilders: true)?.id == builder.id, "Use must prefer an active brick builder")
    try require(Lemmings3Targeting.nearest(among: [builder, walker], x: 52, y: 32, selected: 3,
        favorApproaching: true, favorBuilders: false)?.id == walker.id, "Builder opt-out must restore the nearest tool holder")
    var blocker = Lemmings3TargetCandidate(id: 2, x: 48, y: 40, direction: -1, tool: .bomb,
        isBuilding: false, active: true, isBlocking: true)
    try require(Lemmings3Targeting.nearest(among: [blocker, walker], x: 52, y: 32, selected: 3,
        favorApproaching: true, favorBombBlockers: true)?.id == blocker.id, "Use must prefer a bomb-equipped blocker")
    try require(Lemmings3Targeting.nearest(among: [blocker, walker], x: 52, y: 32, selected: 3,
        favorApproaching: true, favorBombBlockers: false)?.id == walker.id, "Bomb opt-out must restore the nearer tool holder")
    blocker.canAssignSelected = false
    try require(Lemmings3Targeting.nearest(among: [blocker, walker], x: 52, y: 32, selected: 3,
        favorApproaching: true, favorBombBlockers: true)?.id == walker.id, "Bomb preference must respect tool eligibility")
    print("PASS Lemmings 3 bomb and builder priorities, eligibility and independent opt-outs")
    try testApproachingLemmingPreferred()
    try testCrowdedWallTargets()
    try testSameDirectionCandidatesKeepNearestPick()
    try testToolHolderBeatsApproachingCandidate()
    try testManualCarrierSelection()
    try testFollowerBeatsBuilder()
    try testActiveWorkerPriority()
    try testWorkerToolPriorities()
    try testNativeDiggerSelection()
    print("Lemmings 3 targeting tests passed.")
} catch {
    FileHandle.standardError.write(Data("Lemmings 3 targeting tests failed: \(error)\n".utf8))
    exit(1)
}
