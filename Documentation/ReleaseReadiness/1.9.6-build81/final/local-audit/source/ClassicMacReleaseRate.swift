import Foundation

/// Macintosh CODE 3:$0AC6 adjusts MousePress in 24 pitch steps per octave.
public enum ClassicMacReleaseRate {
    public static func pitchSteps(rate: Int) -> Int {
        Int(floor(Double(min(99, max(0, rate)) - 50) / 2))
    }
    public static func playbackRatio(rate: Int) -> Double {
        pow(2, Double(pitchSteps(rate: rate)) / 24)
    }
}
