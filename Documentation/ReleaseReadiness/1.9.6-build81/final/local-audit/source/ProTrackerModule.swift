import Foundation

/// A ProTracker module and a player for it.
///
/// Amiga music of this era is sample based, not FM. A module stores a set of
/// 8-bit samples and a grid of patterns that trigger them. Playback resamples
/// each voice at a rate derived from an Amiga period value, which is what gives
/// tracker music its character.
///
/// This is independent of the OPL2 synthesizer. FM covers the DOS audio.
/// This covers module music the player may supply.

public struct ProTrackerSample: Sendable, Equatable {
    public let name: String
    /// Signed 8-bit PCM.
    public let data: [Int8]
    public let finetune: Int
    public let volume: Int
    public let repeatStart: Int
    public let repeatLength: Int

    public init(
        name: String, data: [Int8], finetune: Int, volume: Int,
        repeatStart: Int, repeatLength: Int
    ) {
        self.name = name
        self.data = data
        self.finetune = finetune
        self.volume = volume
        self.repeatStart = repeatStart
        self.repeatLength = repeatLength
    }

    public var loops: Bool { repeatLength > 2 }
}

public struct ProTrackerNote: Sendable, Equatable {
    public let sample: Int
    public let period: Int
    public let effect: Int
    public let parameter: Int

    public var isEmpty: Bool { sample == 0 && period == 0 && effect == 0 && parameter == 0 }
}

public enum ProTrackerError: Error, Equatable, CustomStringConvertible {
    case tooShort(Int)
    case unknownFormat(String)
    case badPatternCount(Int)
    case truncatedPatterns(expected: Int, available: Int)

    public var description: String {
        switch self {
        case let .tooShort(count): return "module is only \(count) bytes"
        case let .unknownFormat(tag): return "unknown module tag '\(tag)'"
        case let .badPatternCount(count): return "implausible pattern count \(count)"
        case let .truncatedPatterns(expected, available):
            return "pattern data needs \(expected) bytes, file has \(available)"
        }
    }
}

public struct ProTrackerModule: Sendable {
    public let title: String
    public let samples: [ProTrackerSample]
    public let channelCount: Int
    public let songLength: Int
    public let order: [Int]
    /// `patterns[pattern][row][channel]`
    public let patterns: [[[ProTrackerNote]]]

    public static let rowsPerPattern = 64

    /// Amiga periods for notes C-1 to B-3 at finetune 0.
    public static let periodTable: [Int] = [
        856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
        428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
        214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
    ]

    /// PAL Amiga clock. Sample rate for a period is this divided by 2 * period.
    public static let palClock = 7_093_789.2

