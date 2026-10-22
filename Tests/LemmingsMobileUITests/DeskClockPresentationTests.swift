#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
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
    var idleTimer: [Bool] = []
    var suspends = 0
    var resumes = 0

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
            regions: { [unowned self] _ in self.regions })
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
        #expect(MobileSettings.load(from: fixture.defaults).deskClock.calendarRequested)
        clock.close()

        // The request happens once. A later menu opening never asks again.
        let again = await fixture.open(.menu)
        #expect(fixture.events.requests == 1)
        again.close()
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
            #expect(fixture.events.requests == 0)
            #expect(!MobileSettings.load(from: fixture.defaults).deskClock.calendarRequested)
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
