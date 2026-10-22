#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit
import WidgetKit

/// Why the clock opened. Only the player's own choices may ask for calendar access.
enum DeskClockReason: Sendable {
    case menu, widget, stacked, closedCharging

    var asksForCalendar: Bool { self == .menu || self == .widget }
    var isAutomatic: Bool { !asksForCalendar }
}

/// Shows the Desk Clock over the menu. It pauses menu music, keeps the screen on only while the device
/// charges, and reads the next event off the main actor.
@MainActor final class MobileDeskClockController: UIViewController {
    static let closeControlDuration: UInt64 = 4_000_000_000
    static let eventRefreshInterval: TimeInterval = 60

    let reason: DeskClockReason
    let clockView: MobileDeskClockView
    let closeButton = MobilePixelButton()
    private let events: any DeskClockEventSource
    private let eventReader: DeskClockEventReader
    private let batteryState: @MainActor () -> UIDevice.BatteryState
    private let defaults: UserDefaults
    private let suspendMusic: @MainActor () -> Void
    private let resumeMusic: @MainActor () -> Void
    private let setIdleTimerDisabled: @MainActor (Bool) -> Void
    private let regions: @MainActor (UIView) -> [MobileReservedRegion]
    private let voiceOverRunning: @MainActor () -> Bool
    private let reloadWidgets: @MainActor () -> Void
    var onClose: (() -> Void)?
    private(set) var accessTask: Task<Void, Never>?
    var eventTask: Task<Void, Never>? { eventReader.task }
    private var hideTask: Task<Void, Never>?
    private var ticker: Timer?
    private var lastRefresh = Date.distantPast
    private var layout: DeskClockLayout?
    private var batteryMonitoring: Bool?
    private var observers = MobileNotificationObserverBag()
    private(set) var isShown = false

    init(reason: DeskClockReason,
         events: any DeskClockEventSource = EventKitDeskClockSource(),
         batteryState: @escaping @MainActor () -> UIDevice.BatteryState = { UIDevice.current.batteryState },
         defaults: UserDefaults = .standard,
         suspendMusic: @escaping @MainActor () -> Void = { MobileMusic.shared.suspend() },
         resumeMusic: @escaping @MainActor () -> Void = { MobileMusic.shared.resume() },
         setIdleTimerDisabled: @escaping @MainActor (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 },
         regions: @escaping @MainActor (UIView) -> [MobileReservedRegion] = { MobileSystemRegions.read(in: $0) },
         voiceOverRunning: @escaping @MainActor () -> Bool = { UIAccessibility.isVoiceOverRunning },
         reloadWidgets: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.reason = reason
        self.events = events
        eventReader = DeskClockEventReader(source: events)
        self.batteryState = batteryState
        self.defaults = defaults
        self.suspendMusic = suspendMusic
        self.resumeMusic = resumeMusic
        self.setIdleTimerDisabled = setIdleTimerDisabled
        self.regions = regions
        self.voiceOverRunning = voiceOverRunning
        self.reloadWidgets = reloadWidgets
        clockView = MobileDeskClockView(settings: .current(from: defaults))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    private var settings: DeskClockSettings { MobileSettings.load(from: defaults).deskClock }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // VoiceOver stays inside the clock and the menu beneath it is hidden.
        view.accessibilityViewIsModal = true
        view.addSubview(clockView)
        closeButton.title = L10n.text("Close")
        closeButton.isPrimary = true
        closeButton.isHidden = true
        closeButton.onPress = { [weak self] in self?.close() }
        view.addSubview(closeButton)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        layout = DeskClockLayout.make(safe: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
                                      regions: regions(view))
        guard let layout else { return }
        clockView.frame = cg(layout.scene)
        closeButton.frame = cg(layout.close)
        updateCloseVisibility()
    }

    /// The scrub gesture closes the clock, as Close does.
    override func accessibilityPerformEscape() -> Bool {
        guard isShown else { return false }
        close()
        return true
    }

    // MARK: - Show and close

    /// Adds the clock full screen over `parent`, which stays underneath.
    func present(in parent: UIViewController) {
        guard !isShown else { return }
        isShown = true
        parent.addChild(self)
        view.frame = parent.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.view.addSubview(view)
        didMove(toParent: parent)
        start()
    }

