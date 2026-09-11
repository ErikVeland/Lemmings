import Foundation

/// A soundtrack change earned by meeting the rescue target.
public struct AdaptiveDJCue: Equatable, Sendable {
    public enum Reason: String, Equatable, Sendable, CaseIterable {
        // Keep old identifiers for clients that read earlier cue logs.
        case firstRescue, won, nuke, timeRunningOut
    }
    public enum Timing: String, Equatable, Sendable {
        case atNextPhrase, immediate
    }
    public let reason: Reason
    public let timing: Timing
    public init(reason: Reason, timing: Timing) {
        self.reason = reason; self.timing = timing
    }
}

/// Allows one victory transition per level, based on the actual rescue count.
public struct AdaptiveDJDirector: Sendable {
    private var firedReasons: Set<AdaptiveDJCue.Reason> = []
    public init() {}
    public var fired: Set<AdaptiveDJCue.Reason> { firedReasons }
    public mutating func reset() { firedReasons.removeAll() }

    public mutating func cue(for telemetry: AdaptiveDJEngine.Telemetry) -> AdaptiveDJCue? {
        guard telemetry.requiredCount > 0,
              telemetry.savedCount >= telemetry.requiredCount,
              firedReasons.insert(.won).inserted else { return nil }
        return AdaptiveDJCue(reason: .won, timing: .atNextPhrase)
    }
}
