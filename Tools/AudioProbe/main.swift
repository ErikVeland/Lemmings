import Foundation
import NxlvKit

// Reports the structure of the DOS Lemmings Ad-Lib driver.
//
// ADLIB.DAT is not a data file. It is a standalone Ad-Lib driver program by
// Sound Images, with an embedded test menu, an OPL2 channel register table, a
// logarithmic volume table, FM instrument patches, and the tune data. This
// tool locates those parts so the audio work has a factual starting point.

private let instrumentMarker = Data([0x7f, 0x00, 0x00, 0x00, 0x00, 0x00])

private func printableRuns(_ data: Data, minimum: Int) -> [(offset: Int, text: String)] {
    var runs: [(Int, String)] = []
    var current = ""
    var start = 0
    for (index, byte) in data.enumerated() {
        if byte >= 0x20, byte < 0x7f {
            if current.isEmpty { start = index }
            current.append(Character(UnicodeScalar(byte)))
        } else {
            if current.count >= minimum { runs.append((start, current)) }
            current = ""
        }
    }
    if current.count >= minimum { runs.append((start, current)) }
    return runs
}

/// One Ad-Lib FM patch: modulator and carrier operator settings.
private struct Instrument {
    let offset: Int
    let bytes: [UInt8]

    var description: String {
        let hex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        return String(format: "0x%05x  %@", offset, hex)
    }

    /// A patch of all zeroes is padding, not a voice.
    var isPadding: Bool { bytes.allSatisfy { $0 == 0 } }
}

private func analyze(name: String, data: Data) {
    print("=== \(name): \(data.count) bytes decompressed ===")

    let strings = printableRuns(data, minimum: 6)
    if let banner = strings.first(where: { $0.text.contains("Driver") }) {
        print("  banner at 0x\(String(banner.offset, radix: 16)): \(banner.text.trimmingCharacters(in: .whitespaces))")
    }

    // The test menu names every tune, in driver order.
    let tuneLines = strings.filter { $0.text.contains(" - ") && $0.text.count < 60 }
    var tunes: [String] = []
    for line in tuneLines {
        for part in line.text.components(separatedBy: "\t") {
            var trimmed = part.trimmingCharacters(in: .whitespaces)
            // The first menu line carries a "Press" prefix and a leading dash.
            if trimmed.hasPrefix("Press") { trimmed.removeFirst("Press".count) }
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") { trimmed.removeFirst(2) }
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)
            guard let range = trimmed.range(of: " - ") else { continue }
            let key = String(trimmed[trimmed.startIndex..<range.lowerBound])
            let title = String(trimmed[range.upperBound...])
            guard key.count == 1, !title.isEmpty else { continue }
            tunes.append("\(key)=\(title)")
        }
    }
    if !tunes.isEmpty {
        print("  \(tunes.count) tunes named by the driver menu:")
        for chunk in stride(from: 0, to: tunes.count, by: 5) {
            let slice = tunes[chunk..<min(chunk + 5, tunes.count)]
            print("    " + slice.joined(separator: "  "))
        }
    }

    // FM patches sit immediately before each 7f 00 00 00 00 00 marker.
    var instruments: [Instrument] = []
    var searchStart = data.startIndex
    while let found = data.range(of: instrumentMarker, in: searchStart..<data.endIndex) {
        let patchStart = found.lowerBound - 10
        if patchStart >= data.startIndex {
            instruments.append(
                Instrument(offset: patchStart - data.startIndex, bytes: [UInt8](data[patchStart..<found.lowerBound])))
        }
        searchStart = found.lowerBound + 1
    }
    let voices = instruments.filter { !$0.isPadding }
    print("  \(instruments.count) patch slots, \(voices.count) with data")
    for instrument in voices.prefix(6) { print("    \(instrument.description)") }
    if voices.count > 6 { print("    …") }

    if let first = voices.first, let last = voices.last {
        print(
            "  patch region spans 0x\(String(first.offset, radix: 16))"
                + "..0x\(String(last.offset + 16, radix: 16))")
    }
}

let directory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

for name in ["adlib.dat", "tandysnd.dat"] {
    let url = directory.appendingPathComponent(name)
    guard let raw = try? Data(contentsOf: url) else {
        print("\(name): not found")
        continue
    }
    do {
        let sections = try ClassicDATArchive.decode(raw)
        guard let section = sections.first else {
            print("\(name): no sections")
            continue
        }
        analyze(name: name, data: section.data)
    } catch {
        print("\(name): could not decode: \(error)")
    }
    print("")
}
