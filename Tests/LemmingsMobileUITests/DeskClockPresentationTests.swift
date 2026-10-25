#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
@testable import LemmingsMobileUI

/// Records every access request so a test can prove that automatic openings never ask.
private final class FakeDeskClockEvents: DeskClockEventSource, @unchecked Sendable {
    private let lock = NSLock()
    private let access: DeskClockCalendarAccess
    private let event: DeskClockEvent?
    private var requestCount = 0

    init(access: DeskClockCalendarAccess, event: DeskClockEvent? = nil) {
        self.access = access
        self.event = event
    }

    var requests: Int { lock.withLock { requestCount } }
    func authorization() -> DeskClockCalendarAccess { access }
    func requestAccess() async -> Bool {
        lock.withLock { requestCount += 1 }
        return false
    }
    func nextEvent(now: Date) async -> DeskClockEvent? { event }
}

@MainActor private final class DeskClockFixture {
    let suite = "desk-clock-tests-" + UUID().uuidString
    let defaults: UserDefaults
    let events: FakeDeskClockEvents
    let host = UIViewController()
    var battery = UIDevice.BatteryState.unplugged
    var regions: [MobileReservedRegion] = []
    var voiceOver = false
    var idleTimer: [Bool] = []
    var suspends = 0
    var resumes = 0
    var widgetReloads = 0

    init(access: DeskClockCalendarAccess = .notDetermined, size: CGSize = CGSize(width: 465, height: 650)) {
        defaults = UserDefaults(suiteName: suite)!
        events = FakeDeskClockEvents(access: access)
        host.view.frame = CGRect(origin: .zero, size: size)
    }

    deinit { UserDefaults().removePersistentDomain(forName: suite) }

    func clock(_ reason: DeskClockReason) -> MobileDeskClockController {
        MobileDeskClockController(reason: reason, events: events,
            batteryState: { [unowned self] in self.battery }, defaults: defaults,
            suspendMusic: { [unowned self] in self.suspends += 1 },
            resumeMusic: { [unowned self] in self.resumes += 1 },
            setIdleTimerDisabled: { [unowned self] in self.idleTimer.append($0) },
            regions: { [unowned self] _ in self.regions },
            voiceOverRunning: { [unowned self] in self.voiceOver },
            reloadWidgets: { [unowned self] in self.widgetReloads += 1 })
    }

    func open(_ reason: DeskClockReason) async -> MobileDeskClockController {
        let clock = clock(reason)
        clock.present(in: host)
        host.view.layoutIfNeeded()
        await clock.accessTask?.value
        await clock.eventTask?.value
        return clock
    }
}

@MainActor struct DeskClockPresentationTests {
    @Test func windowBackedClockUsesUIKitPresentation() {
        let fixture = DeskClockFixture(access: .denied)
        let window = UIWindow(frame: fixture.host.view.bounds)
        window.rootViewController = fixture.host
        window.isHidden = false
        defer { window.isHidden = true }

        let clock = fixture.clock(.menu)
        clock.present(in: fixture.host, surface: window)
        #expect(clock.modalPresentationStyle == .overFullScreen)
        #expect(clock.presentingViewController === fixture.host)
        #expect(clock.parent == nil)
        #expect(clock.view.superview !== window)
        clock.close()
        #expect(!clock.isShown && clock.view.superview == nil)
    }

    @Test func menuOpensClock() async {
        let home = MobileHomeArt.page(journey: nil, families: [], initials: "PLA", deskClock: true)
        let footer = home.footer.map(\.id)
        #expect(footer.firstIndex(of: "deskClock").map { $0 + 1 } == footer.firstIndex(of: "settings"))
        #expect(!MobileHomeArt.page(journey: nil, families: [], initials: "PLA").footer.contains { $0.id == "deskClock" })

        let fixture = DeskClockFixture()
        let clock = await fixture.open(.menu)
        #expect(fixture.host.children.contains { $0 === clock })
        #expect(clock.view.superview === fixture.host.view)
        #expect(clock.view.frame == fixture.host.view.bounds)
        #expect(fixture.suspends == 1)
        #expect(fixture.events.requests == 1)
        // Widgets reload after the answer, so they show the event without waiting for their timeline.
        #expect(fixture.widgetReloads == 1)
        clock.close()

        // The system decides. While access is still undetermined, a menu or widget opening asks again.
        let widget = await fixture.open(.widget)
        #expect(fixture.events.requests == 2 && fixture.widgetReloads == 2)
        widget.close()

        // Once the player answered, no opening asks.
        for access in [DeskClockCalendarAccess.granted, .denied] {
            let answered = DeskClockFixture(access: access)
            for reason in [DeskClockReason.menu, .widget] {
                let clock = await answered.open(reason)
                #expect(answered.events.requests == 0 && answered.widgetReloads == 0, "\(access) \(reason)")
                clock.close()
            }
        }
    }

