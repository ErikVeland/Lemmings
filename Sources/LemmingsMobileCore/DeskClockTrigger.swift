import Foundation

/// The screen the player is on. The clock only opens over the menu.
public enum DeskClockScreen: Sendable { case menu, level, replay, pause, handover, modal }

public struct DeskClockTriggerInput: Sendable {
    public var foldable: Bool
    public var regions: [MobileReservedRegion]
    public var safe: MobileRect
    public var idle: TimeInterval
    public var charging: Bool
    public var screen: DeskClockScreen
    public var settings: DeskClockSettings

    public init(foldable: Bool, regions: [MobileReservedRegion], safe: MobileRect, idle: TimeInterval,
                charging: Bool, screen: DeskClockScreen, settings: DeskClockSettings) {
        self.foldable = foldable
        self.regions = regions
        self.safe = safe
        self.idle = idle
        self.charging = charging
        self.screen = screen
        self.settings = settings
    }
}

/// Decides when the idle clock opens by itself on a foldable.
public enum DeskClockTrigger: Equatable, Sendable {
    case none, stacked, closedCharging

    public static let idleDelay: TimeInterval = 60

    public static func evaluate(_ input: DeskClockTriggerInput) -> DeskClockTrigger {
        guard input.foldable, input.screen == .menu, input.idle >= idleDelay else { return .none }
        if MobileDisplayRegions.tablePanes(in: input.safe, avoiding: input.regions).count == 2 {
            return input.settings.openWhenStacked ? .stacked : .none
        }
        let closed = !input.regions.contains { $0.kind == .division }
        return closed && input.charging && input.settings.openWhenCharging ? .closedCharging : .none
    }
}
