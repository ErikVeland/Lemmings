import Foundation

/// A Yamaha YM3812 (OPL2) FM synthesizer.
///
/// The chip works in the logarithmic domain. A sine lookup returns attenuation
/// rather than amplitude, envelope attenuation is added to it, and an
/// exponential lookup converts the sum back to a linear sample. Reproducing
/// that structure, instead of computing sine values directly, is what makes
/// the output match an Ad-Lib card.
///
/// Register layout follows the hardware:
/// `0x20` multiplier and flags, `0x40` level, `0x60` attack and decay,
/// `0x80` sustain and release, `0xA0` frequency low, `0xB0` frequency high and
/// key-on, `0xC0` feedback and connection, `0xE0` waveform.
public struct OPL2: Sendable {
    /// The chip clock divided by 72, which is the rate the hardware runs at.
    public static let nativeSampleRate = 3_579_545.0 / 72.0

    // MARK: - Tables

    /// Attenuation of a quarter sine wave, in 1/256 log2 units.
    private static let logSin: [UInt16] = (0..<256).map { index in
        let value = sin((Double(index) + 0.5) * Double.pi / 512.0)
        return UInt16(max(0, min(4095, (-log2(value) * 256.0).rounded())))
    }

    /// Linear amplitude for a fractional attenuation, offset by 1024.
    private static let exponential: [UInt16] = (0..<256).map { index in
        UInt16(((pow(2.0, Double(index) / 256.0) - 1.0) * 1024.0).rounded())
    }

    /// Envelope step pattern. The chip advances an envelope on some cycles
    /// only, which is what gives each rate its slope.
    private static let envelopeIncrement: [[Int]] = [
        [0, 1, 0, 1, 0, 1, 0, 1],
        [0, 1, 0, 1, 1, 1, 0, 1],
        [0, 1, 1, 1, 0, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 1, 1],
    ]

    /// Key scale level attenuation per octave, in 1.5 dB units.
    private static let keyScaleLevel: [Int] = [
        0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64,
    ]

    private static let keyScaleShift: [Int] = [8, 1, 2, 0]

    // MARK: - Operator

    private enum Phase: Sendable {
        case attack
        case decay
        case sustain
        case release
        case off
    }

    private struct Operator: Sendable {
        var multiple = 1
        var keyScaleRate = false
        var sustains = false
        var vibrato = false
        var tremolo = false
        var keyScaleLevelShift = 0
        var totalLevel = 0
        var attackRate = 0
        var decayRate = 0
        var sustainLevel = 0
        var releaseRate = 0
        var waveform = 0

        var phase: UInt32 = 0
        var envelope = 511
        var state = Phase.off
        var output = 0
        var previousOutput = 0
    }

    private struct Channel: Sendable {
        var modulator = Operator()
        var carrier = Operator()
        var frequencyNumber = 0
        var block = 0
        var feedback = 0
        var isAdditive = false
        var keyOn = false
    }

    // MARK: - State

    private var channels = [Channel](repeating: Channel(), count: 9)
    private var registers = [UInt8](repeating: 0, count: 256)
    private var envelopeCounter: UInt32 = 0
    /// Multiplier applied to the chip's 1 MULT step.
    private static let multipliers = [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30]

    public init() {}

    // MARK: - Register access

    /// Operator index for a register offset, or nil when the offset is unused.
    private static func operatorSlot(_ offset: Int) -> (channel: Int, isCarrier: Bool)? {
        let group = offset / 8
        let index = offset % 8
        guard group < 3, index < 6 else { return nil }
        let channel = group * 3 + (index % 3)
        return (channel, index >= 3)
    }

    public mutating func write(register: UInt8, value: UInt8) {
        registers[Int(register)] = value
        let address = Int(register)
        let low = address & 0x0F

        // Operator registers cover 22 slots, so each block spans two high
        // nibbles. Matching on the high nibble alone drops channels 6 to 8.
        let operatorGroup: Int?
        switch address {
        case 0x20...0x35: operatorGroup = 0x20
        case 0x40...0x55: operatorGroup = 0x40
        case 0x60...0x75: operatorGroup = 0x60
        case 0x80...0x95: operatorGroup = 0x80
        case 0xE0...0xF5: operatorGroup = 0xE0
        default: operatorGroup = nil
        }
        if let operatorGroup {
            guard let slot = Self.operatorSlot(address & 0x1F) else { return }
            update(
                high: operatorGroup, value: value, channel: slot.channel,
                isCarrier: slot.isCarrier)
            return
        }

        switch address & 0xF0 {
        case 0xA0:
            guard low < 9 else { return }
            channels[low].frequencyNumber =
                (channels[low].frequencyNumber & 0x300) | Int(value)
        case 0xB0:
            guard low < 9 else { return }
            channels[low].frequencyNumber =
                (channels[low].frequencyNumber & 0xFF) | ((Int(value) & 0x03) << 8)
            channels[low].block = (Int(value) >> 2) & 0x07
            let keyOn = value & 0x20 != 0
            if keyOn != channels[low].keyOn {
                channels[low].keyOn = keyOn
                setKey(on: keyOn, channel: low)
            }
        case 0xC0:
            guard low < 9 else { return }
            channels[low].feedback = (Int(value) >> 1) & 0x07
            channels[low].isAdditive = value & 0x01 != 0
        default:
            break
        }
    }

