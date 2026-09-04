import Foundation

/// Decides when the soundtrack should change, and how soon.
///
/// This answers one question only: has the game just earned a change of music?
/// It does not choose a track, and it does not fade anything. Those belong to
/// the player, which is the only part that knows where the beat is.
///
/// The separation matters. A change that lands in the middle of a bar sounds
/// like a mistake however good the two tracks are, so almost every cue asks to
/// wait for the next phrase. Only the nuke cuts immediately, because the nuke
/// is the one moment where a jarring change is the point.
public struct AdaptiveDJCue: Equatable, Sendable {
    /// What the game did to earn a change.
    public enum Reason: String, Equatable, Sendable, CaseIterable {
        /// The first lemming reached home.
        ///
        /// This is the best cue the game offers. The level has turned, the
        /// outcome is no longer in doubt, and a change started here has the
        /// whole exit sequence to settle before the results appear.
        case firstRescue
        /// Every lemming needed is home.
        case won
        /// The player pressed the nuke.
        case nuke
        /// Under a minute left.
        case timeRunningOut
    }

    /// How soon the change may happen.
    public enum Timing: String, Equatable, Sendable {
        /// Wait for the next phrase boundary. Nearly everything uses this.
        case atNextPhrase
        /// Change now, mid-bar if it must. Only the nuke earns this.
        case immediate
    }

    public let reason: Reason
    public let timing: Timing

    public init(reason: Reason, timing: Timing) {
        self.reason = reason
        self.timing = timing
    }
}

/// Watches a level and calls the cues.
///
/// Each cue fires once per level. Without that, a lemming count that hovers on
/// a boundary would ask for a new transition every frame, and the music would
/// never settle anywhere.
public struct AdaptiveDJDirector: Sendable {
    private var firedReasons: Set<AdaptiveDJCue.Reason> = []

    public init() {}

    /// Which cues have already fired in this level.
    public var fired: Set<AdaptiveDJCue.Reason> { firedReasons }

    /// Forgets the level, so the next one starts from silence.
    ///
    /// Rewinding calls this too. A player who rewinds past the first rescue
    /// and saves that lemming again should hear the same change again, because
    /// to them it is the first time it happened.
    public mutating func reset() {
        firedReasons.removeAll()
    }

    /// Returns a cue the moment the game earns one, and nothing after that.
    ///
    /// When several become true in the same frame, the most disruptive wins.
    /// A nuke during the closing seconds is a nuke.
    public mutating func cue(
        for telemetry: AdaptiveDJEngine.Telemetry
    ) -> AdaptiveDJCue? {
        for candidate in ordered(telemetry) where !firedReasons.contains(candidate.reason) {
            firedReasons.insert(candidate.reason)
            return candidate
        }
        return nil
    }

    /// The cues the telemetry currently justifies, most disruptive first.
    private func ordered(_ telemetry: AdaptiveDJEngine.Telemetry) -> [AdaptiveDJCue] {
        var cues: [AdaptiveDJCue] = []
        if telemetry.isNuking {
            cues.append(AdaptiveDJCue(reason: .nuke, timing: .immediate))
        }
        if telemetry.didWin {
            cues.append(AdaptiveDJCue(reason: .won, timing: .atNextPhrase))
        }
        if telemetry.savedCount >= 1 {
            cues.append(AdaptiveDJCue(reason: .firstRescue, timing: .atNextPhrase))
        }
        if let remaining = telemetry.remainingSeconds, remaining < 60 {
            cues.append(AdaptiveDJCue(reason: .timeRunningOut, timing: .atNextPhrase))
        }
        return cues
    }
}
