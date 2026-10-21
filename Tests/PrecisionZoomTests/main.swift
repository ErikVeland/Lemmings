import Foundation
import CoreGraphics

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let none = PrecisionZoomEarnings(threeStarLevels: 2)
check(none.superzoomUses == 0, "Superzoom unlocked before a third three-star level")
let earned = PrecisionZoomEarnings(threeStarLevels: 3)
check(earned.superzoomUses == 1, "Superzoom threshold is wrong")

var ledger = PrecisionZoomLedger()
let first = UUID()
ledger.start(attemptID: first)
for _ in 0..<100 {
    check(ledger.toggle(.zoom, earnings: none) && ledger.active == .zoom,
        "A new player could not start free Zoom")
    check(PrecisionZoomLedger.effectiveSpeed(normal: 3, active: ledger.active) == 3,
        "Ordinary Zoom changed simulation speed")
    check(ledger.toggle(.zoom, earnings: none) && ledger.active == nil,
        "Ordinary Zoom did not switch off")
}
check(ledger.toggle(.zoom, earnings: none), "Free Zoom was exhausted")
ledger.finish(didWin: false)
ledger.start(attemptID: UUID())
check(ledger.toggle(.zoom, earnings: none), "Failure disabled free Zoom")
check(ledger.toggle(.superzoom, earnings: earned), "Superzoom was unavailable")
check(ledger.remainingSuperzoom(earnings: earned) == 0, "Superzoom did not spend one use")
check(PrecisionZoomLedger.effectiveSpeed(normal: 10, active: ledger.active) == 0.5,
    "Bullet-time did not override fast-forward")
let activeAttempt = ledger.attemptID!
let saved = try JSONEncoder().encode(ledger)
ledger = try JSONDecoder().decode(PrecisionZoomLedger.self, from: saved)
ledger.start(attemptID: activeAttempt)
check(ledger.active == .superzoom && ledger.remainingSuperzoom(earnings: earned) == 0,
    "A recovered run lost its active Superzoom or spent use")

ledger.start(attemptID: UUID())
check(ledger.active == nil && ledger.remainingSuperzoom(earnings: earned) == 1,
    "Manual retry did not replenish Superzoom")
check(ledger.toggle(.superzoom, earnings: earned), "Superzoom was unavailable after retry")
check(ledger.toggle(.zoom, earnings: earned) && ledger.active == .zoom,
    "Free Zoom could not replace Superzoom")
ledger.finish(didWin: false)
ledger.finish(didWin: false)
ledger.start(attemptID: UUID())
check(ledger.remainingSuperzoom(earnings: earned) == 0, "A failed Superzoom use was not burnt once")
check(!ledger.toggle(.superzoom, earnings: earned), "A burnt Superzoom use was still available")
check(ledger.toggle(.zoom, earnings: none), "Superzoom exhaustion disabled free Zoom")
ledger.finish(didWin: true)
ledger.start(attemptID: UUID())
check(ledger.toggle(.zoom, earnings: none), "Winning disabled free Zoom")
let later = PrecisionZoomEarnings(threeStarLevels: 6)
check(ledger.remainingSuperzoom(earnings: later) == 1,
    "New three-star levels did not add Superzoom after a failed run")

let legacyAttempt = UUID()
let legacy = try JSONSerialization.data(withJSONObject: [
    "burnedZoom": 17, "burnedSuperzoom": 2,
    "attemptID": legacyAttempt.uuidString, "usedZoom": 8, "usedSuperzoom": 1,
    "active": "superzoom"
])
var migrated = try JSONDecoder().decode(PrecisionZoomLedger.self, from: legacy)
let legacyEarnings = PrecisionZoomEarnings(threeStarLevels: 12)
migrated.start(attemptID: legacyAttempt)
check(migrated.active == .superzoom && migrated.remainingSuperzoom(earnings: legacyEarnings) == 1,
    "Migration changed the active Superzoom or its balance")
