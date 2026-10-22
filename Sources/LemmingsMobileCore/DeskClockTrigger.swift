import Foundation

public enum DeskClockReason: Sendable { case menu, widget, stacked, closedCharging }

/**
 * Automatic entry is limited to an idle Duo menu. Gameplay and handovers never qualify.
 */
public enum DeskClockTrigger {
    public static func evaluate(foldable: Bool, stacked: Bool, closed: Bool, charging: Bool,
                                idle: TimeInterval, menuAvailable: Bool, settings: DeskClockSettings) -> DeskClockReason? {
        guard foldable, menuAvailable, idle >= 60 else { return nil }
        if stacked && settings.openWhenStacked { return .stacked }
        if closed && charging && settings.openWhenCharging { return .closedCharging }
        return nil
    }
}
