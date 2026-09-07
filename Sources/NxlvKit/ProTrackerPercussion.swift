import Foundation

/// Works out which of a module's samples are percussion.
///
/// The Amiga panned its four channels hard apart, so a kick drum played on
/// channel one sat entirely in the left ear. Modern mixes put the beat in the
/// middle. To move it there, something has to decide which samples are drums,
/// and a module does not say.
///
/// Two signals are used. A module carries a 22 character name per sample, and
/// trackers overwhelmingly label percussion, so a name is checked first. Where
/// a name says nothing, the shape of the sample is used: percussion is short,
/// does not loop, starts loudly and dies away.
///
/// This classifies samples, not beats. A sample used for both a bass line and
/// a kick is one thing to the module and will be judged once. Tuned percussion
/// such as melodic toms may be missed. It is right most of the time, and being
/// wrong moves an instrument toward the middle rather than breaking anything.
public enum ProTrackerPercussion {
    /// Why a sample was judged to be percussion.
    public enum Evidence: String, Sendable, Equatable {
        case name
        case shape
    }

    /// Words that name percussion in a tracker sample.
    ///
    /// `bass` is deliberately absent: on its own it names a bass line far more
    /// often than a bass drum. `bassdrum` and `bd` are both here instead.
    static let percussionWords = [
        "bassdrum", "bdrum", "kick", "kik", "snare", "snr", "rimshot",
        "hihat", "hat", "openhat", "closedhat", "crash", "ride", "cymbal", "cym",
        "tom", "clap", "cowbell", "shaker", "tambourine", "conga", "bongo",
        "perc", "drum", "beat",
    ]

    /// Short words that only count when they stand alone.
    ///
    /// Two letters match far too much inside longer words: `bd` appears in
    /// `bdiddley`, `hh` in `hhorn`. These are compared against the whole name.
    static let percussionAbbreviations = ["bd", "sd", "hh", "oh", "ch", "cy", "tm"]

    /// Reduces a sample name to comparable letters and digits.
    static func normalize(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        })
    }

    /// Whether a name says the sample is percussion.
    public static func nameSuggestsPercussion(_ name: String) -> Bool {
        let text = normalize(name)
        guard !text.isEmpty else { return false }
        if percussionAbbreviations.contains(text) { return true }
        // Digits distinguish one drum from another rather than naming it, so a
        // name like "snare2" still has to match on the word.
        let letters = String(text.filter { !$0.isNumber })
        if percussionAbbreviations.contains(letters) { return true }
        return percussionWords.contains { letters.contains($0) }
    }

    /// The longest one-shot that still counts as a hit.
    ///
    /// Module samples play at around eight thousand samples a second, so this
    /// is roughly a third of a second. Anything longer is being held rather
    /// than struck. A looser limit swept in melodic one-shots.
    static let longestHit = 2_600

    /// Whether the shape of a sample looks like something struck.
    ///
    /// A hit is loudest near its start and quiet by its end. This compares the
    /// two ends rather than looking for an envelope, because a module sample
    /// has no envelope to read.
    public static func shapeSuggestsPercussion(_ sample: ProTrackerSample) -> Bool {
        guard !sample.loops, sample.data.count > 64, sample.data.count <= longestHit
        else { return false }

        func energy(_ slice: ArraySlice<Int8>) -> Double {
            guard !slice.isEmpty else { return 0 }
            let total = slice.reduce(0.0) { $0 + Double(Int($1) * Int($1)) }
            return (total / Double(slice.count)).squareRoot()
        }

        let third = sample.data.count / 3
        guard third > 0 else { return false }
        let opening = energy(sample.data[0..<third])
        let closing = energy(sample.data[(sample.data.count - third)...])
        guard opening > 1 else { return false }

        // The peak arrives early, and the tail is well below the opening.
        let peakIndex = sample.data.indices.max { abs(Int(sample.data[$0])) < abs(Int(sample.data[$1])) }
        let peakIsEarly = (peakIndex ?? 0) < sample.data.count / 5
        return peakIsEarly && closing < opening * 0.28
    }

    /// Whether a name carries no information about the instrument.
    ///
    /// Trackers leave samples unnamed, or label them by slot rather than by
    /// instrument. Those names say nothing either way.
    static func nameIsUninformative(_ name: String) -> Bool {
        let text = normalize(name)
        if text.isEmpty { return true }
        // "st-01", "smp12", "sample3" and bare numbers name a slot, not a sound.
        let withoutDigits = text.filter { !$0.isNumber }
        return withoutDigits.isEmpty
            || ["st", "smp", "sample", "inst", "instr", "sound", "snd"]
                .contains(String(withoutDigits))
    }

    /// Judges one sample, and says on what grounds.
    ///
    /// Shape is only consulted when the name says nothing. A sample called
    /// `organ2` is short and dies away like a hit, but it is an organ, and
    /// pulling it to the middle would be heard. A name that is not a drum word
    /// is treated as evidence against, not as no evidence.
    public static func evidence(for sample: ProTrackerSample) -> Evidence? {
        if nameSuggestsPercussion(sample.name) { return .name }
        if nameIsUninformative(sample.name), shapeSuggestsPercussion(sample) {
            return .shape
        }
        return nil
    }

    /// Builds the per-sample tuning that pulls a module's percussion inward.
    ///
    /// Existing tuning for a sample is kept, so a hand-set gain or send is not
    /// lost when the beat is centred.
    public static func centering(
        for module: ProTrackerModule,
        amount: Double,
        existing: [Int: ProTrackerVoiceTuning] = [:]
    ) -> [Int: ProTrackerVoiceTuning] {
        let pull = min(1, max(0, amount))
        guard pull > 0 else { return existing }
        var tuning = existing
        for (index, sample) in module.samples.enumerated() where evidence(for: sample) != nil {
            var entry = tuning[index] ?? ProTrackerVoiceTuning()
            entry.centering = max(entry.centering, pull)
            tuning[index] = entry
        }
        return tuning
    }
}
