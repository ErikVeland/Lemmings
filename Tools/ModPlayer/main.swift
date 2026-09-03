import Foundation
import NxlvKit

// Parses real ProTracker modules and can render one to WAV.
// The unit tests use a module built by hand. This checks the parser against
// files it did not create.

private func writeStereoWAV(
    left: [Float], right: [Float], sampleRate: Double, to url: URL
) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let frames = min(left.count, right.count)
    let byteCount = frames * 4
    data.append(contentsOf: Array("RIFF".utf8))
    append(UInt32(36 + byteCount))
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(2))
    append(UInt32(sampleRate))
    append(UInt32(sampleRate * 4))
    append(UInt16(4))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(UInt32(byteCount))
    for index in 0..<frames {
        append(Int16(max(-1, min(1, left[index])) * 32000))
        append(Int16(max(-1, min(1, right[index])) * 32000))
    }
    try data.write(to: url)
}

private func modules(under root: URL) -> [URL] {
    guard let walker = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: nil) else { return [] }
    return walker.compactMap { $0 as? URL }
        .filter { $0.pathExtension.lowercased() == "mod" }
        .sorted { $0.path < $1.path }
}

let arguments = CommandLine.arguments
func flag(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}

let root = URL(fileURLWithPath: flag("--dir") ?? "Sources/Music", isDirectory: true)
let renderTarget = flag("--render")
let outputPath = flag("--out") ?? "module.wav"
let seconds = Double(flag("--seconds") ?? "25") ?? 25

let files = modules(under: root)
guard !files.isEmpty else {
    FileHandle.standardError.write(Data("No .mod files under \(root.path)\n".utf8))
    exit(1)
}

var parsed = 0
var failed: [(String, String)] = []
var channelCounts: [Int: Int] = [:]
var effectUse: [Int: Int] = [:]
var extendedUse: [Int: Int] = [:]

for file in files {
    do {
        let module = try ProTrackerModule(data: try Data(contentsOf: file))
        parsed += 1
        channelCounts[module.channelCount, default: 0] += 1
        for pattern in module.patterns {
            for row in pattern {
                for note in row where !(note.effect == 0 && note.parameter == 0) {
                    effectUse[note.effect, default: 0] += 1
                    if note.effect == 0x0E { extendedUse[note.parameter >> 4, default: 0] += 1 }
                }
            }
        }
        let voices = module.samples.filter { !$0.data.isEmpty }.count
        let pcm = module.samples.reduce(0) { $0 + $1.data.count }
        print(String(
            format: "  %-26s %-22s %dch  %2d pat  %3d ord  %2d smp  %6d PCM",
            (file.deletingPathExtension().lastPathComponent as NSString).utf8String!,
            (module.title as NSString).utf8String!,
            module.channelCount, module.patterns.count, module.songLength, voices, pcm))
    } catch {
        failed.append((file.lastPathComponent, "\(error)"))
    }
}

print("")
print("parsed \(parsed)/\(files.count) modules")
for (channels, count) in channelCounts.sorted(by: { $0.key < $1.key }) {
    print("  \(channels) channels: \(count) module(s)")
}
let effectNames = [
    0x0: "arpeggio", 0x1: "porta up", 0x2: "porta down", 0x3: "tone porta",
    0x4: "vibrato", 0x5: "tone porta + vol slide", 0x6: "vibrato + vol slide",
    0x7: "tremolo", 0x8: "panning", 0x9: "sample offset", 0xA: "volume slide",
    0xB: "position jump", 0xC: "set volume", 0xD: "pattern break",
    0xE: "extended", 0xF: "set speed/tempo",
]
let implemented: Set<Int> = [0xB, 0xC, 0xD, 0xF]
print("")
print("effect use across the corpus:")
for (effect, count) in effectUse.sorted(by: { $0.value > $1.value }) {
    let mark = implemented.contains(effect) ? "done" : "TODO"
    print(String(
        format: "  %-4s %X  %-24s %6d",
        (mark as NSString).utf8String!, effect,
        ((effectNames[effect] ?? "?") as NSString).utf8String!, count))
}
if !extendedUse.isEmpty {
    print("  extended (E) subcommands:")
    for (sub, count) in extendedUse.sorted(by: { $0.value > $1.value }) {
        print(String(format: "    E%X: %d", sub, count))
    }
}

if !failed.isEmpty {
    print("  failures:")
    for (name, reason) in failed { print("    \(name): \(reason)") }
}

if let renderTarget {
    let match = files.first {
        $0.deletingPathExtension().lastPathComponent.lowercased() == renderTarget.lowercased()
    }
    guard let match else {
        FileHandle.standardError.write(Data("No module named '\(renderTarget)'\n".utf8))
        exit(1)
    }
    let module = try ProTrackerModule(data: try Data(contentsOf: match))
    let presetName = flag("--preset") ?? "faithful"
    let enhancements: ProTrackerEnhancements
    switch presetName.lowercased() {
    case "modern": enhancements = .modern
    case "faithful": enhancements = .faithful
    default:
        FileHandle.standardError.write(
            Data("Unknown preset '\(presetName)'. Use faithful or modern.\n".utf8))
        exit(1)
    }

    var player = ProTrackerEnhancedPlayer(
        module: module, sampleRate: 44100, enhancements: enhancements)
    let frames = Int(44100 * seconds)
    var left = [Float](repeating: 0, count: frames)
    var right = [Float](repeating: 0, count: frames)
    player.render(left: &left, right: &right)
    try writeStereoWAV(
        left: left, right: right, sampleRate: 44100, to: URL(fileURLWithPath: outputPath))
    let peak = max(left.map { abs($0) }.max() ?? 0, right.map { abs($0) }.max() ?? 0)
    print(String(
        format: "\nrendered '%@' (%@) as %@ -> %@, %.1fs stereo, peak %.3f",
        match.lastPathComponent, module.title, presetName, outputPath, seconds, peak))
}

exit(failed.isEmpty ? 0 : 1)