    private mutating func update(high: Int, value: UInt8, channel: Int, isCarrier: Bool) {
        var op = isCarrier ? channels[channel].carrier : channels[channel].modulator
        switch high {
        case 0x20:
            op.multiple = Self.multipliers[Int(value) & 0x0F]
            op.keyScaleRate = value & 0x10 != 0
            op.sustains = value & 0x20 != 0
            op.vibrato = value & 0x40 != 0
            op.tremolo = value & 0x80 != 0
        case 0x40:
            op.keyScaleLevelShift = Self.keyScaleShift[Int(value) >> 6]
            op.totalLevel = Int(value) & 0x3F
        case 0x60:
            op.attackRate = Int(value) >> 4
            op.decayRate = Int(value) & 0x0F
        case 0x80:
            op.sustainLevel = Int(value) >> 4
            op.releaseRate = Int(value) & 0x0F
        case 0xE0:
            op.waveform = Int(value) & 0x03
        default:
            break
        }
        if isCarrier { channels[channel].carrier = op } else { channels[channel].modulator = op }
    }

    private mutating func setKey(on: Bool, channel: Int) {
        if on {
            channels[channel].modulator.state = .attack
            channels[channel].modulator.phase = 0
            channels[channel].carrier.state = .attack
            channels[channel].carrier.phase = 0
        } else {
            channels[channel].modulator.state = .release
            channels[channel].carrier.state = .release
        }
    }

    // MARK: - Synthesis

    /// Rate index for an envelope stage, including key scaling.
    private func effectiveRate(_ rate: Int, op: Operator, channel: Channel) -> Int {
        guard rate > 0 else { return 0 }
        let keyScaleNumber = (channel.block << 1)
            | ((channel.frequencyNumber >> 9) & 1)
        let scaled = op.keyScaleRate ? keyScaleNumber : keyScaleNumber >> 2
        return min(63, rate * 4 + scaled)
    }

    private mutating func advanceEnvelope(
        _ op: inout Operator, channel: Channel
    ) {
        let rate: Int
        switch op.state {
        case .attack: rate = effectiveRate(op.attackRate, op: op, channel: channel)
        case .decay: rate = effectiveRate(op.decayRate, op: op, channel: channel)
        case .release: rate = effectiveRate(op.releaseRate, op: op, channel: channel)
        case .sustain, .off: rate = 0
        }
        guard rate > 0 else { return }

        let high = rate >> 2
        let low = rate & 3
        let shift = high < 12 ? 12 - high : 0
        let mask: UInt32 = shift > 0 ? (1 << UInt32(shift)) - 1 : 0
        guard envelopeCounter & mask == 0 else { return }
        let index = Int((envelopeCounter >> UInt32(shift)) & 7)
        var step = Self.envelopeIncrement[low][index]
        if high >= 12 { step <<= min(3, high - 11) }
        guard step > 0 else { return }

        switch op.state {
        case .attack:
            // The chip approaches full level exponentially.
            op.envelope += ((~op.envelope) * step) >> 3
            if op.envelope <= 0 {
                op.envelope = 0
                op.state = .decay
            }
        case .decay:
            op.envelope += step
            if op.envelope >= op.sustainLevel * 16 {
                op.envelope = op.sustainLevel * 16
                op.state = .sustain
            }
        case .release:
            op.envelope += step
            if op.envelope >= 511 {
                op.envelope = 511
                op.state = .off
            }
        case .sustain:
            // A voice without the sustain bit keeps decaying.
            if !op.sustains {
                op.envelope = min(511, op.envelope + step)
            }
        case .off:
            break
        }
    }

    /// Converts a phase and an attenuation into a signed sample.
    private static func sample(phase: UInt32, attenuation: Int, waveform: Int) -> Int {
        let position = Int(phase >> 10) & 0x3FF
        let quadrant = position >> 8
        let index = position & 0xFF
        var negative = false
        var logarithm: Int

        switch waveform {
        case 0:
            negative = quadrant >= 2
            logarithm = Int(logSin[quadrant & 1 == 1 ? 255 - index : index])
        case 1:
            // The negative half is muted.
            if quadrant >= 2 { return 0 }
            logarithm = Int(logSin[quadrant == 1 ? 255 - index : index])
        case 2:
            // Both halves are positive.
            logarithm = Int(logSin[quadrant & 1 == 1 ? 255 - index : index])
        default:
            // Only the rising quarter of each half sounds.
            if quadrant & 1 == 1 { return 0 }
            logarithm = Int(logSin[index])
        }

        let total = logarithm + attenuation * 16
        guard total < 4096 else { return 0 }
        let shift = total >> 8
        let value = (Int(exponential[255 - (total & 0xFF)]) + 1024) >> shift
        return negative ? -value : value
    }

