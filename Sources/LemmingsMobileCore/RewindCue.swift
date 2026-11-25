import Foundation
import NxlvKit

/// What the rewind cue tells the player: how far back in game time they are and how fast they are going.
///
/// Rewind changes history, so the cue uses game seconds rather than engine ticks.
/// The speed level grows with rapid presses and shows as one to three chevrons.
public struct RewindCue: Equatable, Sendable {
    /// Game seconds between the point where rewind started and the shown moment.
    public let secondsBack: Double
    /// The shown moment along the run so far: 0 is the level start, 1 is where rewind started.
    public let position: Double
    /// One to three chevrons. More chevrons mean each press covers more time.
    public let speed: Int
    private let announcesSpeed: Bool

    /// Nil while nothing has been rewound.
    public init?(currentTick: Int, originTick: Int, ticksPerSecond: Double, speed: Int? = nil) {
        guard originTick > currentTick, ticksPerSecond > 0 else { return nil }
        secondsBack = Double(originTick - currentTick) / ticksPerSecond
        position = Double(max(0, min(currentTick, originTick))) / Double(originTick)
        self.speed = min(3, max(1, speed ?? 1))
        announcesSpeed = speed != nil
    }

    public var chevrons: String { String(repeating: "<", count: speed + 1) }

    private var fractionDigits: Int {
        if secondsBack < 0.1 { return 2 }
        return secondsBack < 10 ? 1 : 0
    }

    public var text: String {
        let amount = secondsBack.formatted(.number.grouping(.never).precision(.fractionLength(fractionDigits))
            .rounded(rule: .toNearestOrAwayFromZero).locale(L10n.interface.locale))
        return chevrons + " " + L10n.text("REWIND -\(amount)s")
    }

    /// The widest text this cue can show, so the label never resizes while the value changes.
    public static var widestText: String { "<<<< " + L10n.text("REWIND -\("88.8")s") }

    public var accessibilityLabel: String {
        let duration = Measurement(value: secondsBack, unit: UnitDuration.seconds).formatted(
            .measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.grouping(.never)
                .precision(.fractionLength(0...fractionDigits)).rounded(rule: .toNearestOrAwayFromZero))
                .locale(L10n.interface.locale))
        if announcesSpeed { return L10n.text("Rewound \(duration), speed \(speed) of 3") }
        return L10n.text("Rewound \(duration)")
    }
}

extension MobileRewindPressAcceleration {
    /// The rewind speed the next press uses, as one to three chevrons.
    /// A pause longer than the burst window drops back to one.
    public func cueSpeed(at time: Double) -> Int {
        guard let lastPress = lastPressTime, time >= lastPress, time - lastPress <= 0.65 else { return 1 }
        return min(3, 1 + (burstLevel + 1) / 2)
    }
}
