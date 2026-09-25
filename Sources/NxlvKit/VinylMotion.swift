import Foundation

/// Turntable speed and level for a record stopped by hand and released again.
///
/// A retry brakes the platter: the pitch falls to nearly nothing and the
/// sound dies away at the end. The next attempt releases the record from a
/// finger hold: the motor pulls the pitch up to full speed quickly.
public enum VinylMotion {
    public enum Phase: Sendable { case stop, start }

    public static let stopSeconds = 0.45
    public static let startSeconds = 0.3
    /// The slowest audible rate. The platter never quite reaches rest.
    public static let minimumRate = 0.04

    public static func duration(_ phase: Phase) -> Double {
        phase == .stop ? stopSeconds : startSeconds
    }

    /// The playback rate and gain at `progress`, from 0 to 1, through a phase.
    public static func sample(_ phase: Phase, progress: Double) -> (rate: Double, gain: Double) {
        let p = min(1, max(0, progress))
        switch phase {
        case .stop:
            // A hand brakes at a steady force, so the speed falls in a line.
            // The level holds until the pitch is low, then dies away.
            let rate = max(minimumRate, 1 - p)
            return (rate, min(1, (1 - p) * 4))
        case .start:
            // The motor pulls hard at first, then settles on the speed.
            let rate = max(minimumRate, 1 - pow(1 - p, 3))
            return (rate, min(1, p * 5))
        }
    }
}
