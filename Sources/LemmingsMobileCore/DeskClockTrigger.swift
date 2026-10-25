import Foundation

/// The screen the player is on. Idle entry is limited to Home; tent entry works throughout the app.
public enum DeskClockScreen: Sendable { case menu, level, replay, pause, handover, modal }

public enum DeskClockHinge: Sendable { case unavailable, closed, partiallyOpen, fullyOpen }

public struct DeskClockTriggerInput: Sendable {
    public var hinge: DeskClockHinge
    public var hingeAngle: Double?
    public var foldable: Bool
    public var regions: [MobileReservedRegion]
    public var safe: MobileRect
    public var idle: TimeInterval
    public var charging: Bool
    public var screen: DeskClockScreen
    public var settings: DeskClockSettings

    public init(foldable: Bool, regions: [MobileReservedRegion], safe: MobileRect, idle: TimeInterval,
                charging: Bool, screen: DeskClockScreen, settings: DeskClockSettings,
                hinge: DeskClockHinge = .unavailable, hingeAngle: Double? = nil) {
        self.hinge = hinge
        self.hingeAngle = hingeAngle
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
    case none, tent, stacked, closedCharging

    public static let idleDelay: TimeInterval = 60

    public static func evaluate(_ input: DeskClockTriggerInput) -> DeskClockTrigger {
        guard input.foldable || input.hinge != .unavailable else { return .none }
        // The Duo reports its outward-facing tent at 0.905 radians while UIKit still calls
        // the hinge closed. An angle above 30 degrees distinguishes it from a shut phone.
        let angledClosedHinge = input.hinge == .closed
            && input.hingeAngle.map { $0.isFinite && $0 >= .pi / 6 } == true
        if (input.hinge == .partiallyOpen || angledClosedHinge),
           !input.regions.contains(where: { $0.kind == .division }) { return .tent }
        guard input.screen == .menu, input.idle >= idleDelay else { return .none }
        if MobileDisplayRegions.tablePanes(in: input.safe, avoiding: input.regions).count == 2 {
            return input.settings.openWhenStacked ? .stacked : .none
        }
        let closed = input.hinge == .closed || (input.hinge == .unavailable
            && !input.regions.contains { $0.kind == .division })
        return closed && input.charging && input.settings.openWhenCharging ? .closedCharging : .none
    }
}
