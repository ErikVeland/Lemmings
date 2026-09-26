import Foundation

/// A soundtrack change once a level is won or has reached its rescue target.
public struct AdaptiveDJCue: Equatable, Sendable {
    public enum Reason: String, Equatable, Sendable, CaseIterable {
        // Keep old identifiers for clients that read earlier cue logs.
        case firstRescue, won, lost, nuke, timeRunningOut
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

/// Ordinary danger and elapsed time never replace the level track.
public struct AdaptiveDJDirector: Sendable {
    private var firedReasons: Set<AdaptiveDJCue.Reason> = []
    public init() {}
    public var fired: Set<AdaptiveDJCue.Reason> { firedReasons }
    public mutating func reset() { firedReasons.removeAll() }

    public mutating func cue(for telemetry: AdaptiveDJEngine.Telemetry) -> AdaptiveDJCue? {
        guard firedReasons.isEmpty else { return nil }
        let secured = telemetry.requiredCount > 0 && telemetry.savedCount >= telemetry.requiredCount
        guard secured || (telemetry.isComplete && telemetry.didWin) else { return nil }
        let reason: AdaptiveDJCue.Reason = .won
        firedReasons.insert(reason)
        return AdaptiveDJCue(reason: reason, timing: .atNextPhrase)
    }
}

/// Named Amiga rotation, excluding the intro and special-level themes.
/// Reference: https://lemmings.fandom.com/wiki/Music_in_Lemmings
public enum LevelMusicSelection {
    public static let classic = ["cancan", "lemming1", "tim2", "lemming2", "tim8", "tim3", "tim5", "doggie", "tim6", "lemming3", "tim7", "tim9", "tim1", "tim10", "tim4", "tenlemmings", "mountain"]
    /// Count prior score occurrences, including special-level overrides. Direct
    /// level selection and retries produce the same arrangement as linear play.
    public static func cycle(index: Int, titles: [String], holiday: Bool, ohNo: Bool) -> Int {
        guard index >= 0, index < titles.count else { return 0 }
        let selected = track(index: index, title: titles[index], holiday: holiday, ohNo: ohNo)
        return (0..<index).filter {
            track(index: $0, title: titles[$0], holiday: holiday, ohNo: ohNo) == selected
        }.count
    }

    public static func track(index: Int, title: String, holiday: Bool, ohNo: Bool) -> String {
        let title = title.lowercased()
        if !holiday && !ohNo {
            if title.contains("mariarti") { return "mariarti" }
            if title.contains("beastii") || title.contains("beast ii") { return "beastII" }
            if title.contains("beast") { return "beastI" }
            if title.contains("menacing") { return "menace" }
            if title.contains("awesome") { return "awesome" }
        }
        let names = holiday ? ["jb", "kw", "rudi"] : ohNo ? (1...6).map { "tune\($0)" } : classic
        return names[max(0, index) % names.count]
    }
}

public extension LevelMusicSelection {
    static func matchesRecording(_ filename: String, track: String) -> Bool {
        let name = filename.lowercased()
        let key = track.lowercased()
        if name == key { return true }
        let aliases = ["awesome": "awesome", "beastii": "shadow of the beast ii",
            "tim1": "rainbow islands", "tim2": "smile if you love lemmings",
            "tim3": "lend a helping hand", "tim4": "postcard from lemmingland",
            "tim5": "mind the step", "tim6": "dance of the reed flutes",
            "tim7": "turkish march", "tim8": "dance of the little swans",
            "tim9": "london bridge", "tim10": "forest green"]
        return aliases[key].map { name.contains($0) } ?? false
    }
}
