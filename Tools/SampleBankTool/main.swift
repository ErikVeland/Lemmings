import Foundation
import NxlvKit

// Reports a sound effect bank and writes it out as audio.
//
// The stored sample rate is not recorded anywhere in the files, so it is a
// parameter. Everything is written as one file with gaps, which makes the
// effects easy to identify by ear in a single pass.

private let arguments = CommandLine.arguments
private func value(_ flag: String, _ fallback: String) -> String {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
        return fallback
    }
    return arguments[index + 1]
}

private func writeWAV(samples: [Float], sampleRate: Double, to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ item: T) {
        withUnsafeBytes(of: item.littleEndian) { data.append(contentsOf: $0) }
    }
    let byteCount = samples.count * 2
    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + byteCount))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(UInt32(sampleRate))
    append(UInt32(sampleRate * 2))
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(UInt32(byteCount))
    for sample in samples { append(Int16(max(-1, min(1, sample)) * 32000)) }
    try data.write(to: url)
}

let indexPath = value("--index", "Sources/Ports/LEM3CD/AUDIO/SFX001.IND")
let rawPath = value("--raw", "Sources/Ports/LEM3CD/AUDIO/SFX001.RAW")
let rate = Double(value("--rate", "11025"))!
let output = value("--out", "sfx.wav")

do {
    let bank = try ClassicSampleBank.load(
        indexURL: URL(fileURLWithPath: indexPath),
        rawURL: URL(fileURLWithPath: rawPath))

    print("bank: \(bank.samples.count) effects, \(bank.missingBytes) bytes short of the index")
    print("assuming \(Int(rate)) Hz")
    print("")
    print("  #   frames    seconds   peak   note")

    var combined: [Float] = []
    let gap = [Float](repeating: 0, count: Int(rate * 0.35))
    for sample in bank.samples {
        let seconds = Double(sample.frameCount) / rate
        var note = ""
        if sample.frameCount == 0 { note = "empty" }
        else if sample.peak < 0.02 { note = "near silent" }
        if sample.wasTruncated { note += note.isEmpty ? "truncated" : ", truncated" }
        print(String(
            format: "  %2d  %7d   %6.2f   %.3f  %@",
            sample.index, sample.frameCount, seconds, sample.peak,
            note.isEmpty ? "-" : note))

        combined += sample.floatSamples()
        combined += gap
    }

    try writeWAV(samples: combined, sampleRate: rate, to: URL(fileURLWithPath: output))
    let total = Double(combined.count) / rate
    print("")
    print(String(format: "wrote %@ — %.1f seconds, all effects in order with gaps", output, total))
} catch {
    FileHandle.standardError.write(Data("sample bank failed: \(error)\n".utf8))
    exit(1)
}
