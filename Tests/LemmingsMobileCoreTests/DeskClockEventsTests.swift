import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite("Desk Clock events")
struct DeskClockEventsTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    private func candidate(
        _ id: String = "a",
        offset: TimeInterval,
        allDay: Bool = false,
        declined: Bool = false
    ) -> DeskClockCandidate {
        DeskClockCandidate(
            identifier: id,
            start: now.addingTimeInterval(offset),
            title: "Event \(id)",
            allDay: allDay,
            declined: declined
        )
    }

    @Test func skipsAllDay() {
        #expect(DeskClockEvents.next(from: [candidate(offset: 600, allDay: true)], now: now) == nil)
    }

    @Test func skipsDeclined() {
        #expect(DeskClockEvents.next(from: [candidate(offset: 600, declined: true)], now: now) == nil)
    }

    @Test func skipsBeyond24Hours() {
        #expect(DeskClockEvents.next(from: [candidate(offset: 86_400 + 1)], now: now) == nil)
        #expect(DeskClockEvents.next(from: [candidate(offset: 86_400)], now: now) != nil)
    }

    @Test func keepsJustStarted() {
        #expect(DeskClockEvents.next(from: [candidate(offset: -60)], now: now) != nil)
        #expect(DeskClockEvents.next(from: [candidate(offset: -121)], now: now) == nil)
    }

    @Test func choosesEarliest() {
        let found = DeskClockEvents.next(
            from: [candidate("late", offset: 3_600), candidate("early", offset: 300), candidate("mid", offset: 900)],
            now: now
        )
        #expect(found?.title == "Event early")
        #expect(found?.start == now.addingTimeInterval(300))
        #expect(found?.nuke == DeskClockFace.isNuke(identifier: "early", start: now.addingTimeInterval(300)))
    }

    @Test func emptyGivesNil() {
        #expect(DeskClockEvents.next(from: [], now: now) == nil)
    }
}

#if canImport(EventKit) && (os(iOS) || os(macOS))
import EventKit

@Suite struct DeskClockCalendarAccessTests {
    @Test func onlyFullAccessReadsEvents() {
        #expect(EventKitDeskClockSource.access(for: .notDetermined) == .notDetermined)
        #expect(EventKitDeskClockSource.access(for: .denied) == .denied)
        #expect(EventKitDeskClockSource.access(for: .restricted) == .denied)
        if #available(iOS 17, macOS 14, *) {
            #expect(EventKitDeskClockSource.access(for: .fullAccess) == .granted)
            #expect(EventKitDeskClockSource.access(for: .writeOnly) == .denied)
        }
    }
}
#endif
