import Foundation

/// Sample indices resolved through L2.RKO's FXNumber table at 4877.
public enum Lemmings2SoundCue: Int, Sendable, Hashable {
    case launched = 0, rope = 2, balloonPop = 3, countdown = 22, valve = 31, teleporter = 34
    case levelStart = 18, doorOpen = 10, assignSkill = 21, explode = 11
    case splat = 27, drown = 37, fire = 35, fallOut = 17, builderWarning = 33, hitSteel = 8
}

public struct Lemmings2SoundRequest: Sendable, Hashable {
    public let isBottomFall: Bool
    public let sample: Int
    public let timeConstant: UInt8?
    public init(_ cue: Lemmings2SoundCue, isBottomFall: Bool = false) { sample = cue.rawValue; timeConstant = nil; self.isBottomFall = isBottomFall }
    private init(sample: Int, timeConstant: UInt8) { self.sample = sample; self.timeConstant = timeConstant; isBottomFall = false }
    public static func assignment(skill: Lemmings2Runtime.Skill, tribe: Int) -> Self {
        let sample: Int
        switch skill {
        case .jumper: sample = 15
        case .superlem: sample = 30
        case .surfer: sample = 36
        case .attractor where (1..<12).contains(tribe): sample = 37+tribe
        default: return Self(.assignSkill)
        }
        return Self(sample:sample)
    }
    public static func introduction(sample: Int) -> Self? {
        (0..<79).contains(sample) ? Self(sample:sample) : nil
    }
    private init(sample: Int) { self.sample = sample; timeConstant = nil; isBottomFall = false }
    public static func panel(slot: Int) -> Self? {
        // Native panel clicks transpose one sample for each of the twelve slots.
        let pitches: [UInt8] = [136,142,149,155,160,166,171,176,180,184,188,192]
        guard pitches.indices.contains(slot) else { return nil }
        return Self(sample: 49, timeConstant: pitches[slot])
    }
}

/// The DOS Sound Blaster bank is an offset table followed by Creative Voice files.
/// Only PCM and silence are decoded; no original sound-driver code is executed.
public struct Lemmings2SoundBank: Sendable {
    public struct Clip: Sendable {
        public let samples: [Float]
        public let sampleRate: Double
    }
    public let clips: [Clip]
    public init(data: Data) throws {
        let r = SequelBinary(data)
        guard r.count >= 512, r.count <= 16_777_216 else { throw SequelDataError.invalid("Invalid L2 sound bank size.") }
        let table = try (0..<128).map { try r.u32($0 * 4) }
        guard table[0] == 0 else { throw SequelDataError.invalid("Invalid L2 sound bank origin.") }
        let count = table.dropFirst().firstIndex(of: 0) ?? 128
        guard count > 1, table[count...].allSatisfy({ $0 == 0 }) else {
            throw SequelDataError.invalid("Invalid L2 sound offset table.")
        }
        var clips: [Clip] = []
        for i in 0..<count {
            let start = 512 + table[i], end = i + 1 < count ? 512 + table[i + 1] : r.count
            guard start < end, end <= r.count else { throw SequelDataError.invalid("Invalid L2 sound offset.") }
            clips.append(try Self.decodeVoice(Data(r.slice(start, end - start))))
        }
        self.clips = clips
    }

