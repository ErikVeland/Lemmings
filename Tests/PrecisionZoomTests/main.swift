import Foundation
import CoreGraphics

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let none = PrecisionZoomEarnings(careerStars: 2, threeStarLevels: 2)
check(none.zoomUses == 0 && none.superzoomUses == 0, "Uses unlocked before a third star or three-star level")
let earned = PrecisionZoomEarnings(careerStars: 6, threeStarLevels: 3)
check(earned.zoomUses == 2 && earned.superzoomUses == 1, "Career thresholds are wrong")

var ledger = PrecisionZoomLedger()
let first = UUID()
ledger.start(attemptID: first)
check(ledger.toggle(.zoom, earnings: earned), "The first Zoom use was unavailable")
check(ledger.active == .zoom && ledger.remaining(.zoom, earnings: earned) == 1, "Zoom did not spend one use")
check(ledger.toggle(.zoom, earnings: earned), "Zoom did not switch off")
check(ledger.active == nil && ledger.remaining(.zoom, earnings: earned) == 1, "Switching off spent another use")
check(ledger.toggle(.superzoom, earnings: earned), "Superzoom was unavailable")
check(PrecisionZoomLedger.effectiveSpeed(normal: 10, active: ledger.active) == 0.5,
    "Bullet-time did not override fast-forward")
let saved = try JSONEncoder().encode(ledger)
ledger = try JSONDecoder().decode(PrecisionZoomLedger.self, from: saved)
ledger.start(attemptID: first)
check(ledger.active == .superzoom && ledger.remaining(.superzoom, earnings: earned) == 0,
    "A recovered run lost its active effect or spent use")

ledger.start(attemptID: UUID())
check(ledger.active == nil && ledger.remaining(.zoom, earnings: earned) == 2
    && ledger.remaining(.superzoom, earnings: earned) == 1, "Manual retry did not replenish uses")
check(ledger.toggle(.zoom, earnings: earned), "Zoom was unavailable after retry")
check(ledger.toggle(.superzoom, earnings: earned), "Superzoom was unavailable after retry")
ledger.finish(didWin: false)
ledger.finish(didWin: false)
ledger.start(attemptID: UUID())
check(ledger.remaining(.zoom, earnings: earned) == 1 && ledger.remaining(.superzoom, earnings: earned) == 0,
    "Failed-run uses were not burnt once")
check(!ledger.toggle(.superzoom, earnings: earned), "A burnt Superzoom use was still available")
check(ledger.toggle(.zoom, earnings: earned), "The remaining Zoom use was lost")
ledger.finish(didWin: true)
ledger.start(attemptID: UUID())
check(ledger.remaining(.zoom, earnings: earned) == 1, "A winning run burnt its Zoom use")
let later = PrecisionZoomEarnings(careerStars: 9, threeStarLevels: 6)
check(ledger.remaining(.zoom, earnings: later) == 2 && ledger.remaining(.superzoom, earnings: later) == 1,
    "New stars did not add uses after a failed run")

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
check(scroll.handle(horizontal: 14, vertical: 2, precise: true, phase: .began, time: 1) == .pan,
    "Horizontal trackpad panning activated Zoom")
check(scroll.handle(horizontal: 0, vertical: 3, precise: true, phase: .began, time: 2) == .consumed,
    "A short trackpad movement was not held for a deliberate gesture")
check(scroll.handle(horizontal: 0, vertical: 4, precise: true, phase: .changed, time: 2.1) == .consumed,
    "A partial trackpad gesture activated Zoom")
check(scroll.handle(horizontal: 0, vertical: 1, precise: true, phase: .changed, time: 2.2) == .zoom(.zoomIn),
    "Trackpad scroll up did not activate Zoom")
check(scroll.handle(horizontal: 0, vertical: 16, precise: true, phase: .changed, time: 2.3) == .consumed,
    "A trackpad gesture started Zoom twice")
check(scroll.handle(horizontal: 0, vertical: -12, precise: true, phase: .changed, time: 2.4) == .consumed,
    "A trackpad bounce switched Zoom off")
check(scroll.handle(horizontal: 0, vertical: -20, precise: true, momentum: true, time: 2.5) == .consumed,
    "Momentum started another Zoom action")
check(scroll.handle(horizontal: 0, vertical: 0, precise: true, phase: .ended, time: 2.6) == .consumed,
    "Ending an active trackpad gesture panned the camera")
check(scroll.handle(horizontal: 0, vertical: -8, precise: true, phase: .began, time: 3) == .zoom(.zoomOut),
    "A new trackpad gesture did not switch Zoom off")
check(scroll.handle(horizontal: 0, vertical: 0, precise: true, phase: .ended, time: 3.1) == .consumed,
    "Trackpad release panned the camera")
check(scroll.handle(horizontal: 0, vertical: 1, precise: false, time: 4) == .zoom(.zoomIn),
    "A scroll-wheel tick did not activate Zoom")
check(scroll.handle(horizontal: 0, vertical: -1, precise: false, time: 4.01) == .zoom(.zoomOut),
    "A second wheel tick could not switch Zoom off")
check(scroll.handle(horizontal: 0, vertical: 9, precise: true, modified: true, time: 5) == .pan,
    "Shift or system-modified scroll lost camera panning")
check(scroll.handle(horizontal: 0, vertical: 4, precise: true, time: 6) == .consumed,
    "A short Magic Mouse movement activated Zoom")
check(scroll.handle(horizontal: 0, vertical: 4, precise: true, time: 6.1) == .zoom(.zoomIn),
    "A phase-less Magic Mouse gesture did not activate Zoom")
check(scroll.handle(horizontal: 0, vertical: -8, precise: true, time: 6.2) == .consumed,
    "Magic Mouse bounce switched Zoom off")
check(scroll.handle(horizontal: 0, vertical: -8, precise: true, time: 6.8) == .zoom(.zoomOut),
    "A later phase-less gesture stayed latched")
print("PASS career thresholds, toggles, retry, failure costs, bullet-time, cursor mapping and wheel/touch gestures")
