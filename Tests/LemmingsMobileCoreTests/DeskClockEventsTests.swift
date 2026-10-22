import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite struct DeskClockEventsTests {
    @Test func filtersEventsAndKeepsTheStartCelebration() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func candidate(_ id: String, _ delta: Double, allDay: Bool = false, declined: Bool = false) -> DeskClockCandidate {
            .init(identifier: id, start: now.addingTimeInterval(delta), title: id, allDay: allDay, declined: declined)
        }
        let candidates = [candidate("old", -121), candidate("all day", 10, allDay: true),
            candidate("declined", 20, declined: true), candidate("far", 86_401), candidate("next", 600), candidate("started", -60)]
        #expect(DeskClockEvents.next(from: candidates, now: now)?.title == "started")
        #expect(DeskClockEvents.next(from: candidates, now: now.addingTimeInterval(61))?.title == "next")
        #expect(DeskClockEvents.next(from: [], now: now) == nil)
    }

    @Test func timelineUsesWholeMinutesAndRefreshesAfterAnHour() {
        let dates = DeskClockTimeline.entryDates(from: Date(timeIntervalSince1970: 1_000_019))
        #expect(dates.count == 60)
        #expect(dates.first!.timeIntervalSince1970 == 999_960)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == 60 })
        #expect(dates.last!.addingTimeInterval(60).timeIntervalSince(dates.first!) == 3600)
    }

    @Test func compactCountdownPreservesTheWholeMinute() {
        let now = Date(timeIntervalSince1970: 1_000_019)
        #expect(DeskClockFace.countdown(to: now.addingTimeInterval(300), now: now, compact: true) == "5 MIN")
        #expect(DeskClockFace.countdown(to: now.addingTimeInterval(3900), now: now, compact: true) == "1H 05M")
        #expect(DeskClockFace.countdown(to: now, now: now, compact: true) == "LET'S GO!")
    }

    @Test func automaticEntryRequiresAnIdleDuoMenu() {
        let settings = DeskClockSettings()
        #expect(DeskClockTrigger.evaluate(foldable: true, stacked: true, closed: false, charging: false,
            idle: 60, menuAvailable: true, settings: settings) == .stacked)
        #expect(DeskClockTrigger.evaluate(foldable: true, stacked: false, closed: true, charging: true,
            idle: 60, menuAvailable: true, settings: settings) == .closedCharging)
        for (foldable, idle, menu) in [(false, 60.0, true), (true, 59.0, true), (true, 60.0, false)] {
            #expect(DeskClockTrigger.evaluate(foldable: foldable, stacked: true, closed: false, charging: true,
                idle: idle, menuAvailable: menu, settings: settings) == nil)
        }
        #expect(DeskClockTrigger.evaluate(foldable: true, stacked: false, closed: true, charging: false,
            idle: 60, menuAvailable: true, settings: settings) == nil)
        #expect(DeskClockTrigger.evaluate(foldable: true, stacked: true, closed: false, charging: true,
            idle: 60, menuAvailable: true, settings: .init(openWhenStacked: false)) == nil)
    }
}
