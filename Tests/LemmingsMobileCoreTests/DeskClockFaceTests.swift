import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite("Desk Clock face")
struct DeskClockFaceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int, second: Double = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: hour, minute: minute))!
        return base.addingTimeInterval(second)
    }

    @Test func twentyFourHour() {
        #expect(DeskClockFace.digits(for: date(9, 5), uses24Hour: true, calendar: calendar) == "0905")
        #expect(DeskClockFace.digits(for: date(23, 59), uses24Hour: true, calendar: calendar) == "2359")
    }

    @Test func twelveHour() {
        #expect(DeskClockFace.digits(for: date(9, 5), uses24Hour: false, calendar: calendar) == " 905")
        #expect(DeskClockFace.digits(for: date(0, 30), uses24Hour: false, calendar: calendar) == "1230")
        #expect(DeskClockFace.digits(for: date(13, 0), uses24Hour: false, calendar: calendar) == " 100")
    }

    @Test func phaseBoundaries() {
        let now = date(12, 0)
        func phase(_ offset: TimeInterval) -> DeskClockPhase {
            DeskClockFace.phase(event: DeskClockEvent(start: now.addingTimeInterval(offset), title: "", nuke: false), now: now)
        }
        #expect(phase(601) == .calm)
        #expect(phase(600) == .soon)
        #expect(phase(0) == .start)
        #expect(phase(-120) == .start)
        #expect(phase(-121) == .calm)
        #expect(DeskClockFace.phase(event: nil, now: now) == .calm)
    }

    @Test func countdownCopy() {
        let event = date(12, 40)
        #expect(DeskClockFace.countdown(to: event, now: date(12, 33)) == "IN 7 MINUTES")
        #expect(DeskClockFace.countdown(to: event, now: date(12, 33, second: 59.9)) == "IN 7 MINUTES")
        #expect(DeskClockFace.countdown(to: event, now: date(12, 34)) == "IN 6 MINUTES")
        #expect(DeskClockFace.countdown(to: event, now: date(12, 39)) == "IN 1 MINUTE")
        #expect(DeskClockFace.countdown(to: event, now: date(12, 40)) == "LET'S GO!")
        #expect(DeskClockFace.countdown(to: date(13, 41), now: date(12, 40)) == "IN 1H 01M")
    }

    @Test func nukeIsStableAndOneInThree() {
        let start = date(12, 40)
        #expect(DeskClockFace.isNuke(identifier: "abc", start: start) == DeskClockFace.isNuke(identifier: "abc", start: start))
        let nukes = (0..<3000).filter { DeskClockFace.isNuke(identifier: "event-\($0)", start: start) }.count
        let share = Double(nukes) / 3000
        #expect(share >= 0.30 && share <= 0.37)
    }

    @Test func glyphShapes() {
        for digit in "0123456789" {
            let rows = DeskClockFace.glyphs[digit]
            #expect(rows?.count == 7)
            #expect(rows?.allSatisfy { $0.count == 5 } == true)
        }
        let blank = DeskClockFace.glyphs[" "]
        #expect(blank?.count == 7)
        #expect(blank?.contains { $0.contains("1") } == false)
    }

    @Test func nightWindow() {
        #expect(!DeskClockFace.isNight(date(21, 59), calendar: calendar))
        #expect(DeskClockFace.isNight(date(22, 0), calendar: calendar))
        #expect(DeskClockFace.isNight(date(6, 59), calendar: calendar))
        #expect(!DeskClockFace.isNight(date(7, 0), calendar: calendar))
    }

    @Test func burnInShift() {
        let start = date(0, 0)
        let a = DeskClockFace.burnInOffset(at: start.addingTimeInterval(10))
        let b = DeskClockFace.burnInOffset(at: start.addingTimeInterval(170))
        #expect(a == b)
        var seen = Set<Int>()
        for slot in 0..<480 {
            let offset = DeskClockFace.burnInOffset(at: start.addingTimeInterval(Double(slot) * 180))
            #expect((-2...2).contains(offset.x) && (-2...2).contains(offset.y))
            seen.insert(offset.x * 10 + offset.y)
        }
        #expect(seen.count >= 2)
    }
}
