                                                            #if os(iOS)
import GameController
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit
import WidgetKit

/// Why the clock opened. Only the player's own choices may ask for calendar access.
enum DeskClockReason: Sendable {
    case menu, widget, tent, stacked, closedCharging

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
    private var presentedModally = false
    /// The library pauses its own input under the clock, so the clock reads the controller itself.
    private(set) lazy var input = makeInput()
    private var inputLink: CADisplayLink?

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
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private var settings: DeskClockSettings { MobileSettings.load(from: defaults).deskClock }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // VoiceOver stays inside the clock and the menu beneath it is hidden.
        view.accessibilityViewIsModal = true
        view.addSubview(clockView)
        closeButton.title = L10n.text("Close")
        closeButton.isPrimary = true
        closeButton.redNightVision = clockView.isRedNightVisionActive(at: Date())
        closeButton.isHidden = true
        closeButton.onPress = { [weak self] in self?.close() }
        view.addSubview(closeButton)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = MobileSystemRegions.usesFullDisplay(in: view) ? view.bounds : view.safeAreaLayoutGuide.layoutFrame
        layout = DeskClockLayout.make(safe: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
                                      regions: regions(view),
                                      bounds: MobileRect(x: view.bounds.minX, y: view.bounds.minY,
                                                         width: view.bounds.width, height: view.bounds.height))
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

    // MARK: - Keyboard and controller

    override var canBecomeFirstResponder: Bool { isShown }

    /// A hardware Escape closes the clock, as Close does.
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapePressed))]
    }

    @objc func escapePressed() { close() }

    /// B and Menu close the clock, as Close does. A acts as a touch.
    private func makeInput() -> MobileInputAdapter {
        let adapter = MobileInputAdapter()
        let defaults = defaults
        adapter.settings = { MobileSettings.current(from: defaults).classic }
        adapter.isMenu = { true }
        adapter.isActive = { [weak self] in
            self?.isShown == true && self?.view.window?.windowScene?.activationState == .foregroundActive
        }
        adapter.onMenuBack = { [weak self] in self?.close() }
        adapter.onMenuActivate = { [weak self] in
            guard let self else { return }
            if self.reason.isAutomatic { self.close() } else if !self.closeAlwaysShown { self.revealCloseControl() }
        }
        return adapter
    }

    /// The link runs only while a controller is connected.
    private func updateInputLink() {
        inputLink?.isPaused = !isShown || GCController.controllers().isEmpty
        if inputLink?.isPaused == true { input.reset() }
    }

    // MARK: - Show and close

    /// Presents above the visible controller. UIKit must own a controller's view when it
    /// crosses a window boundary; adding a child of `parent` directly to its window aborts.
    func present(in parent: UIViewController, surface: UIView? = nil) {
        guard !isShown else { return }
        isShown = true
        let window = parent.view.window ?? (surface as? UIWindow) ?? surface?.window
        if let window {
            presentedModally = true
            var presenter = parent.view.window === window ? parent : (window.rootViewController ?? parent)
            while let presented = presenter.presentedViewController { presenter = presented }
            modalPresentationStyle = .overFullScreen
            modalPresentationCapturesStatusBarAppearance = true
            presenter.present(self, animated: false) { [weak self] in
                guard let self else { return }
                guard self.isShown else { self.dismiss(animated: false); return }
                self.start()
            }
            return
        }
        // A detached test host has no window, so containment keeps layout tests headless.
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
        inputLink?.invalidate(); inputLink = nil
        input.reset()
        resignFirstResponder()
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
        if presentedModally {
            dismiss(animated: false)
        } else {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
        }
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
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateInputLink() }
            })
        }
        let target = MobileDisplayLinkTarget { [weak self] link in
            guard let self else { return }
            self.input.poll(context: ObjectIdentifier(self), at: link.timestamp)
        }
        let link = CADisplayLink(target: target, selector: #selector(MobileDisplayLinkTarget.frame(_:)))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        inputLink = link
        input.reset()
        updateInputLink()
        becomeFirstResponder()
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
        closeButton.redNightVision = clockView.isRedNightVisionActive(at: Date())
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
