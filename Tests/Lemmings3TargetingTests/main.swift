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
    let turned = Lemmings3TargetCandidate(id: 0, x: 50, y: 40, direction: -1, tool: nil, active: true)
    let approaching = Lemmings3TargetCandidate(id: 1, x: 48, y: 40, direction: 1, tool: nil, active: true)

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

do {
    try testApproachingLemmingPreferred()
    print("Lemmings 3 targeting tests passed.")
} catch {
    FileHandle.standardError.write(Data("Lemmings 3 targeting tests failed: \(error)\n".utf8))
    exit(1)
}
