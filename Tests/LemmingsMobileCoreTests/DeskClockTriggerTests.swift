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

    @Test func tentOpensImmediatelyFromEveryScreenWithoutCharging() {
        for screen in [DeskClockScreen.menu, .level, .replay, .pause, .handover, .modal] {
            var value = input(idle: 0, screen: screen)
            value.safe = Self.bookSafe
            value.hinge = .partiallyOpen
            #expect(DeskClockTrigger.evaluate(value) == .tent)
            value.safe = Self.stackedSafe
            #expect(DeskClockTrigger.evaluate(value) == .tent)
            value.hinge = .closed
            #expect(DeskClockTrigger.evaluate(value) == .none)
            value.hinge = .fullyOpen
            #expect(DeskClockTrigger.evaluate(value) == .none)
        }
    }

    @Test func openHingeDoesNotCountAsClosedCharging() {
        var value = input(charging: true)
        value.hinge = .partiallyOpen
        #expect(DeskClockTrigger.evaluate(value) == .tent)
        value.hinge = .fullyOpen
        #expect(DeskClockTrigger.evaluate(value) == .none)
    }

    @Test func duoTentAngleOpensEvenWhenUIKitCallsTheHingeClosed() {
        for screen in [DeskClockScreen.menu, .level, .replay, .pause, .handover, .modal] {
            var value = input(idle: 0, screen: screen)
            value.hinge = .closed
            value.hingeAngle = 0.9050147095486298
            #expect(DeskClockTrigger.evaluate(value) == .tent)
            value.hingeAngle = 0.1
            #expect(DeskClockTrigger.evaluate(value) == .none)
            value.hingeAngle = 0.9050147095486298
            value.regions = [Self.bookDivision]
            #expect(DeskClockTrigger.evaluate(value) == .none)
        }
    }

    @Test func innerDisplayDivisionDoesNotCountAsTent() {
        var value = input(book: true, idle: 0)
        value.hinge = .partiallyOpen
        #expect(DeskClockTrigger.evaluate(value) == .none)
        value = input(stacked: true, idle: 0)
        value.hinge = .partiallyOpen
        #expect(DeskClockTrigger.evaluate(value) == .none)
        value = input(idle: 0)
        value.hinge = .partiallyOpen
        #expect(DeskClockTrigger.evaluate(value) == .tent)
    }

    @Test func cameraDoesNotReserveAWholeClockEdge() {
        let bounds = MobileRect(x: 0, y: 0, width: 720, height: 495)
        let camera = MobileReservedRegion(kind: .occlusion, frame: .init(x: 0, y: 0, width: 92, height: 80))
        let content = MobileDisplayRegions.fullWidthContent(in: bounds, avoiding: [camera])
        #expect(content == MobileRect(x: 0, y: 80, width: 720, height: 415))
        let clock = DeskClockLayout.make(safe: bounds, regions: [camera], bounds: bounds)
        #expect(clock.scene == bounds)
        #expect(clock.close.minX == 16 && !clock.close.intersects(camera.frame))
    }

    @Test func fullDisplaySceneKeepsCloseWithinTheSafeArea() {
        for size in [MobileSize(width: 495, height: 720), .init(width: 720, height: 495)] {
            let bounds = MobileRect(x: 0, y: 0, width: size.width, height: size.height)
            let safe = MobileRect(x: 12, y: 36, width: size.width - 100, height: size.height - 70)
            let layout = DeskClockLayout.make(safe: safe, regions: [], bounds: bounds)
            #expect(layout.scene == bounds)
            #expect(layout.close.minX >= safe.minX && layout.close.maxX <= safe.maxX)
            #expect(layout.close.minY >= safe.minY && layout.close.maxY <= safe.maxY)
            #expect(layout.close.width >= 44 && layout.close.height >= 44)
        }
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
