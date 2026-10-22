#if os(iOS)
import LemmingsMobileCore
import UIKit

/// The screen that may show the Desk Clock. The library is the only host in the app; tests supply their own.
@MainActor protocol DeskClockHost: AnyObject {
    var deskClock: MobileDeskClockController? { get }
    var deskClockScreen: DeskClockScreen { get }
    var deskClockSettings: DeskClockSettings { get }
    var deskClockRegionView: UIView { get }
    func presentDeskClock(reason: DeskClockReason)
    func dismissDeskClock()
}

/// Opens the Desk Clock by itself on an idle foldable and closes an automatic clock when its pose or power
/// no longer applies. It also observes menu touches without recognising a gesture or taking input from controls.
@MainActor final class DeskClockAutomaticEntry: NSObject, UIGestureRecognizerDelegate {
    private let foldable: @MainActor (UIView) -> Bool
    private let regions: @MainActor (UIView) -> [MobileReservedRegion]
    private let charging: @MainActor () -> Bool
    private let uptime: @MainActor () -> TimeInterval
    private(set) var lastInput: TimeInterval

    init(foldable: @escaping @MainActor (UIView) -> Bool = { MobileSystemRegions.isFoldable(in: $0) },
         regions: @escaping @MainActor (UIView) -> [MobileReservedRegion] = { MobileSystemRegions.read(in: $0) },
         charging: @escaping @MainActor () -> Bool = {
             UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
         },
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.foldable = foldable
        self.regions = regions
        self.charging = charging
        self.uptime = uptime
        lastInput = uptime()
    }

    /// Every input resets the idle time.
    func noteInput() { lastInput = uptime() }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        noteInput()
        return false
    }

    /// The trigger for the host's current pose, power and screen. A shown clock is checked with `ignoringIdle`,
    /// because the player is not touching the menu beneath it.
    func trigger(for host: DeskClockHost, ignoringIdle: Bool = false) -> DeskClockTrigger {
        let view = host.deskClockRegionView
        let safe = view.safeAreaLayoutGuide.layoutFrame
        return DeskClockTrigger.evaluate(DeskClockTriggerInput(
            foldable: foldable(view), regions: regions(view),
            safe: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
            idle: ignoringIdle ? DeskClockTrigger.idleDelay : uptime() - lastInput,
            charging: charging(), screen: host.deskClockScreen, settings: host.deskClockSettings))
    }

    /// Opens a clock when the trigger fires. While an automatic clock shows, closes it when its trigger no
    /// longer holds. A clock the player opened stays until the player closes it.
    func check(_ host: DeskClockHost) {
        if let clock = host.deskClock {
            guard clock.isShown, let expected = Self.trigger(for: clock.reason) else { return }
            if trigger(for: host, ignoringIdle: true) != expected { host.dismissDeskClock() }
            return
        }
        switch trigger(for: host) {
        case .stacked: host.presentDeskClock(reason: .stacked)
        case .closedCharging: host.presentDeskClock(reason: .closedCharging)
        case .none: break
        }
    }

    private static func trigger(for reason: DeskClockReason) -> DeskClockTrigger? {
        switch reason {
        case .stacked: .stacked
        case .closedCharging: .closedCharging
        case .menu, .widget: nil
        }
    }
}
#endif
