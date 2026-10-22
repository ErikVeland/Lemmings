import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite struct DeskClockWidgetTimelineTests {
    @Test func entriesStartAtCurrentWholeMinuteAndCoverOneHour() {
        let now = Date(timeIntervalSince1970: 1_792_143_040)
        let dates = DeskClockTimeline.entryDates(from: now)
        #expect(dates.count == 60)
        #expect(dates.first == Date(timeIntervalSince1970: 1_792_143_000))
        #expect(dates.last == Date(timeIntervalSince1970: 1_792_146_540))
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == 60 })
    }
}
