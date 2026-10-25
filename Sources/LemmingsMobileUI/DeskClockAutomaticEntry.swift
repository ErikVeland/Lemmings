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

/// Opens the Desk Clock for tent pose or idle Home triggers and closes it when the pose or power
/// no longer applies. It also observes menu touches without recognising a gesture or taking input from controls.
@MainActor final class DeskClockAutomaticEntry: NSObject, UIGestureRecognizerDelegate {
    private let foldable: @MainActor (UIView) -> Bool
    private let regions: @MainActor (UIView) -> [MobileReservedRegion]
    private let charging: @MainActor () -> Bool
    private let uptime: @MainActor () -> TimeInterval
    private let voiceOverRunning: @MainActor () -> Bool
    var hinge = DeskClockHinge.unavailable
    private var hingeAngle: Double?
    var onPoseChange: (() -> Void)?
    private var dismissedTent = false
    private let observedViews = NSHashTable<UIView>.weakObjects()
    private(set) var lastInput: TimeInterval

    init(foldable: @escaping @MainActor (UIView) -> Bool = { MobileSystemRegions.isFoldable(in: $0) },
         regions: @escaping @MainActor (UIView) -> [MobileReservedRegion] = { MobileSystemRegions.read(in: $0) },
         charging: @escaping @MainActor () -> Bool = {
             UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
         },
         uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         voiceOverRunning: @escaping @MainActor () -> Bool = { UIAccessibility.isVoiceOverRunning }) {
        self.foldable = foldable
        self.regions = regions
        self.charging = charging
        self.uptime = uptime
        self.voiceOverRunning = voiceOverRunning
        lastInput = uptime()
    }

    /// The screen seen by idle triggers. Only Home permits idle entry. A game reports its own
    /// screen. A sheet, a loading level or a text field with the keyboard blocks the clock, because typing never
    /// reaches the idle time stamp.
    static func screen(game: DeskClockScreen?, home: Bool, textEditing: Bool, blocked: Bool) -> DeskClockScreen {
        if let game { return game }
        if blocked || textEditing { return .modal }
        return home ? .menu : .modal
    }

    /// The content view stays in the scene hierarchy beneath levels and menu pages.
    func observePose(in view: UIView) {
        guard !observedViews.contains(view) else { return }
        observedViews.add(view)
        #if compiler(>=6.3)
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak self, weak view] _, update in
                guard let self else { return }
                if update.hinge != nil, let view { MobileSystemRegions.noteHinge(in: view) }
                // A display handoff can send an update without hinge data before the
                // outer display reports its pose. Keep the last measured pose meanwhile.
                if let hinge = update.hinge {
                    switch hinge.status {
                    case .closed: self.hinge = .closed
                    case .partiallyOpen: self.hinge = .partiallyOpen
                    case .fullyOpen: self.hinge = .fullyOpen
                    default: self.hinge = .unavailable
                    }
                    self.hingeAngle = Double(hinge.angle)
                }
                self.onPoseChange?()
            })
        }
        #endif
    }

    /// A dismissed tent clock waits until the phone leaves tent pose before opening again.
    func noteDismissal(reason: DeskClockReason) {
        if reason == .tent { dismissedTent = true }
        noteInput()
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
            charging: charging(), screen: host.deskClockScreen, settings: host.deskClockSettings,
            hinge: hinge, hingeAngle: hingeAngle))
    }

    /// Tent entry works with VoiceOver. Idle entry waits while VoiceOver runs. While an automatic clock shows,
    /// closes it when its trigger no longer holds. A clock the player opened stays until the player closes it.
    func check(_ host: DeskClockHost) {
        let candidate = trigger(for: host)
        #if DEBUG
        let state = "hinge=\(hinge) angle=\(hingeAngle.map(String.init(describing:)) ?? "nil") "
            + "trigger=\(candidate) dismissed=\(dismissedTent) clock=\(host.deskClock.map { String(describing: $0.reason) } ?? "none") "
            + "screen=\(host.deskClockScreen)"
        if UserDefaults.standard.string(forKey: "DeskClockPoseState") != state {
            UserDefaults.standard.set(state, forKey: "DeskClockPoseState")
            var history = UserDefaults.standard.stringArray(forKey: "DeskClockPoseHistory") ?? []
            history.append("\(Date().timeIntervalSince1970) \(state)")
            UserDefaults.standard.set(Array(history.suffix(32)), forKey: "DeskClockPoseHistory")
        }
        #endif
        if candidate != .tent { dismissedTent = false }
        if let clock = host.deskClock {
            guard clock.isShown, let expected = Self.trigger(for: clock.reason) else { return }
            if trigger(for: host, ignoringIdle: true) != expected {
                host.dismissDeskClock()
                if expected == .tent { dismissedTent = false }
            }
            return
        }
        guard candidate == .tent || !voiceOverRunning() else { return }
        switch candidate {
        case .tent:
            if !dismissedTent { host.presentDeskClock(reason: .tent) }
        case .stacked: host.presentDeskClock(reason: .stacked)
        case .closedCharging: host.presentDeskClock(reason: .closedCharging)
        case .none: break
        }
    }

    private static func trigger(for reason: DeskClockReason) -> DeskClockTrigger? {
        switch reason {
        case .tent: .tent
        case .stacked: .stacked
        case .closedCharging: .closedCharging
        case .menu, .widget: nil
        }
    }
}
#endif
