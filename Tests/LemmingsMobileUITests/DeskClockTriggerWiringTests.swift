#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

private final class SilentDeskClockEvents: DeskClockEventSource, @unchecked Sendable {
    func authorization() -> DeskClockCalendarAccess { .denied }
    func requestAccess() async -> Bool { false }
    func nextEvent(now: Date) async -> DeskClockEvent? { nil }
}

/// A menu that hosts the clock with injected pose, power and idle time.
@MainActor private final class WiringHost: UIViewController, DeskClockHost {
    let suite = "desk-clock-wiring-" + UUID().uuidString
    lazy var defaults = UserDefaults(suiteName: suite)!
    var deskClock: MobileDeskClockController?
    var deskClockScreen = DeskClockScreen.menu
    var deskClockSettings = DeskClockSettings()
    var deskClockRegionView: UIView { view }
    var regions: [MobileReservedRegion] = []
    var charging = false
    var clockTime: TimeInterval = 1_000
    var idleTimer: [Bool] = []
    var presented: [DeskClockReason] = []
    var voiceOver = false
    lazy var entry = DeskClockAutomaticEntry(foldable: { _ in true }, regions: { [unowned self] _ in self.regions },
                                             charging: { [unowned self] in self.charging },
                                             uptime: { [unowned self] in self.clockTime },
                                             voiceOverRunning: { [unowned self] in self.voiceOver })

    static let stacked = [MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 318, width: 465, height: 14))]
    static let book = [MobileReservedRegion(kind: .division, frame: .init(x: 226, y: 0, width: 14, height: 650))]

    func presentDeskClock(reason: DeskClockReason) {
        guard deskClock == nil else { return }
        presented.append(reason)
        let clock = MobileDeskClockController(reason: reason, events: SilentDeskClockEvents(),
            batteryState: { [unowned self] in self.charging ? .charging : .unplugged }, defaults: defaults,
            suspendMusic: {}, resumeMusic: {},
            setIdleTimerDisabled: { [unowned self] in self.idleTimer.append($0) },
            regions: { [unowned self] _ in self.regions }, voiceOverRunning: { false })
        clock.onClose = { [weak self, weak clock] in
            guard let self, self.deskClock === clock else { return }
            self.deskClock = nil
            self.entry.noteDismissal(reason: reason)
        }
        deskClock = clock
        clock.present(in: self)
    }

    func dismissDeskClock() { deskClock?.close() }

    func check() {
        view.layoutIfNeeded()
        entry.check(self)
    }

    deinit { UserDefaults().removePersistentDomain(forName: suite) }
}

@MainActor struct DeskClockTriggerWiringTests {
    private func host() -> WiringHost {
        let host = WiringHost()
        host.view.frame = CGRect(x: 0, y: 0, width: 465, height: 650)
        host.entry.noteInput()
        return host
    }