    private func phaseStep(_ op: Operator, channel: Channel) -> UInt32 {
        // The frequency number is scaled by the block, then by the multiplier.
        let base = channel.frequencyNumber << channel.block
        return UInt32((base * op.multiple) >> 1)
    }

    private func totalAttenuation(_ op: Operator, channel: Channel) -> Int {
        var level = op.envelope + op.totalLevel * 4
        if op.keyScaleLevelShift > 0 {
            let octave = channel.block
            let scaled = Self.keyScaleLevel[(channel.frequencyNumber >> 6) & 0x0F]
                - 16 * (7 - octave)
            if scaled > 0 { level += scaled >> op.keyScaleLevelShift }
        }
        return min(511, max(0, level))
    }

    /// Produces the next sample, in the range -1 to 1.
    public mutating func nextSample() -> Float {
        envelopeCounter &+= 1
        var mix = 0

        for index in channels.indices {
            var channel = channels[index]
            guard
                channel.modulator.state != .off || channel.carrier.state != .off
            else {
                channels[index] = channel
                continue
            }

            advanceEnvelope(&channel.modulator, channel: channel)
            advanceEnvelope(&channel.carrier, channel: channel)

            channel.modulator.phase &+= phaseStep(channel.modulator, channel: channel)
            channel.carrier.phase &+= phaseStep(channel.carrier, channel: channel)

            // Feedback averages the modulator's last two outputs.
            var modulation: UInt32 = 0
            if channel.feedback > 0 {
                let averaged = (channel.modulator.output + channel.modulator.previousOutput) / 2
                modulation = UInt32(bitPattern: Int32(averaged << channel.feedback)) &<< 6
            }
            let modulatorSample = Self.sample(
                phase: channel.modulator.phase &+ modulation,
                attenuation: totalAttenuation(channel.modulator, channel: channel),
                waveform: channel.modulator.waveform)
            channel.modulator.previousOutput = channel.modulator.output
            channel.modulator.output = modulatorSample

            let carrierAttenuation = totalAttenuation(channel.carrier, channel: channel)
            if channel.isAdditive {
                let carrierSample = Self.sample(
                    phase: channel.carrier.phase,
                    attenuation: carrierAttenuation,
                    waveform: channel.carrier.waveform)
                mix += modulatorSample + carrierSample
            } else {
                let carrierSample = Self.sample(
                    phase: channel.carrier.phase
                        &+ UInt32(bitPattern: Int32(modulatorSample)) &<< 6,
                    attenuation: carrierAttenuation,
                    waveform: channel.carrier.waveform)
                mix += carrierSample
            }
            channels[index] = channel
        }

        // Nine channels of roughly 4096 peak each.
        return max(-1, min(1, Float(mix) / 16_384.0))
    }

    /// Fills a buffer at the chip's native rate.
    public mutating func render(into buffer: inout [Float]) {
        for index in buffer.indices { buffer[index] = nextSample() }
    }

    /// True while any operator is still sounding.
    public var isSilent: Bool {
        channels.allSatisfy { $0.modulator.state == .off && $0.carrier.state == .off }
    }

    /// Loads a 10-byte Ad-Lib patch into a channel, as the driver files store it.
    public mutating func loadPatch(_ patch: [UInt8], channel: Int) {
        guard patch.count >= 10, channel < 9 else { return }
        // Operator slots are grouped in threes with a gap: channels 0-2 use
        // 0x00-0x02, channels 3-5 use 0x08-0x0A, channels 6-8 use 0x10-0x12.
        // The carrier always sits three slots above the modulator.
        let bases: [UInt8] = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12]
        let slot = bases[channel]
        write(register: 0x20 &+ slot, value: patch[0])
        write(register: 0x23 &+ slot, value: patch[1])
        write(register: 0x40 &+ slot, value: patch[2])
        write(register: 0x43 &+ slot, value: patch[3])
        write(register: 0x60 &+ slot, value: patch[4])
        write(register: 0x63 &+ slot, value: patch[5])
        write(register: 0x80 &+ slot, value: patch[6])
        write(register: 0x83 &+ slot, value: patch[7])
        write(register: 0xE0 &+ slot, value: patch[8])
        write(register: 0xE3 &+ slot, value: patch[9])
    }
}
