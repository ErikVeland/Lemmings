import Foundation

/// Optional processing for module playback on modern systems.
///
/// Every setting defaults to the Amiga behavior, so an untouched value plays
/// the module as the hardware did. Turning something on is always a deliberate
/// choice, which keeps the faithful rendering available for comparison.

/// Per-sample adjustment, for the instruments that need it rather than all.
public struct ProTrackerVoiceTuning: Codable, Equatable, Sendable {
    /// Linear gain. 1 leaves the sample alone.
    public var gain: Double
    /// How much of this instrument feeds the reverb, from 0 to 1.
    public var reverbSend: Double
    /// Shifts this instrument across the stereo field, from -1 to 1.
    public var panOffset: Double
    /// Pulls this instrument toward the middle, from 0 to 1.
    ///
    /// This is a pull rather than a position because a module plays the same
    /// sample on whichever channel is free, and the channels are panned apart.
    /// A fixed offset would centre the sample on one side and push it further
    /// out on the other. Scaling the channel's own pan works wherever the
    /// note lands.
    public var centering: Double

    public init(
        gain: Double = 1, reverbSend: Double = 0, panOffset: Double = 0,
        centering: Double = 0
    ) {
        self.gain = gain
        self.reverbSend = reverbSend
        self.panOffset = panOffset
        self.centering = centering
    }
}

public struct ProTrackerEnhancements: Codable, Equatable, Sendable {
    public var interpolation: ProTrackerInterpolation
    /// 1 is the Amiga's full left-right split. 0 is mono.
    ///
    /// The hardware panned channels hard apart, which is tiring on headphones.
    /// Around 0.6 keeps the separation without the split-head effect.
    public var stereoSeparation: Double

    public var lowGainDB: Double
    public var lowFrequency: Double
    public var midGainDB: Double
    public var midFrequency: Double
    public var midQ: Double
    public var highGainDB: Double
    public var highFrequency: Double

    /// Wet level, from 0 to 1.
    public var reverbMix: Double
    public var reverbRoomSize: Double
    public var reverbDamping: Double

    public var outputGain: Double
    /// How far percussion is pulled toward the middle, from 0 to 1.
    ///
    /// The Amiga panned its four channels hard apart, so a kick drum sat in
    /// one ear. Modern mixes put the beat in the middle. Which samples count
    /// as percussion is worked out per module, because a module names its own
    /// samples.
    public var percussionCentering: Double
    /// Keyed by sample index, counting from zero.
    public var voiceTuning: [Int: ProTrackerVoiceTuning]

    public init(
        interpolation: ProTrackerInterpolation = .none,
        stereoSeparation: Double = 1,
        lowGainDB: Double = 0,
        lowFrequency: Double = 120,
        midGainDB: Double = 0,
        midFrequency: Double = 900,
        midQ: Double = 0.9,
        highGainDB: Double = 0,
        highFrequency: Double = 6000,
        reverbMix: Double = 0,
        reverbRoomSize: Double = 0.72,
        reverbDamping: Double = 0.45,
        outputGain: Double = 1,
        percussionCentering: Double = 0,
        voiceTuning: [Int: ProTrackerVoiceTuning] = [:]
    ) {
        self.interpolation = interpolation
        self.stereoSeparation = stereoSeparation
        self.lowGainDB = lowGainDB
        self.lowFrequency = lowFrequency
        self.midGainDB = midGainDB
        self.midFrequency = midFrequency
        self.midQ = midQ
        self.highGainDB = highGainDB
        self.highFrequency = highFrequency
        self.reverbMix = reverbMix
        self.reverbRoomSize = reverbRoomSize
        self.reverbDamping = reverbDamping
        self.outputGain = outputGain
        self.percussionCentering = percussionCentering
        self.voiceTuning = voiceTuning
    }

    /// Exactly what the Amiga did.
    public static let faithful = ProTrackerEnhancements()

    /// A modern setting with weight and attack.
    ///
    /// The earlier version of this dulled the music rather than lifting it. It
    /// scooped the mids, narrowed the stereo field, washed the transients in
    /// reverb, and turned the output down, all on top of the smoothing that
    /// linear interpolation already applies to an 8-bit sample. Next to the
    /// faithful setting it sounded muffled, which is the opposite of the point.
    ///
    /// This keeps the interpolation, because it removes the aliasing whine,
    /// and answers it with air at the top instead of a cut in the middle. The
    /// low shelf sits lower so it adds weight rather than mud, the reverb is
    /// short enough to leave attacks alone, and the field opens back up.
    ///
    /// The output gain leaves room for the boosts. The mixer clips rather than
    /// limits, so the headroom has to come from somewhere.
    public static let modern = ProTrackerEnhancements(
        interpolation: .linear,
        stereoSeparation: 0.80,
        lowGainDB: 4.0,
        lowFrequency: 90,
        midGainDB: 0,
        midFrequency: 900,
        highGainDB: 3.5,
        highFrequency: 8000,
        reverbMix: 0.07,
        reverbRoomSize: 0.60,
        reverbDamping: 0.45,
        outputGain: 0.85,
        percussionCentering: 0.85
    )