    @Test func closeRestoresMusicAndIdleTimer() async {
        let fixture = DeskClockFixture()
        fixture.battery = .charging
        var closed = 0
        let clock = await fixture.open(.menu)
        clock.onClose = { closed += 1 }
        #expect(fixture.idleTimer.last == true)
        #expect(fixture.suspends == 1 && fixture.resumes == 0)
        clock.close()
        #expect(fixture.idleTimer.last == false)
        #expect(fixture.resumes == 1)
        #expect(closed == 1)
        #expect(clock.parent == nil && clock.view.superview == nil)

        // On battery the system keeps its own screen lock.
        fixture.battery = .unplugged
        fixture.idleTimer.removeAll()
        let unplugged = await fixture.open(.menu)
        #expect(!fixture.idleTimer.contains(true))
        unplugged.close()
        #expect(fixture.idleTimer.last == false)
    }

    @Test func stackedUsesTopPane() async {
        let fixture = DeskClockFixture()
        fixture.regions = [.init(kind: .division, frame: .init(x: 0, y: 318, width: 465, height: 14))]
        let clock = await fixture.open(.stacked)
        clock.view.layoutIfNeeded()
        #expect(clock.clockView.frame == CGRect(x: 0, y: 0, width: 465, height: 318))
        let bottom = CGRect(x: 0, y: 332, width: 465, height: 318)
        #expect(!clock.closeButton.isHidden)
        #expect(bottom.contains(clock.closeButton.frame))
        #expect(clock.closeButton.frame.width >= 44 && clock.closeButton.frame.height >= 44)
        #expect(clock.closeButton.accessibilityLabel?.isEmpty == false)
        // The scene above shows the event. The lower pane holds Close and nothing else.
        let lower = clock.view.subviews.filter { !$0.isHidden && $0.frame.intersects(bottom) }
        #expect(lower.count == 1 && lower.first === clock.closeButton)
        #expect(!clock.clockView.frame.intersects(bottom))
        clock.close()

        // Closed poses hide the control until a touch.
        fixture.regions = []
        let closed = await fixture.open(.closedCharging)
        closed.view.layoutIfNeeded()
        #expect(closed.clockView.frame == fixture.host.view.bounds)
        #expect(closed.closeButton.isHidden)
        closed.revealCloseControl()
        #expect(!closed.closeButton.isHidden)
        closed.close()
    }

    @Test func clockIsModalAndEscapeCloses() async {
        let fixture = DeskClockFixture()
        fixture.battery = .full
        fixture.voiceOver = true
        let clock = await fixture.open(.closedCharging)
        clock.view.layoutIfNeeded()
        #expect(clock.view.accessibilityViewIsModal)
        // VoiceOver keeps Close on screen and in the accessibility tree in every pose.
        #expect(!clock.closeButton.isHidden && clock.closeButton.isAccessibilityElement)
        #expect(clock.accessibilityPerformEscape())
        #expect(clock.parent == nil && fixture.resumes == 1 && fixture.idleTimer.last == false)
        #expect(!clock.accessibilityPerformEscape())
    }

    @Test func backAndEscapeCloseTheClock() async {
        // Controller B and Menu close a menu, widget or automatic clock, as Close does.
        for (reason, action) in [(DeskClockReason.menu, ControllerBindings.Action.cancel), (.widget, .pause),
                                 (.stacked, .cancel), (.closedCharging, .pause)] {
            let fixture = DeskClockFixture()
            fixture.battery = .charging
            let clock = await fixture.open(reason)
            #expect(fixture.idleTimer.last == true, "\(reason)")
            clock.input.perform(action)
            #expect(clock.parent == nil && !clock.isShown, "\(reason)")
            #expect(fixture.idleTimer.last == false && fixture.resumes == 1, "\(reason)")
        }

        // A hardware Escape does the same.
        let fixture = DeskClockFixture()
        fixture.battery = .full
        let clock = await fixture.open(.menu)
        #expect(clock.canBecomeFirstResponder)
        let escape = clock.keyCommands?.first { $0.input == UIKeyCommand.inputEscape && $0.modifierFlags.isEmpty }
        #expect(escape != nil)
        if let action = escape?.action { clock.perform(action) }
        #expect(clock.parent == nil && fixture.idleTimer.last == false && fixture.resumes == 1)
        #expect(!clock.canBecomeFirstResponder)

        // A acts as a touch: it shows Close on a menu clock and closes an automatic one.
        let menuFixture = DeskClockFixture()
        let menu = await menuFixture.open(.menu)
        menu.input.perform(.assign)
        #expect(menu.isShown && !menu.closeButton.isHidden)
        menu.close()
        let automaticFixture = DeskClockFixture()
        let automatic = await automaticFixture.open(.closedCharging)
        automatic.input.perform(.assign)
        #expect(!automatic.isShown && automaticFixture.resumes == 1)
    }