    public static func decodeVoice(_ data: Data) throws -> Clip {
        let r = SequelBinary(data)
        guard try r.slice(0, 20) == Array("Creative Voice File\u{1a}".utf8),
              try r.u16(24) == ((~r.u16(22) + 0x1234) & 0xffff) else {
            throw SequelDataError.invalid("Invalid Creative Voice header.")
        }
        var cursor = try r.u16(20)
        guard cursor >= 26, cursor < r.count else { throw SequelDataError.invalid("Invalid Creative Voice data offset.") }
        var rate = 0.0, currentRate = 0.0, samples: [Float] = [], ended = false
        func append(_ segment: [Float], at segmentRate: Double) throws {
            if rate == 0 { rate = segmentRate }
            let count = Int((Double(segment.count) * rate / segmentRate).rounded())
            guard count <= 4_194_304 - samples.count else { throw SequelDataError.invalid("L2 sound is too long.") }
            for i in 0..<count {
                let position = min(Double(segment.count - 1), Double(i) * segmentRate / rate)
                let a = Int(position), b = min(a + 1, segment.count - 1)
                samples.append(segment[a] + (segment[b] - segment[a]) * Float(position - Double(a)))
            }
        }
        while cursor < r.count {
            let type = try r.slice(cursor, 1)[0]; cursor += 1
            if type == 0 { ended = true; break }
            let bytes = try r.slice(cursor, 3)
            let length = Int(bytes[0]) | Int(bytes[1]) << 8 | Int(bytes[2]) << 16
            cursor += 3
            let block = try r.slice(cursor, length); cursor += length
            switch type {
            case 1:
                guard block.count >= 3, block[1] == 0 else { throw SequelDataError.invalid("Unsupported L2 sound codec.") }
                currentRate = 1_000_000 / Double(256 - Int(block[0]))
                try append(block.dropFirst(2).map { (Float($0) - 128) / 128 }, at: currentRate)
            case 2:
                guard currentRate > 0, !block.isEmpty else { throw SequelDataError.invalid("Invalid L2 sound continuation.") }
                try append(block.map { (Float($0) - 128) / 128 }, at: currentRate)
            case 3:
                guard block.count == 3 else { throw SequelDataError.invalid("Invalid L2 silence block.") }
                try append([Float](repeating: 0, count: (Int(block[0]) | Int(block[1]) << 8) + 1),
                           at: 1_000_000 / Double(256 - Int(block[2])))
            default: throw SequelDataError.invalid("Unsupported L2 voice block \(type).")
            }
        }
        // The final shipped voice has an unused 0x7f alignment byte after its terminator.
        let aligned = cursor.isMultiple(of: 2) == false && r.count == cursor + 1
        guard ended, !samples.isEmpty, cursor == r.count || aligned else {
            throw SequelDataError.invalid("Incomplete L2 voice sample.")
        }
        return Clip(samples: samples, sampleRate: rate)
    }
}

/// Fixed-voice PCM mixer shared by the audio callback and offline regression tests.
public struct Lemmings2SoundMixer: Sendable {
    private struct Voice: Sendable {
        let samples: [Float]
        var position: Double
        let increment: Double
        var remaining: Double { (Double(samples.count) - position) / increment }
    }
    public let bank: Lemmings2SoundBank
    private var voices: [Voice?] = Array(repeating: nil, count: 8)
    public private(set) var muted = false
    public init(bank: Lemmings2SoundBank) { self.bank = bank }
    public mutating func silence() { for i in voices.indices { voices[i] = nil } }
    public mutating func setMuted(_ muted: Bool) { self.muted = muted; if muted { silence() } }
    public mutating func play(_ request: Lemmings2SoundRequest) {
        guard !muted, bank.clips.indices.contains(request.sample) else { return }
        let clip = bank.clips[request.sample]
        let rate = request.timeConstant.map { 1_000_000 / Double(256 - Int($0)) } ?? clip.sampleRate
        let index = voices.firstIndex(where: { $0 == nil }) ?? voices.indices.min(by: {
            voices[$0]!.remaining < voices[$1]!.remaining
        })!
        voices[index] = Voice(samples: clip.samples, position: 0, increment: rate / 44100)
    }
    public mutating func nextSample() -> Float {
        var sum: Float = 0
        for i in voices.indices {
            guard let voice = voices[i] else { continue }
            let a = Int(voice.position), b = min(a + 1, voice.samples.count - 1)
            sum += voice.samples[a] + (voice.samples[b] - voice.samples[a]) * Float(voice.position - Double(a))
            voices[i]!.position += voice.increment
            if voices[i]!.position >= Double(voice.samples.count) { voices[i] = nil }
        }
        return max(-1, min(1, sum * 0.5))
    }
}
