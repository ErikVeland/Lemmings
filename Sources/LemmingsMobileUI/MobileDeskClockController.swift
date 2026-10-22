#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

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
    private let eventLines = [MobilePixelLabel(), MobilePixelLabel()]
    private let events: any DeskClockEventSource
    private let batteryState: @MainActor () -> UIDevice.BatteryState
    private let defaults: UserDefaults
    private let suspendMusic: @MainActor () -> Void
    private let resumeMusic: @MainActor () -> Void
    private let setIdleTimerDisabled: @MainActor (Bool) -> Void
    private let regions: @MainActor (UIView) -> [MobileReservedRegion]
    var onClose: (() -> Void)?
    private(set) var accessTask: Task<Void, Never>?
    private(set) var eventTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var ticker: Timer?
    private var lastRefresh = Date.distantPast
    private var layout: DeskClockLayout?
    private var batteryMonitoring: Bool?
    private var observers = MobileNotificationObserverBag()
    private var shown = false

    init(reason: DeskClockReason,
         events: any DeskClockEventSource = EventKitDeskClockSource(),
         batteryState: @escaping @MainActor () -> UIDevice.BatteryState = { UIDevice.current.batteryState },
         defaults: UserDefaults = .standard,
         suspendMusic: @escaping @MainActor () -> Void = { MobileMusic.shared.suspend() },
         resumeMusic: @escaping @MainActor () -> Void = { MobileMusic.shared.resume() },
         setIdleTimerDisabled: @escaping @MainActor (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 },
         regions: @escaping @MainActor (UIView) -> [MobileReservedRegion] = { MobileSystemRegions.read(in: $0) }) {
        self.reason = reason
        self.events = events
        self.batteryState = batteryState
        self.defaults = defaults
        self.suspendMusic = suspendMusic
        self.resumeMusic = resumeMusic
        self.setIdleTimerDisabled = setIdleTimerDisabled
        self.regions = regions
        clockView = MobileDeskClockView(settings: .current(from: defaults))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    private var settings: DeskClockSettings { MobileSettings.load(from: defaults).deskClock }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(clockView)
        for line in eventLines {
            line.palette = .green
            line.maximumScale = 3
            line.face = .large
            line.isHidden = true
            view.addSubview(line)
        }
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
        let next = DeskClockLayout.make(safe: MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height),
                                        regions: regions(view))
        let wasStacked = layout?.stacked
        layout = next
        clockView.frame = cg(next.scene)
        closeButton.frame = cg(next.close)
        for (line, frame) in zip(eventLines, next.lines) { line.frame = cg(frame) }
        if next.stacked {
            hideTask?.cancel()
            closeButton.isHidden = false
        } else if wasStacked == true {
            closeButton.isHidden = true
        }
        updateLines(now: Date())
    }

    // MARK: - Show and close

    /// Adds the clock full screen over `parent`, which stays underneath.
    func present(in parent: UIViewController) {
        guard !shown else { return }
        shown = true
        parent.addChild(self)
        view.frame = parent.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.view.addSubview(view)
        didMove(toParent: parent)
        start()
    }

    func close() {
        guard shown else { return }
        shown = false
        ticker?.invalidate(); ticker = nil
        hideTask?.cancel(); hideTask = nil
        accessTask?.cancel(); eventTask?.cancel()
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

    private func start() {
        suspendMusic()
        batteryMonitoring = UIDevice.current.isBatteryMonitoringEnabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateIdleTimer()
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateIdleTimer() }
        })
        observers.append(centre.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.clockView.isRunning = false }
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
        guard shown else { return }
        let state = batteryState()
        setIdleTimerDisabled(state == .charging || state == .full)
    }

    // MARK: - Calendar

    private func requestCalendarIfAllowed() {
        var stored = MobileSettings.load(from: defaults)
        guard reason.asksForCalendar, stored.deskClock.showNextEvent, !stored.deskClock.calendarRequested,
              events.authorization() == .notDetermined else { return }
        stored.deskClock.calendarRequested = true
        stored.save(to: defaults)
        let source = events
        accessTask = Task { [weak self] in
            _ = await source.requestAccess()
            self?.refreshEvent()
        }
    }

    /// EventKit queries block, so the read runs detached and only the result returns to the main actor.
    private func refreshEvent() {
        lastRefresh = Date()
        guard settings.showNextEvent else {
            clockView.event = nil
            updateLines(now: lastRefresh)
            return
        }
        let source = events, now = lastRefresh
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            let next = await Task.detached { await source.nextEvent(now: now) }.value
            guard !Task.isCancelled, let self else { return }
            self.clockView.event = next
            self.updateLines(now: Date())
        }
    }

    private func tick() {
        let now = Date()
        if now.timeIntervalSince(lastRefresh) >= Self.eventRefreshInterval { refreshEvent() }
        updateLines(now: now)
    }

    /// Stacked pose repeats the next event below the hinge in menu lettering.
    private func updateLines(now: Date) {
        guard let layout, layout.stacked, let event = clockView.event else {
            for line in eventLines { line.isHidden = true }
            return
        }
        let digits = Array(DeskClockFace.digits(for: event.start, uses24Hour: DeskClockFace.uses24Hour(locale: .current),
                                                calendar: .current))
        let start = String(digits[0..<2]).trimmingCharacters(in: .whitespaces) + ":" + String(digits[2..<4])
        let texts = [L10n.text("NEXT") + "  " + start + "  " + event.title,
                     DeskClockFace.countdown(to: event.start, now: now)]
        for (line, text) in zip(eventLines, texts) {
            if line.text != text { line.text = text }
            line.isHidden = false
        }
    }

    // MARK: - Touch

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard shown else { return }
        let point = gesture.location(in: view)
        if !closeButton.isHidden, closeButton.frame.contains(point) { return }
        if reason.isAutomatic { close(); return }
        if layout?.stacked != true { revealCloseControl() }
    }

    /// Shows the close control for four seconds. Stacked pose always shows it.
    func revealCloseControl() {
        closeButton.isHidden = false
        hideTask?.cancel()
        guard layout?.stacked != true else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.closeControlDuration)
            guard !Task.isCancelled, let self, self.layout?.stacked != true else { return }
            self.closeButton.isHidden = true
        }
    }

    private func cg(_ rect: MobileRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }
}
#endif