    public init(data: Data) throws {
        guard data.count >= 1084 else { throw ProTrackerError.tooShort(data.count) }
        let bytes = [UInt8](data)

        func string(_ range: Range<Int>) -> String {
            String(decoding: bytes[range].prefix { $0 != 0 }, as: UTF8.self)
                .trimmingCharacters(in: .whitespaces)
        }
        func word(_ offset: Int) -> Int {
            (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
        }

        title = string(0..<20)

        let tag = String(decoding: bytes[1080..<1084], as: UTF8.self)
        switch tag {
        case "M.K.", "M!K!", "FLT4", "4CHN": channelCount = 4
        case "6CHN": channelCount = 6
        case "8CHN", "CD81", "OKTA": channelCount = 8
        default: throw ProTrackerError.unknownFormat(tag)
        }

        // 31 sample headers of 30 bytes each, starting at byte 20.
        var headers: [(name: String, length: Int, finetune: Int, volume: Int, start: Int, loop: Int)] = []
        for index in 0..<31 {
            let base = 20 + index * 30
            let rawFinetune = Int(bytes[base + 24] & 0x0F)
            headers.append((
                name: string(base..<(base + 22)),
                length: word(base + 22) * 2,
                finetune: rawFinetune > 7 ? rawFinetune - 16 : rawFinetune,
                volume: min(64, Int(bytes[base + 25])),
                start: word(base + 26) * 2,
                loop: word(base + 28) * 2
            ))
        }

        songLength = min(128, Int(bytes[950]))
        order = (0..<128).map { Int(bytes[952 + $0]) }

        let patternCount = (order.prefix(max(1, songLength)).max() ?? 0) + 1
        guard patternCount > 0, patternCount <= 128 else {
            throw ProTrackerError.badPatternCount(patternCount)
        }

        let patternBytes = patternCount * Self.rowsPerPattern * channelCount * 4
        guard data.count >= 1084 + patternBytes else {
            throw ProTrackerError.truncatedPatterns(
                expected: 1084 + patternBytes, available: data.count)
        }

        var built: [[[ProTrackerNote]]] = []
        var cursor = 1084
        for _ in 0..<patternCount {
            var rows: [[ProTrackerNote]] = []
            for _ in 0..<Self.rowsPerPattern {
                var row: [ProTrackerNote] = []
                for _ in 0..<channelCount {
                    let b0 = Int(bytes[cursor])
                    let b1 = Int(bytes[cursor + 1])
                    let b2 = Int(bytes[cursor + 2])
                    let b3 = Int(bytes[cursor + 3])
                    row.append(ProTrackerNote(
                        sample: (b0 & 0xF0) | (b2 >> 4),
                        period: ((b0 & 0x0F) << 8) | b1,
                        effect: b2 & 0x0F,
                        parameter: b3))
                    cursor += 4
                }
                rows.append(row)
            }
            built.append(rows)
        }
        patterns = built

        // Sample PCM follows the patterns, in header order.
        var samples: [ProTrackerSample] = []
        for header in headers {
            let end = min(data.count, cursor + header.length)
            let pcm = cursor < end
                ? bytes[cursor..<end].map { Int8(bitPattern: $0) }
                : []
            cursor = end
            samples.append(ProTrackerSample(
                name: header.name,
                data: pcm,
                finetune: header.finetune,
                volume: header.volume,
                repeatStart: header.start,
                repeatLength: header.loop))
        }
        self.samples = samples
    }
}

/// How a voice reads between sample points.
///
/// The Amiga hardware repeats the nearest byte, which is part of the sound.
/// Linear reading removes some of the aliasing for modern listening.
public enum ProTrackerInterpolation: String, Codable, Sendable {
    case none
    case linear
}

/// One voice's output for a single frame, before mixing.
public struct ProTrackerVoiceOutput: Sendable {
    public let value: Double
    public let sampleIndex: Int
    public let isActive: Bool

    public static let silent = ProTrackerVoiceOutput(
        value: 0, sampleIndex: -1, isActive: false)
}

/// Renders a module to audio.
///
/// Effect coverage follows what the Lemmings modules actually use: set volume,
/// position jump, pattern break, speed and tempo, both portamentos, tone
/// portamento and arpeggio. The set filter command is accepted and ignored,
/// because it drove an Amiga hardware filter that has no meaning here.
public struct ProTrackerPlayer: Sendable {
    private struct Voice {
        var sampleIndex = 0
        var position = 0.0
        var increment = 0.0
        var volume = 0
        var period = 0
        var isActive = false

        // Effect state, carried between ticks.
        var portaSpeed = 0
        var targetPeriod = 0
        var toneSpeed = 0
        var arpeggioFirst = 0
        var arpeggioSecond = 0
        var hasArpeggio = false
    }

    public let module: ProTrackerModule
    public let sampleRate: Double
    /// Defaults to the hardware behavior.
    public var interpolation: ProTrackerInterpolation = .none

    private var voices: [Voice]
    private var scratch: [ProTrackerVoiceOutput]
    private var orderIndex = 0
    private var row = 0
    private var tick = 0
    private var samplesUntilTick = 0.0
    private var hasStarted = false
    /// Ticks per row. ProTracker starts at six.
    private var speed = 6
    private var beatsPerMinute = 125
    private var pendingOrder: Int?
    private var pendingRow: Int?
    public private(set) var hasFinished = false

    public init(module: ProTrackerModule, sampleRate: Double = 44100) {
        self.module = module
        self.sampleRate = sampleRate
        voices = [Voice](repeating: Voice(), count: module.channelCount)
        scratch = [ProTrackerVoiceOutput](
            repeating: .silent, count: module.channelCount)
    }

