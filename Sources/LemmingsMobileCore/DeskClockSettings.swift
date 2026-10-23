import Foundation

/// Preferences for the idle Desk Clock. Older saves lack these keys, so every field decodes with its default.
public struct DeskClockSettings: Codable, Equatable, Sendable {
    public var openWhenStacked: Bool
    public var openWhenCharging: Bool
    public var showNextEvent: Bool
    /// When enabled, the live clock uses only dim red pixels from 22:00 to 06:59.
    public var redNightVision: Bool
    /// Kept so older saves decode and encode unchanged. The clock no longer reads it:
    /// the system's calendar authorization decides whether to ask.
    public var calendarRequested: Bool

    public init(openWhenStacked: Bool = true, openWhenCharging: Bool = true,
                showNextEvent: Bool = true, redNightVision: Bool = false, calendarRequested: Bool = false) {
        self.openWhenStacked = openWhenStacked
        self.openWhenCharging = openWhenCharging
        self.showNextEvent = showNextEvent
        self.redNightVision = redNightVision
        self.calendarRequested = calendarRequested
    }

    private enum CodingKeys: String, CodingKey {
        case openWhenStacked, openWhenCharging, showNextEvent, redNightVision, calendarRequested
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        self.init(openWhenStacked: try fields.decodeIfPresent(Bool.self, forKey: .openWhenStacked) ?? true,
                  openWhenCharging: try fields.decodeIfPresent(Bool.self, forKey: .openWhenCharging) ?? true,
                  showNextEvent: try fields.decodeIfPresent(Bool.self, forKey: .showNextEvent) ?? true,
                  redNightVision: try fields.decodeIfPresent(Bool.self, forKey: .redNightVision) ?? false,
                  calendarRequested: try fields.decodeIfPresent(Bool.self, forKey: .calendarRequested) ?? false)
    }
}

/// What a tap on the "Show next event" row does. Without calendar access the row shows off and opens
/// iOS Settings. The saved choice stays, so the events return when the player grants access again.
public enum DeskClockEventsRowAction: Equatable, Sendable {
    case toggle, openSettings

    public init(access: DeskClockCalendarAccess) {
        self = access == .denied ? .openSettings : .toggle
    }
}
