#if os(iOS)
import UIKit

/**
 * Observes menu touches without recognising a gesture or taking input from controls.
 */
@MainActor final class DeskClockActivity: NSObject, UIGestureRecognizerDelegate {
    var lastInput = ProcessInfo.processInfo.systemUptime

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        lastInput = ProcessInfo.processInfo.systemUptime
        return false
    }
}
#endif