    @Test func voiceOverKeepsCloseInEveryPose() async {
        let poses: [(DeskClockReason, [MobileReservedRegion])] = [
            (.stacked, [.init(kind: .division, frame: .init(x: 0, y: 318, width: 465, height: 14))]),
            (.menu, [.init(kind: .division, frame: .init(x: 226, y: 0, width: 14, height: 650))]),
            (.closedCharging, []),
            (.widget, [])]
        for (reason, regions) in poses {
            let fixture = DeskClockFixture()
            fixture.battery = .charging
            fixture.voiceOver = true
            fixture.regions = regions
            let clock = await fixture.open(reason)
            clock.view.layoutIfNeeded()
            #expect(clock.view.accessibilityViewIsModal, "\(reason)")
            #expect(!clock.closeButton.isHidden && clock.closeButton.isAccessibilityElement, "\(reason)")
            #expect(fixture.host.view.bounds.contains(clock.closeButton.frame), "\(reason)")
            #expect(clock.closeButton.accessibilityLabel?.isEmpty == false, "\(reason)")
            clock.close()
        }
    }

    @Test func startingGameClosesClock() async {
        let fixture = DeskClockFixture()
        fixture.battery = .charging
        let clock = await fixture.open(.menu)
        #expect(fixture.idleTimer.last == true)
        let game = UIViewController()
        MobileDeskClockController.attach(game, to: fixture.host, closing: clock)
        #expect(clock.parent == nil && clock.view.superview == nil)
        #expect(fixture.resumes == 1 && fixture.idleTimer.last == false)
        #expect(game.parent === fixture.host && fixture.host.view.subviews.last === game.view)
        #expect(game.view.frame == fixture.host.view.bounds)
    }

    @Test func settingsListsDeskClockOnlyInTheMenu() {
        let id = "settingsGroup." + MobileSettingsGroup.deskClock.rawValue
        #expect(MobileSettingsArt.groups().rows.contains { $0.id == id })
        #expect(!MobileSettingsArt.groups(inGame: true).rows.contains { $0.id == id })
        #expect(!MobileSettingsArt.groups(television: true).rows.contains { $0.id == id })
    }

    @Test func redNightVisionSettingHasAVisibleToggleAndNightBoundary() {
        var settings = MobileSettings()
        let key = "setting.deskClockRedNight"
        let off = MobileSettingsArt.page(.deskClock, settings: settings).rows.first { $0.id == key }
        #expect(off?.toggleValue == false)
        settings.deskClock.redNightVision = true
        let on = MobileSettingsArt.page(.deskClock, settings: settings).rows.first { $0.id == key }
        #expect(on?.toggleValue == true)
        let view = MobileDeskClockView(settings: settings)
        let calendar = Calendar.current
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 23))!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 12))!
        #expect(view.isRedNightVisionActive(at: night))
        #expect(!view.isRedNightVisionActive(at: day))
    }

    @Test func accessibilityLabelReadsTimeAndEvent() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let locale = Locale(identifier: "en_GB")
        let now = Date(timeIntervalSince1970: 1_792_143_000) // 09:30 UTC
        let event = DeskClockEvent(start: now.addingTimeInterval(5 * 60), title: "Standup", nuke: false)
        #expect(MobileDeskClockView.accessibilityLabel(now: now, event: event, locale: locale, calendar: calendar)
            == "09:30. Next: Standup at 09:35, IN 5 MINUTES")
        #expect(MobileDeskClockView.accessibilityLabel(now: now, event: nil, locale: locale, calendar: calendar) == "09:30")
        let view = MobileDeskClockView()
        #expect(view.isAccessibilityElement)
    }

    @Test func noCalendarPromptForAutomaticReasons() async {
        for reason in [DeskClockReason.stacked, .closedCharging] {
            let fixture = DeskClockFixture()
            let clock = await fixture.open(reason)
            #expect(fixture.events.requests == 0 && fixture.widgetReloads == 0)
            clock.close()
        }
        // Show next event off: the menu does not ask either.
        let fixture = DeskClockFixture()
        var settings = MobileSettings.load(from: fixture.defaults)
        settings.deskClock.showNextEvent = false
        settings.save(to: fixture.defaults)
        let clock = await fixture.open(.menu)
        #expect(fixture.events.requests == 0)
        clock.close()
    }
}
#endif
