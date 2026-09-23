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
    try testApproachingLemmingPreferred()
    try testSameDirectionCandidatesKeepNearestPick()
    try testToolHolderBeatsApproachingCandidate()
    try testFollowerBeatsBuilder()
    print("Lemmings 3 targeting tests passed.")
} catch {
    FileHandle.standardError.write(Data("Lemmings 3 targeting tests failed: \(error)\n".utf8))
    exit(1)
}
