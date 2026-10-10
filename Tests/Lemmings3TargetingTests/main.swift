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
    print("Lemmings 3 targeting tests passed.")
} catch {
    FileHandle.standardError.write(Data("Lemmings 3 targeting tests failed: \(error)\n".utf8))
    exit(1)
}