    @Test func hingeCapabilityKeepsOuterDisplayLayoutsFullWidth() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 720, height: 495))
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        MobileSystemRegions.noteHinge(in: window)
        #expect(MobileSystemRegions.isFoldable(in: view))
        #expect(MobileSystemRegions.usesFullDisplay(in: view))
        #expect(MobileSystemRegions.menuFrame(in: view) == view.bounds)
        #expect(MobileSystemRegions.contentInsets(in: view) == .zero)
        #expect(window.isHidden)
    }

    @Test func hingeObserverAttachesToSceneContentView() {
        let host = host()
        host.entry.observePose(in: host.view)
        #if compiler(>=6.3)
        if #available(iOS 27.1, *) {
            #expect(host.view.interactions.contains { $0 is UIHingeInteraction })
        }
        #endif
    }

    @Test func tentPresentsOverEveryScreenAndWaitsAfterDismissal() {
        for screen in [DeskClockScreen.menu, .level, .replay, .pause, .handover, .modal] {
            let host = host()
            host.view.frame.size = CGSize(width: 720, height: 495)
            host.deskClockScreen = screen
            host.entry.hinge = .partiallyOpen
            host.check()
            #expect(host.presented == [.tent])
            host.dismissDeskClock()
            host.check()
            #expect(host.presented == [.tent])
            host.entry.hinge = .fullyOpen
            host.check()
            host.entry.hinge = .partiallyOpen
            host.check()
            #expect(host.presented == [.tent, .tent])
            host.dismissDeskClock()
        }
    }

    @Test func leavingAndReenteringTentReopensWithoutAnExtraCheck() {
        let host = host()
        host.view.frame.size = CGSize(width: 720, height: 495)
        host.entry.hinge = .partiallyOpen
        host.check()
        #expect(host.presented == [.tent])
        host.entry.hinge = .fullyOpen
        host.check()
        #expect(host.deskClock == nil)
        host.entry.hinge = .partiallyOpen
        host.check()
        #expect(host.presented == [.tent, .tent])
        host.dismissDeskClock()
    }

    @Test func idleStackedPresents() {
        let host = host()
        host.regions = WiringHost.stacked
        host.clockTime += 59
        host.check()
        #expect(host.presented.isEmpty)
        host.clockTime += 1
        host.check()
        #expect(host.presented == [.stacked])
        #expect(host.deskClock?.isShown == true)
        host.dismissDeskClock()
    }

    @Test func levelBlocksTrigger() {
        let host = host()
        host.regions = WiringHost.stacked
        host.charging = true
        host.clockTime += 600
        for screen in [DeskClockScreen.level, .replay, .pause, .handover, .modal] {
            host.deskClockScreen = screen
            host.check()
        }
        #expect(host.presented.isEmpty)
        #expect(host.deskClock == nil)
    }

    @Test func poseChangeClosesAutomaticClock() throws {
        let host = host()
        host.regions = WiringHost.stacked
        host.charging = true
        host.clockTime += 60
        host.check()
        let clock = try #require(host.deskClock)
        #expect(clock.reason == .stacked)
        #expect(host.idleTimer.last == true)
        // The idle time does not matter while the clock shows: only the pose does. A touch on the clock keeps it.
        host.entry.noteInput()
        host.check()
        #expect(host.deskClock === clock)
        #expect(clock.isShown)
        host.regions = WiringHost.book
        host.check()
        #expect(host.deskClock == nil)
        #expect(!clock.isShown)
        #expect(host.idleTimer.last == false)
    }

    @Test func chargerRemovedClosesChargingClock() {
        let host = host()
        host.charging = true
        host.clockTime += 60
        host.check()
        #expect(host.presented == [.closedCharging])
        host.charging = false
        host.check()
        #expect(host.deskClock == nil)
        #expect(host.idleTimer.last == false)

        // A clock the player opened stays when the charger goes.
        host.presentDeskClock(reason: .menu)
        host.check()
        #expect(host.deskClock?.reason == .menu)
        host.dismissDeskClock()
    }

    @Test func onlyHomeOpensAutomatically() {
        #expect(DeskClockAutomaticEntry.screen(game: nil, home: true, textEditing: false, blocked: false) == .menu)
        #expect(DeskClockAutomaticEntry.screen(game: nil, home: false, textEditing: false, blocked: false) == .modal)
        #expect(DeskClockAutomaticEntry.screen(game: .pause, home: true, textEditing: false, blocked: false) == .pause)
        #expect(DeskClockAutomaticEntry.screen(game: nil, home: true, textEditing: false, blocked: true) == .modal)
        let host = host()
        host.regions = WiringHost.stacked
        host.clockTime += 600
        host.deskClockScreen = DeskClockAutomaticEntry.screen(game: nil, home: false, textEditing: false, blocked: false)
        host.check()
        #expect(host.presented.isEmpty)
    }

    @Test func activeTextFieldNeverOpens() {
        #expect(DeskClockAutomaticEntry.screen(game: nil, home: true, textEditing: true, blocked: false) == .modal)
        let host = host()
        host.regions = WiringHost.stacked
        host.clockTime += 600
        host.deskClockScreen = DeskClockAutomaticEntry.screen(game: nil, home: true, textEditing: true, blocked: false)
        host.check()
        #expect(host.presented.isEmpty)
    }

    @Test func voiceOverNeverOpensButKeepsAShownClock() {
        let host = host()
        host.regions = WiringHost.stacked
        host.clockTime += 600
        host.voiceOver = true
        host.check()
        #expect(host.presented.isEmpty)
        // A clock that opened before VoiceOver started stays while its pose holds.
        host.voiceOver = false
        host.check()
        #expect(host.presented == [.stacked])
        host.voiceOver = true
        host.check()
        #expect(host.deskClock?.isShown == true)
        host.dismissDeskClock()
    }
}
#endif
