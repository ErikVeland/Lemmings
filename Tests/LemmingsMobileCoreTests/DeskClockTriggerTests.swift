import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite struct DeskClockTriggerTests {
    private static let stackedSafe = MobileRect(x: 0, y: 0, width: 834, height: 1194)
    private static let bookSafe = MobileRect(x: 0, y: 0, width: 1194, height: 834)
    private static let stackedDivision = MobileReservedRegion(kind: .division, frame: MobileRect(x: 0, y: 577, width: 834, height: 40))
    private static let bookDivision = MobileReservedRegion(kind: .division, frame: MobileRect(x: 577, y: 0, width: 40, height: 834))

    private func input(foldable: Bool = true, stacked: Bool = false, book: Bool = false, idle: TimeInterval = 60,
                       charging: Bool = false, screen: DeskClockScreen = .menu,
                       settings: DeskClockSettings = DeskClockSettings()) -> DeskClockTriggerInput {
        let safe = book ? Self.bookSafe : Self.stackedSafe
        let regions = stacked ? [Self.stackedDivision] : (book ? [Self.bookDivision] : [])
        return DeskClockTriggerInput(foldable: foldable, regions: regions, safe: safe, idle: idle,
                                     charging: charging, screen: screen, settings: settings)
    }

    @Test func stackedIdleOpens() {
        #expect(DeskClockTrigger.evaluate(input(stacked: true)) == .stacked)
    }

    @Test func stackedTooSoon() {
        #expect(DeskClockTrigger.evaluate(input(stacked: true, idle: 59)) == .none)
    }

    @Test func closedChargingOpens() {
        #expect(DeskClockTrigger.evaluate(input(charging: true)) == .closedCharging)
    }

    @Test func closedNotChargingStaysClosed() {
        #expect(DeskClockTrigger.evaluate(input()) == .none)
    }

    @Test func occlusionOnlyCountsAsClosed() {
        var value = input(charging: true)
        value.regions = [MobileReservedRegion(kind: .occlusion, frame: MobileRect(x: 400, y: 0, width: 40, height: 40))]
        #expect(DeskClockTrigger.evaluate(value) == .closedCharging)
    }

    @Test func notFoldableNeverOpens() {
        #expect(DeskClockTrigger.evaluate(input(foldable: false, idle: 600, charging: true)) == .none)
        #expect(DeskClockTrigger.evaluate(input(foldable: false, stacked: true, idle: 600, charging: true)) == .none)
    }

    @Test func blockedScreens() {
        for screen in [DeskClockScreen.level, .replay, .pause, .handover, .modal] {
            #expect(DeskClockTrigger.evaluate(input(stacked: true, charging: true, screen: screen)) == .none)
            #expect(DeskClockTrigger.evaluate(input(charging: true, screen: screen)) == .none)
        }
    }

    @Test func settingsOff() {
        var stackedOff = DeskClockSettings()
        stackedOff.openWhenStacked = false
        #expect(DeskClockTrigger.evaluate(input(stacked: true, settings: stackedOff)) == .none)
        var chargingOff = DeskClockSettings()
        chargingOff.openWhenCharging = false
        #expect(DeskClockTrigger.evaluate(input(charging: true, settings: chargingOff)) == .none)
    }

    @Test func bookPoseIsNotStacked() {
        #expect(DeskClockTrigger.evaluate(input(book: true)) == .none)
        #expect(DeskClockTrigger.evaluate(input(book: true, charging: true)) == .none)
    }
}