check(migrated.toggle(.zoom, earnings: legacyEarnings)
    && migrated.remainingSuperzoom(earnings: legacyEarnings) == 1,
    "Old Zoom costs affected free Zoom or changed the Superzoom balance")
migrated.finish(didWin: false)
check(migrated.burnedSuperzoom == 3, "Migration lost the pending failed-run Superzoom cost")
let migratedJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(migrated)) as! [String: Any]
check(migratedJSON["burnedZoom"] == nil && migratedJSON["usedZoom"] == nil,
    "Obsolete basic Zoom currency remained in the saved ledger")

var lens = PrecisionZoomLens()
let pointer = CGPoint(x: 80, y: 60)
check(lens.transition(to: true, at: pointer, scaleX: 3, scaleY: 3) == .zero,
    "Zoom activation moved the cursor target")
check(lens.display(CGPoint(x: 90, y: 65)) == CGPoint(x: 100, y: 70), "2× image mapping is wrong")
check(lens.display(CGRect(x: 90, y: 65, width: 6, height: 4))
    == CGRect(x: 100, y: 70, width: 12, height: 8), "2× flash mapping is wrong")
check(lens.source(CGPoint(x: 100, y: 70)) == CGPoint(x: 90, y: 65), "Click mapping does not match the image")
let movedPointer = CGPoint(x: 100, y: 70)
let oldSource = lens.source(movedPointer)
let adjustment = lens.transition(to: false, at: movedPointer, scaleX: 3, scaleY: 6)
check(adjustment.x == (oldSource.x - movedPointer.x) / 3
    && adjustment.y == (oldSource.y - movedPointer.y) / 6,
    "Zoom-out did not retain the target under the cursor")
check(!lens.active && lens.source(movedPointer) == movedPointer, "Zoom did not switch off")

var scroll = PrecisionZoomScrollGesture()
@MainActor func factor(_ vertical: Double, precise: Bool, time: Double) -> Double {
    guard case .zoom(.magnify(let value)) = scroll.handle(horizontal: 0, vertical: vertical,
        precise: precise, phase: .changed, time: time) else { preconditionFailure("Missing continuous zoom") }
    return value
}
check(scroll.handle(horizontal: 14, vertical: 2, precise: true, phase: .began, time: 1) == .pan,
    "Horizontal trackpad panning activated Zoom")
let small = factor(1, precise: true, time: 2)
check(small > 1 && small < 1.02, "Precise input jumped to full Zoom")
let continued = factor(4, precise: true, time: 2.1)
check(continued > small && continued < 1.1, "Continued trackpad input did not scale proportionally")
check(abs(factor(-4, precise: true, time: 2.2) * continued - 1) < 0.000001,
    "Reversing the gesture did not reverse Zoom")
check(scroll.handle(horizontal: 0, vertical: -20, precise: true, momentum: true, time: 2.5) == .consumed,
    "Momentum changed Zoom")
check(scroll.handle(horizontal: 0, vertical: 0, precise: true, phase: .ended, time: 2.6) == .consumed,
    "Trackpad release panned the camera")
let wheel = factor(1, precise: false, time: 4)
check(wheel > 1.1 && wheel < 1.2, "A wheel tick jumped to full Zoom")
check(abs(factor(-1, precise: false, time: 4.01) * wheel - 1) < 0.000001,
    "Wheel reversal did not undo the magnification")
check(scroll.handle(horizontal: 0, vertical: 9, precise: true, modified: true, time: 5) == .pan,
    "Modified scroll lost camera panning")
check(scroll.handle(horizontal: 0, vertical: .infinity, precise: true, time: 6) == .consumed,
    "Invalid input reached the camera")
check(factor(10000, precise: false, time: 7) < 1.5, "Large input caused an unbounded zoom jump")
print("PASS free Zoom, Superzoom costs, legacy migration, cursor mapping and continuous wheel/touch gestures")
