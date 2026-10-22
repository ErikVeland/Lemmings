import Foundation
import NxlvKit

/// One upcoming calendar event as the Desk Clock shows it.
public struct DeskClockEvent: Equatable, Sendable {
    public var start: Date
    public var title: String
    public var nuke: Bool

    public init(start: Date, title: String, nuke: Bool) {
        self.start = start
        self.title = title
        self.nuke = nuke
    }
}

/// Where the Desk Clock is relative to the next event.
public enum DeskClockPhase: Equatable, Sendable {
    case calm, soon, start
}

/// Pure time and event helpers for the Desk Clock. Nothing here reads the wall clock or `Calendar.current`.
public enum DeskClockFace {
    /// 5 x 7 digit glyphs; `1` marks a block. The space glyph is blank.
    public static let glyphs: [Character: [String]] = [
        "0": ["11111", "10001", "10001", "10001", "10001", "10001", "11111"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["11111", "00001", "00001", "11111", "10000", "10000", "11111"],
        "3": ["11111", "00001", "00001", "01111", "00001", "00001", "11111"],
        "4": ["10001", "10001", "10001", "11111", "00001", "00001", "00001"],
        "5": ["11111", "10000", "10000", "11111", "00001", "00001", "11111"],
        "6": ["11111", "10000", "10000", "11111", "10001", "10001", "11111"],
        "7": ["11111", "00001", "00001", "00010", "00100", "00100", "00100"],
        "8": ["11111", "10001", "10001", "11111", "10001", "10001", "11111"],
        "9": ["11111", "10001", "10001", "11111", "00001", "00001", "11111"],
        " ": Array(repeating: "00000", count: 7)
    ]

    /// Four characters for HHMM. In 12-hour time a single-digit hour gets a leading space.
    public static func digits(for date: Date, uses24Hour: Bool, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let shown = uses24Hour ? hour : (hour % 12 == 0 ? 12 : hour % 12)
        let hourText = uses24Hour || shown >= 10 ? String(format: "%02d", shown) : " \(shown)"
        return hourText + String(format: "%02d", minute)
    }

    public static func uses24Hour(locale: Locale) -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return format.contains("H") || format.contains("k")
    }

    /// One event in three, from a hash that stays the same across runs and platforms.
    public static func isNuke(identifier: String, start: Date) -> Bool {
        let minute = Int((start.timeIntervalSince1970 / 60).rounded(.down))
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Array(identifier.utf8) + Array(String(minute).utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash % 3 == 0
    }

    public static func phase(event: DeskClockEvent?, now: Date) -> DeskClockPhase {
        guard let event else { return .calm }
        let delta = event.start.timeIntervalSince(now)
        if delta > 0 && delta <= 600 { return .soon }
        if delta <= 0 && delta >= -120 { return .start }
        return .calm
    }

    /// Whole clock minutes between the two minutes. Seconds never round. UTC flooring is exact
    /// for time zones whose offset is a whole number of minutes.
    public static func countdown(to start: Date, now: Date, compact: Bool = false) -> String {
        let minutes = Int((start.timeIntervalSince1970 / 60).rounded(.down))
            - Int((now.timeIntervalSince1970 / 60).rounded(.down))
        if minutes <= 0 { return L10n.text("LET'S GO!") }
        if compact {
            if minutes >= 60 { return L10n.text("\(minutes / 60)H \(String(format: "%02d", minutes % 60))M") }
            return L10n.text("\(minutes) MIN")
        }
        if minutes >= 60 {
            let hours = minutes / 60
            let rest = String(format: "%02d", minutes % 60)
            return L10n.text("IN \(hours)H \(rest)M")
        }
        return minutes == 1 ? L10n.text("IN 1 MINUTE") : L10n.text("IN \(minutes) MINUTES")
    }

    /// True from 22:00 to 06:59.
    public static func isNight(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 22 || hour < 7
    }

    /// A fixed walk through -2...2 on both axes that moves once per 180 s slot.
    public static func burnInOffset(at date: Date) -> (x: Int, y: Int) {
        let slot = Int((date.timeIntervalSince1970 / 180).rounded(.down))
        let index = ((slot % 25) + 25) % 25
        // 7 is coprime with 25, so one cycle of 25 slots visits every offset once.
        let step = (index * 7) % 25
        return (x: step % 5 - 2, y: step / 5 - 2)
    }
}
