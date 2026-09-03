import Foundation
import NxlvKit

// Renders the OPL2 synthesizer to a WAV file so its sound can be checked by
// ear. The tests prove the numbers. This proves the character.

private func writeWAV(samples: [Float], sampleRate: Double, to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let frameCount = samples.count
    let byteCount = frameCount * 2

    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + byteCount))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))  // PCM
    append(UInt16(1))  // mono
    append(UInt32(sampleRate))
    append(UInt32(sampleRate * 2))
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(UInt32(byteCount))
    for sample in samples {
        append(Int16(max(-1, min(1, sample)) * 32000))
    }
    try data.write(to: url)
}

/// A bright FM voice with clear modulator character.
private let voice: [UInt8] = [
    0x01, 0x01,  // multipliers
    0x10, 0x00,  // modulator level, carrier level
    0xF2, 0xF2,  // attack and decay
    0x53, 0x33,  // sustain and release
    0x00, 0x00,  // waveforms
]

private func note(_ semitone: Int) -> (fnum: Int, block: Int) {
    // Equal temperament from A440, converted to the chip's own units.
    let frequency = 440.0 * pow(2.0, Double(semitone - 9) / 12.0)
    var block = 0
    var fnum = 0.0
    while block < 7 {
        fnum = frequency * pow(2.0, Double(20 - block)) / OPL2.nativeSampleRate
        if fnum < 1024 { break }
        block += 1
    }
    return (Int(fnum.rounded()), block)
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "opl2.wav")

var chip = OPL2()
for channel in 0..<3 {
    chip.loadPatch(voice, channel: channel)
    chip.write(register: UInt8(0xC0 + channel), value: 0x06)  // FM with feedback
}

var samples: [Float] = []
let rate = OPL2.nativeSampleRate

// An arpeggio, then a sustained major chord.
let melody = [0, 4, 7, 12, 7, 4]
for (step, semitone) in melody.enumerated() {
    let pitch = note(semitone + 12)
    chip.write(register: 0xA0, value: UInt8(pitch.fnum & 0xFF))
    chip.write(
        register: 0xB0,
        value: UInt8(0x20 | (pitch.block << 2) | ((pitch.fnum >> 8) & 0x03)))
    var block = [Float](repeating: 0, count: Int(rate * 0.18))
    chip.render(into: &block)
    samples += block
    _ = step
}
chip.write(register: 0xB0, value: 0x00)

for (channel, semitone) in [0, 4, 7].enumerated() {
    let pitch = note(semitone + 12)
    chip.write(register: UInt8(0xA0 + channel), value: UInt8(pitch.fnum & 0xFF))
    chip.write(
        register: UInt8(0xB0 + channel),
        value: UInt8(0x20 | (pitch.block << 2) | ((pitch.fnum >> 8) & 0x03)))
}
var chord = [Float](repeating: 0, count: Int(rate * 1.4))
chip.render(into: &chord)
samples += chord

for channel in 0..<3 { chip.write(register: UInt8(0xB0 + channel), value: 0x00) }
var tail = [Float](repeating: 0, count: Int(rate * 0.9))
chip.render(into: &tail)
samples += tail

try writeWAV(samples: samples, sampleRate: rate, to: output)
let peak = samples.map { abs($0) }.max() ?? 0
print(String(
    format: "wrote %@ — %.2fs, %d samples at %.0f Hz, peak %.3f",
    output.lastPathComponent, Double(samples.count) / rate, samples.count, rate, peak))
