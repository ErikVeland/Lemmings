import Foundation

/// A sound the game asks for, named by meaning rather than by bank position.
///
/// Keeping this separate from the sample bank means the engine never needs to
/// know which index holds which recording. A data set supplies that mapping,
/// so a different bank can be substituted without touching gameplay.
public enum ClassicSoundEffect: String, CaseIterable, Codable, Sendable {
    case levelStart
    case doorOpen
    case assignSkill
    case ohNo
    case explode
    case splat
    case drown
    case vaporize
    case exitLevel
    case builderWarning
    case hitSteel
    case nuke
}

/// Turns engine events into sound requests.
public enum ClassicSoundCue {
    /// Maps one tick's events to the sounds that tick should play.
    ///
    /// Duplicates are collapsed. A nuke can push a dozen lemmings into the
    /// same state on one tick, and playing a dozen copies of one recording is
    /// noise rather than feedback.
    public static func cues(for events: [ClassicDOSEvent]) -> [ClassicSoundEffect] {
        var seen = Set<ClassicSoundEffect>()
        var ordered: [ClassicSoundEffect] = []

        func add(_ effect: ClassicSoundEffect) {
            guard seen.insert(effect).inserted else { return }
            ordered.append(effect)
        }

        for event in events {
            switch event {
            case .entrancesOpened:
                add(.doorOpen)
            case .skillAssigned:
                add(.assignSkill)
            case .saved:
                add(.exitLevel)
            case .builderWarning:
                add(.builderWarning)
            case .hitSteel:
                add(.hitSteel)
            case .nukeStarted:
                add(.nuke)
            case let .actionChanged(_, _, to):
                switch to {
                case .ohNo: add(.ohNo)
                case .exploding: add(.explode)
                case .splatting: add(.splat)
                case .drowning: add(.drown)
                case .vaporizing: add(.vaporize)
                default: break
                }
            default:
                break
            }
        }
        return ordered
    }
}

/// Which bank entry holds each sound.
///
/// The banks carry no names, so this has to be supplied. It is data rather
/// than code so it can be corrected without a rebuild.
public struct ClassicSoundMapping: Codable, Equatable, Sendable {
    /// Bank index per effect. A missing entry means that sound is unavailable.
    public var indices: [ClassicSoundEffect: Int]
    /// Samples were recorded at one rate and played back faster, which is what
    /// gives the voices their cartoon pitch.
    public var recordedRate: Double
    public var playbackRate: Double

    /// The rate a Sound Blaster produced for a given time constant.
    ///
    /// The card could not play arbitrary rates. It took a time constant and
    /// the rate followed from it, so the round numbers people quote were never
    /// the rates the hardware actually ran at.
    public static func soundBlasterRate(timeConstant: Int) -> Double {
        let clamped = min(255, max(0, timeConstant))
        return 1_000_000.0 / Double(256 - clamped)
    }

    /// The rate these effects were recorded at, about 11 kHz.
    public static let recordedTimeConstant = 165
    /// The rate they were played back at, about 21 kHz.
    ///
    /// Playing faster than the recording is what lifts the voices and makes
    /// them sound like cartoon characters rather than people.
    public static let playbackTimeConstant = 208

    public init(
        indices: [ClassicSoundEffect: Int] = [:],
        recordedRate: Double = ClassicSoundMapping.soundBlasterRate(
            timeConstant: ClassicSoundMapping.recordedTimeConstant),
        playbackRate: Double = ClassicSoundMapping.soundBlasterRate(
            timeConstant: ClassicSoundMapping.playbackTimeConstant)
    ) {
        self.indices = indices
        self.recordedRate = recordedRate
        self.playbackRate = playbackRate
    }

    /// How much faster a sample plays than it was recorded.
    public var pitchRatio: Double {
        guard recordedRate > 0 else { return 1 }
        return playbackRate / recordedRate
    }

    public func index(for effect: ClassicSoundEffect) -> Int? { indices[effect] }
    public var isComplete: Bool {
        ClassicSoundEffect.allCases.allSatisfy { indices[$0] != nil }
    }

    /// Effects that still have no recording assigned.
    public var missingEffects: [ClassicSoundEffect] {
        ClassicSoundEffect.allCases.filter { indices[$0] == nil }
    }
}


extension ClassicSoundMapping {
    /// Binds effects to the names the Macintosh release uses.
    ///
    /// Most are unambiguous. The three marked below are reasoned guesses from
    /// the name and the length, because nothing in the data says what a sound
    /// is for. They are listed apart so they are easy to correct.
    public static let macintoshNames: [ClassicSoundEffect: String] = [
        .levelStart: "LetsGo",
        .doorOpen: "Door",
        .assignSkill: "MousePress",
        .ohNo: "OhNo",
        .explode: "Explode",
        .splat: "Splat",
        .drown: "Splash",
        .vaporize: "Fire",
        .hitSteel: "Chink",
        // Reasoned from name and length rather than stated by the data.
        .exitLevel: "Ting",
        .builderWarning: "Oing",
        .nuke: "Die",
    ]
}