    public var isFaithful: Bool { self == .faithful }
}

// MARK: - Filters

/// A two-pole filter section, using the standard audio cookbook forms.
struct Biquad: Sendable {
    var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func lowShelf(frequency: Double, gainDB: Double, sampleRate: Double) -> Biquad {
        let a = pow(10, gainDB / 40)
        let w = 2 * Double.pi * frequency / sampleRate
        let cosw = cos(w), sinw = sin(w)
        let alpha = sinw / 2 * sqrt((a + 1 / a) * (1 / 0.9 - 1) + 2)
        let twoSqrtAAlpha = 2 * sqrt(a) * alpha
        let a0 = (a + 1) + (a - 1) * cosw + twoSqrtAAlpha
        var filter = Biquad()
        filter.b0 = a * ((a + 1) - (a - 1) * cosw + twoSqrtAAlpha) / a0
        filter.b1 = 2 * a * ((a - 1) - (a + 1) * cosw) / a0
        filter.b2 = a * ((a + 1) - (a - 1) * cosw - twoSqrtAAlpha) / a0
        filter.a1 = -2 * ((a - 1) + (a + 1) * cosw) / a0
        filter.a2 = ((a + 1) + (a - 1) * cosw - twoSqrtAAlpha) / a0
        return filter
    }

    static func highShelf(frequency: Double, gainDB: Double, sampleRate: Double) -> Biquad {
        let a = pow(10, gainDB / 40)
        let w = 2 * Double.pi * frequency / sampleRate
        let cosw = cos(w), sinw = sin(w)
        let alpha = sinw / 2 * sqrt((a + 1 / a) * (1 / 0.9 - 1) + 2)
        let twoSqrtAAlpha = 2 * sqrt(a) * alpha
        let a0 = (a + 1) - (a - 1) * cosw + twoSqrtAAlpha
        var filter = Biquad()
        filter.b0 = a * ((a + 1) + (a - 1) * cosw + twoSqrtAAlpha) / a0
        filter.b1 = -2 * a * ((a - 1) + (a + 1) * cosw) / a0
        filter.b2 = a * ((a + 1) + (a - 1) * cosw - twoSqrtAAlpha) / a0
        filter.a1 = 2 * ((a - 1) - (a + 1) * cosw) / a0
        filter.a2 = ((a + 1) - (a - 1) * cosw - twoSqrtAAlpha) / a0
        return filter
    }

    static func peaking(
        frequency: Double, gainDB: Double, q: Double, sampleRate: Double
    ) -> Biquad {
        let a = pow(10, gainDB / 40)
        let w = 2 * Double.pi * frequency / sampleRate
        let alpha = sin(w) / (2 * max(0.1, q))
        let a0 = 1 + alpha / a
        var filter = Biquad()
        filter.b0 = (1 + alpha * a) / a0
        filter.b1 = -2 * cos(w) / a0
        filter.b2 = (1 - alpha * a) / a0
        filter.a1 = -2 * cos(w) / a0
        filter.a2 = (1 - alpha / a) / a0
        return filter
    }

    mutating func process(_ input: Double) -> Double {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        return output
    }
}

// MARK: - Reverb

/// A small room built from comb and all-pass sections.
struct Reverb: Sendable {
    private struct Comb: Sendable {
        var buffer: [Double]
        var index = 0
        var store = 0.0

        init(length: Int) { buffer = [Double](repeating: 0, count: max(1, length)) }

        mutating func process(_ input: Double, feedback: Double, damping: Double) -> Double {
            let output = buffer[index]
            store = output * (1 - damping) + store * damping
            buffer[index] = input + store * feedback
            index = (index + 1) % buffer.count
            return output
        }
    }

    private struct Allpass: Sendable {
        var buffer: [Double]
        var index = 0

        init(length: Int) { buffer = [Double](repeating: 0, count: max(1, length)) }

        mutating func process(_ input: Double) -> Double {
            let stored = buffer[index]
            let output = -input + stored
            buffer[index] = input + stored * 0.5
            index = (index + 1) % buffer.count
            return output
        }
    }

    private var combs: [Comb]
    private var allpasses: [Allpass]

    /// Delay lengths are relatively prime so the tail does not ring.
    init(sampleRate: Double, spread: Int) {
        let scale = sampleRate / 44100.0
        let combLengths = [1116, 1188, 1277, 1356, 1422, 1491]
        let allpassLengths = [556, 441, 341]
        combs = combLengths.map { Comb(length: Int(Double($0) * scale) + spread) }
        allpasses = allpassLengths.map { Allpass(length: Int(Double($0) * scale) + spread) }
    }

    mutating func process(_ input: Double, roomSize: Double, damping: Double) -> Double {
        let feedback = 0.7 + min(0.28, max(0, roomSize)) * 0.28
        var output = 0.0
        for index in combs.indices {
            output += combs[index].process(input, feedback: feedback, damping: damping)
        }
        output /= Double(combs.count)
        for index in allpasses.indices {
            output = allpasses[index].process(output)
        }
        return output
    }
}