    public var musicalBPM: Double { Double(beatsPerMinute) * 6 / Double(max(1, speed)) }
    public var secondsUntilNextBeat: Double {
        if !hasStarted { return 0 }
        let elapsedTick = 1 - min(1, max(0, samplesUntilTick / samplesPerTick))
        let fraction = Double(row % 4) + (Double(tick) + elapsedTick) / Double(max(1, speed))
        let rowsLeft = 4 - fraction
        return max(0, rowsLeft * Double(speed) * 2.5 / Double(beatsPerMinute))
    }

    private var samplesPerTick: Double {
        // ProTracker derives the tick rate from the tempo this way.
        sampleRate * 2.5 / Double(beatsPerMinute)
    }

    private static let minimumPeriod = 113
    private static let maximumPeriod = 856

    private func increment(forPeriod period: Int) -> Double {
        guard period > 0 else { return 0 }
        return ProTrackerModule.palClock / (2.0 * Double(period)) / sampleRate
    }

    /// Shifts a period by whole semitones, which is how arpeggio works.
    private func period(_ period: Int, semitonesUp semitones: Int) -> Int {
        guard semitones != 0 else { return period }
        return max(
            Self.minimumPeriod,
            Int((Double(period) / pow(2.0, Double(semitones) / 12.0)).rounded()))
    }

    // MARK: - Row and tick handling

    private mutating func startRow() {
        guard orderIndex < module.songLength else {
            hasFinished = true
            return
        }
        let pattern = module.order[orderIndex]
        guard pattern < module.patterns.count else {
            hasFinished = true
            return
        }
        let cells = module.patterns[pattern][row]

        for (channel, note) in cells.enumerated() where channel < voices.count {
            var voice = voices[channel]
            voice.hasArpeggio = false

            if note.sample > 0, note.sample <= module.samples.count {
                voice.sampleIndex = note.sample - 1
                voice.volume = module.samples[note.sample - 1].volume
            }

            if note.period > 0 {
                if note.effect == 0x03 {
                    // Tone portamento slides to the note instead of retriggering.
                    voice.targetPeriod = note.period
                } else {
                    voice.period = note.period
                    voice.targetPeriod = note.period
                    voice.position = 0
                    voice.isActive = true
                    voice.increment = increment(forPeriod: note.period)
                }
            }

            applyRowEffect(note, voice: &voice)
            voices[channel] = voice
        }
    }

    private mutating func applyRowEffect(_ note: ProTrackerNote, voice: inout Voice) {
        switch note.effect {
        case 0x00:
            if note.parameter != 0 {
                voice.hasArpeggio = true
                voice.arpeggioFirst = note.parameter >> 4
                voice.arpeggioSecond = note.parameter & 0x0F
            }
        case 0x01, 0x02:
            voice.portaSpeed = note.parameter
        case 0x03:
            if note.parameter != 0 { voice.toneSpeed = note.parameter }
        case 0x0B:
            pendingOrder = note.parameter
            pendingRow = 0
        case 0x0C:
            voice.volume = min(64, note.parameter)
        case 0x0D:
            // The parameter is the target row, in decimal digits.
            pendingOrder = orderIndex + 1
            pendingRow = (note.parameter >> 4) * 10 + (note.parameter & 0x0F)
        case 0x0E:
            // E0 drove the Amiga hardware filter. Nothing else is used here.
            break
        case 0x0F:
            if note.parameter == 0 {
                hasFinished = true
            } else if note.parameter < 0x20 {
                speed = note.parameter
            } else {
                beatsPerMinute = note.parameter
            }
        default:
            break
        }
    }

    /// Effects that keep working on every tick after the first.
    private mutating func applyTickEffects() {
        guard orderIndex < module.songLength else { return }
        let pattern = module.order[orderIndex]
        guard pattern < module.patterns.count else { return }
        let cells = module.patterns[pattern][row]

        for (channel, note) in cells.enumerated() where channel < voices.count {
            var voice = voices[channel]
            switch note.effect {
            case 0x00 where voice.hasArpeggio:
                let step = tick % 3
                let semitones = step == 0
                    ? 0 : (step == 1 ? voice.arpeggioFirst : voice.arpeggioSecond)
                voice.increment = increment(
                    forPeriod: period(voice.period, semitonesUp: semitones))
            case 0x01:
                voice.period = max(Self.minimumPeriod, voice.period - voice.portaSpeed)
                voice.increment = increment(forPeriod: voice.period)
            case 0x02:
                voice.period = min(Self.maximumPeriod, voice.period + voice.portaSpeed)
                voice.increment = increment(forPeriod: voice.period)
            case 0x03:
                if voice.targetPeriod > 0, voice.period != voice.targetPeriod {
                    if voice.period < voice.targetPeriod {
                        voice.period = min(voice.targetPeriod, voice.period + voice.toneSpeed)
                    } else {
                        voice.period = max(voice.targetPeriod, voice.period - voice.toneSpeed)
                    }
                    voice.increment = increment(forPeriod: voice.period)
                }
            default:
                break
            }
            voices[channel] = voice
        }
    }

