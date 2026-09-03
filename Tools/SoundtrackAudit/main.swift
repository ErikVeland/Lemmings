import Foundation
import NxlvKit

// Inventories every soundtrack source that is present, and cross references
// them by tune name. Deciding which interpretation to ship, or which to offer
// as a choice, needs the coverage laid out rather than assumed.

private struct Source {
    let platform: String
    let format: String
    let status: String
    var tunes: [String: String] = [:]   // normalised name -> detail
}

private func normalise(_ name: String) -> String {
    name.lowercased()
        .replacingOccurrences(of: ".midi", with: "")
        .replacingOccurrences(of: ".mod", with: "")
        .filter { $0.isLetter || $0.isNumber }
}

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private var sources: [Source] = []

// 1. Amiga modules.
let moduleRoot = root.appendingPathComponent("Sources/Music/lemmings_music_mod")
if let files = try? FileManager.default.contentsOfDirectory(
    at: moduleRoot, includingPropertiesForKeys: nil) {
    var source = Source(
        platform: "Amiga", format: "ProTracker module", status: "playable now")
    for url in files where url.pathExtension.lowercased() == "mod" {
        guard let data = try? Data(contentsOf: url),
            let module = try? ProTrackerModule(data: data) else { continue }
        let name = url.deletingPathExtension().lastPathComponent
        source.tunes[normalise(name)] =
            "\(module.channelCount)ch, \(module.patterns.count) patterns, "
            + "\(module.samples.filter { !$0.data.isEmpty }.count) samples"
    }
    if !source.tunes.isEmpty { sources.append(source) }
}

// 2. Macintosh MIDI plus sampled instruments.
let macImage = root.appendingPathComponent("Sources/Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk")
if let image = try? Data(contentsOf: macImage, options: .mappedIfSafe),
    let volume = try? ClassicHFSVolume(image: image),
    let fork = try? volume.resourceFork(named: "Music") {
    var source = Source(
        platform: "Macintosh", format: "MIDI + sampled instruments",
        status: "decoded, needs a sampler")
    for resource in ClassicResourceFork.resources(ofType: "MIDI", in: fork) {
        let name = resource.name ?? "id \(resource.id)"
        source.tunes[normalise(name)] = "\(resource.data.count) bytes of MIDI"
    }
    let instruments = ClassicResourceFork.resources(ofType: "snd ", in: fork).count
    if !source.tunes.isEmpty {
        source.tunes["_instruments"] = "\(instruments) instruments"
        sources.append(source)
    }
}

// 3. DOS Ad-Lib. The driver names its tunes even though the sequencer is not
//    decoded, so coverage is known even while playback is not.
for candidate in ["Content/lemming1.pc", "Sources/Ports/lemmings_dos_1991-07-30"] {
    let url = root.appendingPathComponent(candidate).appendingPathComponent("adlib.dat")
    let upper = root.appendingPathComponent(candidate).appendingPathComponent("ADLIB.DAT")
    let found = FileManager.default.fileExists(atPath: url.path) ? url : upper
    guard let raw = try? Data(contentsOf: found),
        let sections = try? ClassicDATArchive.decode(raw),
        let first = sections.first else { continue }

    var source = Source(
        platform: "DOS", format: "Ad-Lib FM (OPL2)",
        status: "synthesizer built, sequencer undecoded")
    // The test menu lists every tune, one per keyboard letter.
    let text = String(decoding: first.data, as: UTF8.self)
    for line in text.components(separatedBy: CharacterSet(charactersIn: "\r\n")) {
        for part in line.components(separatedBy: "\t") {
            var trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Press") { trimmed.removeFirst(5) }
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") { trimmed.removeFirst(2) }
            guard let range = trimmed.range(of: " - ") else { continue }
            let key = String(trimmed[trimmed.startIndex..<range.lowerBound])
            let title = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            guard key.count == 1, !title.isEmpty, title.count < 20 else { continue }
            source.tunes[normalise(title)] = "key \(key)"
        }
    }
    if !source.tunes.isEmpty { sources.append(source) }
    break
}

// Report.
print("Soundtrack sources present\n")
for source in sources {
    let count = source.tunes.filter { !$0.key.hasPrefix("_") }.count
    print("  \(source.platform)")
    print("    format : \(source.format)")
    print("    status : \(source.status)")
    print("    tunes  : \(count)")
    if let instruments = source.tunes["_instruments"] {
        print("    bank   : \(instruments)")
    }
}

var everyTune = Set<String>()
for source in sources {
    everyTune.formUnion(source.tunes.keys.filter { !$0.hasPrefix("_") })
}

print("\nCoverage by tune\n")
let header = "  " + "tune".padding(toLength: 16, withPad: " ", startingAt: 0)
    + sources.map { $0.platform.padding(toLength: 12, withPad: " ", startingAt: 0) }.joined()
print(header)
for tune in everyTune.sorted() {
    var row = "  " + tune.padding(toLength: 16, withPad: " ", startingAt: 0)
    for source in sources {
        row += (source.tunes[tune] != nil ? "yes" : "-")
            .padding(toLength: 12, withPad: " ", startingAt: 0)
    }
    print(row)
}
print("\n\(everyTune.count) distinct tunes across \(sources.count) sources")