    func close() {
        guard isShown else { return }
        isShown = false
        ticker?.invalidate(); ticker = nil
        hideTask?.cancel(); hideTask = nil
        accessTask?.cancel(); accessTask = nil
        eventReader.cancel()
        clockView.event = nil
        observers = MobileNotificationObserverBag()
        clockView.stop()
        setIdleTimerDisabled(false)
        if let batteryMonitoring { UIDevice.current.isBatteryMonitoringEnabled = batteryMonitoring }
        batteryMonitoring = nil
        resumeMusic()
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
        onClose?()
    }

    /// Closes `clock` before `game` joins `parent` full screen, so a level never starts beneath the clock.
    static func attach(_ game: UIViewController, to parent: UIViewController, closing clock: MobileDeskClockController?) {
        clock?.close()
        parent.addChild(game)
        game.view.frame = parent.view.bounds
        game.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.view.addSubview(game.view)
        game.didMove(toParent: parent)
    }

    private func start() {
        suspendMusic()
        batteryMonitoring = UIDevice.current.isBatteryMonitoringEnabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateIdleTimer()
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateIdleTimer() }
        })
        observers.append(centre.addObserver(forName: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCloseVisibility() }
        })
        observers.append(centre.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clockView.isRunning = false
                self?.eventReader.cancel()
                self?.clockView.event = nil
            }
        })
        observers.append(centre.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clockView.isRunning = true
                self?.refreshEvent()
            }
        })
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
        clockView.isRunning = true
        requestCalendarIfAllowed()
        refreshEvent()
    }

    /// The screen stays on only on mains power. On battery the system can lock as usual.
    private func updateIdleTimer() {
        guard isShown else { return }
        let state = batteryState()
        setIdleTimerDisabled(state == .charging || state == .full)
    }

    // MARK: - Calendar

    /// iOS shows the access prompt only once, so `.notDetermined` alone decides whether to ask.
    private func requestCalendarIfAllowed() {
        guard reason.asksForCalendar, settings.showNextEvent, events.authorization() == .notDetermined else { return }
        let source = events
        let reloadWidgets = self.reloadWidgets
        accessTask = Task { [weak self] in
            _ = await source.requestAccess()
            // The widget reads the calendar on its own timeline. Reload it so the event shows now.
            reloadWidgets()
            guard !Task.isCancelled else { return }
            self?.refreshEvent()
        }
    }

    /// EventKit queries block, so the read runs detached and only the result returns to the main actor.
    private func refreshEvent() {
        guard isShown, clockView.isRunning else { return }
        lastRefresh = Date()
        eventReader.refresh(now: lastRefresh, enabled: settings.showNextEvent) { [weak self] next in
            guard let self, self.isShown else { return }
            self.clockView.event = next
        }
    }

    private func tick() {
        if Date().timeIntervalSince(lastRefresh) >= Self.eventRefreshInterval { refreshEvent() }
    }

    // MARK: - Close control

    /// Stacked pose and VoiceOver keep Close on screen. Otherwise a touch shows it for four seconds.
    private var closeAlwaysShown: Bool { layout?.stacked == true || voiceOverRunning() }

    private func updateCloseVisibility() {
        if closeAlwaysShown {
            hideTask?.cancel(); hideTask = nil
            closeButton.isHidden = false
        } else if hideTask == nil {
            closeButton.isHidden = true
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard isShown else { return }
        let point = gesture.location(in: view)
        if !closeButton.isHidden, closeButton.frame.contains(point) { return }
        if reason.isAutomatic { close(); return }
        if !closeAlwaysShown { revealCloseControl() }
    }

    /// Shows the close control for four seconds and moves VoiceOver to it.
    func revealCloseControl() {
        closeButton.isHidden = false
        UIAccessibility.post(notification: .layoutChanged, argument: closeButton)
        hideTask?.cancel(); hideTask = nil
        guard !closeAlwaysShown else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.closeControlDuration)
            guard !Task.isCancelled, let self else { return }
            self.hideTask = nil
            self.updateCloseVisibility()
        }
    }

    private func cg(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