    private mutating func advanceRow() {
        if let order = pendingOrder {
            orderIndex = order
            row = pendingRow ?? 0
            pendingOrder = nil
            pendingRow = nil
        } else {
            row += 1
            if row >= ProTrackerModule.rowsPerPattern {
                row = 0
                orderIndex += 1
            }
        }
        if orderIndex >= module.songLength { hasFinished = true }
    }

    private mutating func processTick() {
        guard !hasFinished else { return }
        if !hasStarted {
            hasStarted = true
            tick = 0
            startRow()
            return
        }
        tick += 1
        if tick >= speed {
            tick = 0
            advanceRow()
            if !hasFinished { startRow() }
        } else {
            applyTickEffects()
        }
    }

    /// Reads one frame from a voice, honoring the loop and the interpolation.
    private func read(_ voice: Voice, _ sample: ProTrackerSample) -> Double {
        let count = sample.data.count
        guard count > 0 else { return 0 }
        let position = Int(voice.position)
        guard position < count else { return 0 }
        let first = Double(sample.data[position])

        guard interpolation == .linear else { return first }
        var nextIndex = position + 1
        if nextIndex >= count {
            nextIndex = sample.loops ? sample.repeatStart : position
        }
        guard nextIndex < count else { return first }
        let fraction = voice.position - Double(position)
        return first + (Double(sample.data[nextIndex]) - first) * fraction
    }

    /// Advances one frame and writes each voice's output separately.
    ///
    /// Keeping the voices apart lets a caller pan, filter or send them
    /// individually, which mixing them here would prevent.
    public mutating func nextVoiceOutputs(into outputs: inout [ProTrackerVoiceOutput]) {
        if samplesUntilTick <= 0 {
            processTick()
            samplesUntilTick += samplesPerTick
        }
        samplesUntilTick -= 1

        for index in voices.indices {
            var voice = voices[index]
            guard voice.isActive, voice.sampleIndex < module.samples.count else {
                if index < outputs.count { outputs[index] = .silent }
                continue
            }
            let sample = module.samples[voice.sampleIndex]
            guard !sample.data.isEmpty else {
                voices[index] = voice
                if index < outputs.count { outputs[index] = .silent }
                continue
            }

            var position = Int(voice.position)
            if position >= sample.data.count {
                if sample.loops {
                    let loopEnd = min(sample.data.count, sample.repeatStart + sample.repeatLength)
                    let span = max(1, loopEnd - sample.repeatStart)
                    position = sample.repeatStart + (position - sample.repeatStart) % span
                    voice.position = Double(position)
                } else {
                    voice.isActive = false
                    voices[index] = voice
                    if index < outputs.count { outputs[index] = .silent }
                    continue
                }
            }

            let value = read(voice, sample) / 128.0 * Double(voice.volume) / 64.0
            voice.position += voice.increment
            voices[index] = voice
            if index < outputs.count {
                outputs[index] = ProTrackerVoiceOutput(
                    value: value, sampleIndex: voice.sampleIndex, isActive: true)
            }
        }
    }

    /// Produces the next mono sample, in the range -1 to 1.
    public mutating func nextSample() -> Float {
        // Move the buffer out of self so the inout access does not overlap the
        // mutating call, and so no copy is made.
        var buffer = scratch
        scratch = []
        nextVoiceOutputs(into: &buffer)
        let mix = buffer.reduce(0.0) { $0 + $1.value }
        scratch = buffer
        // Divide by the channel count so a full module cannot clip.
        return Float(max(-1, min(1, mix / Double(module.channelCount))))
    }

    public mutating func render(into buffer: inout [Float]) {
        for index in buffer.indices { buffer[index] = nextSample() }
    }
}