// MARK: - Enhanced player

/// A module player with the optional processing applied.
public struct ProTrackerEnhancedPlayer: Sendable {
    public private(set) var player: ProTrackerPlayer
    public let enhancements: ProTrackerEnhancements

    private var outputs: [ProTrackerVoiceOutput]
    private var leftLow: Biquad
    private var leftMid: Biquad
    private var leftHigh: Biquad
    private var rightLow: Biquad
    private var rightMid: Biquad
    private var rightHigh: Biquad
    private var leftReverb: Reverb
    private var rightReverb: Reverb
    private let usesEqualizer: Bool

    public var hasFinished: Bool { player.hasFinished }

    public init(
        module: ProTrackerModule,
        sampleRate: Double = 44100,
        enhancements: ProTrackerEnhancements = .faithful
    ) {
        var player = ProTrackerPlayer(module: module, sampleRate: sampleRate)
        player.interpolation = enhancements.interpolation
        self.player = player

        // Which samples are drums depends on the module, so the tuning is
        // worked out here rather than living in a shared preset.
        var resolved = enhancements
        if enhancements.percussionCentering > 0 {
            resolved.voiceTuning = ProTrackerPercussion.centering(
                for: module,
                amount: enhancements.percussionCentering,
                existing: enhancements.voiceTuning)
        }
        self.enhancements = resolved
        outputs = [ProTrackerVoiceOutput](
            repeating: .silent, count: module.channelCount)

        leftLow = .lowShelf(
            frequency: enhancements.lowFrequency, gainDB: enhancements.lowGainDB,
            sampleRate: sampleRate)
        rightLow = leftLow
        leftMid = .peaking(
            frequency: enhancements.midFrequency, gainDB: enhancements.midGainDB,
            q: enhancements.midQ, sampleRate: sampleRate)
        rightMid = leftMid
        leftHigh = .highShelf(
            frequency: enhancements.highFrequency, gainDB: enhancements.highGainDB,
            sampleRate: sampleRate)
        rightHigh = leftHigh

        leftReverb = Reverb(sampleRate: sampleRate, spread: 0)
        rightReverb = Reverb(sampleRate: sampleRate, spread: 23)

        usesEqualizer = enhancements.lowGainDB != 0
            || enhancements.midGainDB != 0
            || enhancements.highGainDB != 0
    }

    /// The Amiga panned its four voices left, right, right, left.
    private static func isLeftChannel(_ index: Int) -> Bool {
        let position = index % 4
        return position == 0 || position == 3
    }

    public mutating func nextFrame() -> (left: Float, right: Float) {
        var buffer = outputs
        outputs = []
        player.nextVoiceOutputs(into: &buffer)

        var left = 0.0
        var right = 0.0
        var reverbSend = 0.0

        let separation = min(1, max(0, enhancements.stereoSeparation))
        for (index, output) in buffer.enumerated() where output.isActive {
            let tuning = enhancements.voiceTuning[output.sampleIndex]
            let value = output.value * (tuning?.gain ?? 1)

            // -1 is hard left, 1 is hard right.
            var pan = Self.isLeftChannel(index) ? -separation : separation
            // Pull toward the middle first, then apply any deliberate shift.
            pan *= 1 - min(1, max(0, tuning?.centering ?? 0))
            pan = min(1, max(-1, pan + (tuning?.panOffset ?? 0)))
            let leftGain = (1 - pan) / 2
            let rightGain = (1 + pan) / 2

            left += value * leftGain
            right += value * rightGain
            if let send = tuning?.reverbSend, send > 0 {
                reverbSend += value * send
            }
        }
        outputs = buffer

        let scale = 1.0 / Double(player.module.channelCount)
        left *= scale
        right *= scale

        if usesEqualizer {
            left = leftHigh.process(leftMid.process(leftLow.process(left)))
            right = rightHigh.process(rightMid.process(rightLow.process(right)))
        }

        if enhancements.reverbMix > 0 {
            // Instruments with an explicit send feed the room on top of the mix.
            let source = (left + right) / 2 + reverbSend * scale
            let wetLeft = leftReverb.process(
                source, roomSize: enhancements.reverbRoomSize,
                damping: enhancements.reverbDamping)
            let wetRight = rightReverb.process(
                source, roomSize: enhancements.reverbRoomSize,
                damping: enhancements.reverbDamping)
            let mix = min(1, max(0, enhancements.reverbMix))
            left = left * (1 - mix) + wetLeft * mix
            right = right * (1 - mix) + wetRight * mix
        }

        left *= enhancements.outputGain
        right *= enhancements.outputGain
        return (
            Float(min(1, max(-1, left))),
            Float(min(1, max(-1, right)))
        )
    }

    public mutating func render(left: inout [Float], right: inout [Float]) {
        let count = min(left.count, right.count)
        for index in 0..<count {
            let frame = nextFrame()
            left[index] = frame.left
            right[index] = frame.right
        }
    }
}
