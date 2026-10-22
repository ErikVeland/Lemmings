#if os(iOS)
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

/**
 * A silent, explicitly dismissible clock. Calendar and time sources can be replaced in tests.
 */
@MainActor final class MobileDeskClockController: UIViewController {
    let reason: DeskClockReason
    var onClose: (() -> Void)?
    private let source: any DeskClockEventSource
    private let now: () -> Date
    private let settings: DeskClockSettings
    private let scene: MobileDeskClockView
    private let close = MobilePixelButton()
    private let eventScroll = MobileMenuScrollView()
    private let eventDetails = MobilePixelLabel()
    private var started = false
    private var task: Task<Void, Never>?
    private var oldIdleTimer = false
    private var observers: [NSObjectProtocol] = []

    init(reason: DeskClockReason, settings: MobileSettings, source: any DeskClockEventSource = EventKitDeskClockSource(),
         now: @escaping () -> Date = Date.init) {
        self.reason = reason
        self.settings = settings.deskClock
        self.source = source
        self.now = now
        scene = MobileDeskClockView(now: now(), settings: settings)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override var canBecomeFirstResponder: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(closeFromKeyboard))]
    }
    @objc private func closeFromKeyboard() { onClose?() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(scene)
        eventDetails.wraps = true
        eventDetails.preservesCase = true
        eventDetails.alignment = .left
        eventScroll.addSubview(eventDetails)
        view.addSubview(eventScroll)
        close.title = L10n.text("Close")
        close.accessibilityIdentifier = "deskClock.close"
        close.onPress = { [weak self] in self?.onClose?() }
        view.addSubview(close)
        let tap = UITapGestureRecognizer(target: self, action: #selector(touched))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        UIDevice.current.isBatteryMonitoringEnabled = true
        for name in [UIDevice.batteryStateDidChangeNotification, UIApplication.didBecomeActiveNotification,
                     UIApplication.willResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if name == UIApplication.willResignActiveNotification { UIApplication.shared.isIdleTimerDisabled = false }
                    else { self?.refreshPower() }
                }
            })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }

    func start() {
        guard !started else { return }
        started = true
        becomeFirstResponder()
        oldIdleTimer = UIApplication.shared.isIdleTimerDisabled
        refreshPower()
        MobileMusic.shared.suspend()
        task = Task { [weak self] in
            guard let self else { return }
            if self.settings.showNextEvent && (self.reason == .menu || self.reason == .widget) {
                _ = await self.source.requestAccess()
            }
            var refreshAt = Date.distantPast
            while !Task.isCancelled {
                let date = self.now()
                if date >= refreshAt || refreshAt.timeIntervalSince(date) > 30 {
                    self.scene.event = self.settings.showNextEvent ? self.source.nextEvent(now: date) : nil
                    self.eventDetails.text = self.scene.event.map {
                        $0.title + "\n\n" + $0.start.formatted(date: .omitted, time: .shortened)
                    } ?? ""
                    self.view.setNeedsLayout()
                    refreshAt = date.addingTimeInterval(15)
                }
                if self.view.window?.windowScene?.activationState == .foregroundActive {
                    self.scene.advance(to: date)
                }
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    func stop() {
        guard started else { return }
        started = false
        task?.cancel(); task = nil
        UIApplication.shared.isIdleTimerDisabled = oldIdleTimer
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func refreshPower() {
        let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        UIApplication.shared.isIdleTimerDisabled = charging && view.window?.windowScene?.activationState == .foregroundActive
        if reason == .closedCharging && !charging { onClose?() }
    }
    @objc private func touched() {
        if reason == .stacked || reason == .closedCharging { onClose?() }
        else { close.isHidden = false }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        let regions = MobileSystemRegions.read(in: view)
        let panes = MobileDisplayRegions.tablePanes(in: .init(x: safe.minX, y: safe.minY, width: safe.width, height: safe.height), avoiding: regions)
        let region = MobileSystemRegions.menuFrame(in: view)
        if panes.count == 2 {
            scene.frame = CGRect(x: panes[0].x, y: panes[0].y, width: panes[0].width, height: panes[0].height)
            close.frame = CGRect(x: panes[1].minX + 12, y: panes[1].maxY - 60, width: 132, height: 48)
            eventScroll.isHidden = false
            eventScroll.frame = CGRect(x: panes[1].minX + 24, y: panes[1].minY + 24,
                width: panes[1].width - 48, height: max(0, panes[1].height - 100))
            let height = GameTextLayout.height(eventDetails.text, width: eventScroll.bounds.width)
            eventDetails.frame = CGRect(x: 0, y: 0, width: eventScroll.bounds.width, height: height)
            eventScroll.contentSize = eventDetails.frame.size
        } else {
            eventScroll.isHidden = true
            scene.frame = region.insetBy(dx: 4, dy: 4)
            scene.frame.size.height = max(0, scene.frame.height - 64)
            close.frame = CGRect(x: region.minX + 12, y: region.maxY - 60, width: 132, height: 48)
        }
        if reason == .stacked && panes.isEmpty { onClose?() }
        if reason == .closedCharging && regions.contains(where: { $0.kind == .division }) { onClose?() }
    }
}

@MainActor final class MobileDeskClockView: UIView {
    var event: DeskClockEvent?
    private var simulation: DeskClockSimulation
    private var date: Date
    private let art: GameDeskClockArt?

    init(now: Date, settings: MobileSettings) {
        date = now
        simulation = DeskClockSimulation(now: now, uses24Hour: DeskClockFace.uses24Hour(locale: .current),
            reduceMotion: settings.classic.reduceMotion || UIAccessibility.isReduceMotionEnabled,
            reduceFlashes: settings.classic.reduceFlashes, seed: UInt64(max(0, now.timeIntervalSince1970)))
        art = Bundle.main.resourceURL.flatMap { GameDeskClockArt(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
        super.init(frame: .zero)
        backgroundColor = .black
        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently
        accessibilityIdentifier = "deskClock.time"
    }
    required init?(coder: NSCoder) { nil }

    func advance(to now: Date) {
        date = now
        simulation.advance(to: now, event: event)
        let details = event.map { [$0.title, DeskClockFace.countdown(to: $0.start, now: now)] } ?? []
        accessibilityLabel = ([now.formatted(date: .omitted, time: .shortened)] + details).joined(separator: ". ")
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let shift = DeskClockFace.burnInOffset(at: date)
        art?.draw(simulation, event: event, now: date, in: context,
            rect: bounds.insetBy(dx: 2, dy: 2).offsetBy(dx: CGFloat(shift.x), dy: CGFloat(shift.y)))
    }
}

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
