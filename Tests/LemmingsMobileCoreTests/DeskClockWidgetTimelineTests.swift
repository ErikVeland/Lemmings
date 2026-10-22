import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite("Desk Clock widget timeline")
struct DeskClockWidgetTimelineTests {
    /// 12:34:40 UTC.
    private let now = Date(timeIntervalSince1970: 1_792_154_080)

    @Test func entriesAreWholeMinutes() {
        let dates = DeskClockTimeline.entryDates(from: now)
        #expect(dates.count == 60)
        #expect(dates.allSatisfy { $0.timeIntervalSince1970.truncatingRemainder(dividingBy: 60) == 0 })
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == 60 })
    }

    @Test func firstEntryIsCurrentMinute() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let first = try #require(DeskClockTimeline.entryDates(from: now).first)
        #expect(calendar.dateComponents([.hour, .minute, .second], from: now) == DateComponents(hour: 12, minute: 34, second: 40))
        #expect(calendar.dateComponents([.hour, .minute, .second], from: first) == DateComponents(hour: 12, minute: 34, second: 0))
    }

    @Test func timelineUsesWholeMinutesAndRefreshesAfterAnHour() throws {
        let dates = DeskClockTimeline.entryDates(from: Date(timeIntervalSince1970: 1_000_019))
        #expect(dates.first?.timeIntervalSince1970 == 999_960)
        let first = try #require(dates.first)
        #expect(DeskClockTimeline.reloadDate(after: dates).timeIntervalSince(first) == 3600)
    }

    @Test func compactCountdownPreservesTheWholeMinute() {
        let now = Date(timeIntervalSince1970: 1_000_019)
        #expect(DeskClockFace.countdown(to: now.addingTimeInterval(300), now: now, compact: true) == "5 MIN")
        #expect(DeskClockFace.countdown(to: now.addingTimeInterval(3900), now: now, compact: true) == "1H 05M")
        #expect(DeskClockFace.countdown(to: now, now: now, compact: true) == "LET'S GO!")
    }

    @Test func eventsAreReadAgainOnlyWhenTheCurrentEventEnds() async {
        let dates = DeskClockTimeline.entryDates(from: now)
        let first = DeskClockEvent(start: dates[10], title: "Standup", nuke: false)
        let second = DeskClockEvent(start: dates[40], title: "Review", nuke: true)
        var reads: [Date] = []
        let events = await DeskClockTimeline.events(for: dates) { date in
            reads.append(date)
            if date <= first.start.addingTimeInterval(120) { return first }
            return date <= second.start.addingTimeInterval(120) ? second : nil
        }
        // Each event stays through its two-minute start window, then the next one takes over.
        #expect(reads == [dates[0], dates[13], dates[43]])
        #expect(events[12] == first)
        #expect(events[13] == second && events[42] == second)
        #expect(events[43] == nil && events[59] == nil)
        #expect(events.count == 60)
    }
}
