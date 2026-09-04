import Foundation
import NxlvKit

// Reads sounds from a Mac disk image. The Mac release names each sound and
// records its own rate, so this checks that both survive the whole path from
// disk image to samples.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("pass the path to a Mac disk image\n".utf8))
    exit(2)
}

do {
    let image = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
    let volume = try ClassicHFSVolume(image: image)
    print("PASS volume '\(volume.volumeName)' with \(volume.files.count) files")

    try require(
        volume.files.contains { $0.name == "Lemmings" && $0.type == "APPL" },
        "the application was not found in the catalog")

    let fork = try volume.resourceFork(named: "Lemmings")
    try require(fork.count > 100_000, "the resource fork is only \(fork.count) bytes")
    print("PASS resource fork read — \(fork.count) bytes")

    let sounds = ClassicMacSoundDecoder.sounds(in: fork)
    try require(sounds.count >= 20, "only \(sounds.count) sounds decoded")

    // The names are the mapping, so the important ones must be present.
    let byName = Dictionary(
        uniqueKeysWithValues: sounds.compactMap { sound in
            sound.name.map { ($0, sound) }
        })
    for wanted in ["OhNo", "LetsGo", "Explode", "Splat", "Door", "MousePress"] {
        try require(byName[wanted] != nil, "the sound named \(wanted) is missing")
    }
    print("PASS \(sounds.count) sounds decoded, all the key names present")

    // Every sound must carry a usable rate and real samples.
    for sound in sounds {
        try require(
            sound.sampleRate > 1000 && sound.sampleRate < 48_000,
            "\(sound.name ?? "\(sound.id)") reports \(sound.sampleRate) Hz")
        try require(!sound.pcm.isEmpty, "\(sound.name ?? "\(sound.id)") has no samples")
    }
    let rates = Set(sounds.map { Int($0.sampleRate) })
    try require(
        rates.count > 1,
        "every sound reported the same rate, so the rate is probably not being read")
    print("PASS every sound has samples and its own rate — \(rates.count) distinct rates")

    if let ohNo = byName["OhNo"] {
        print(String(
            format: "     OhNo: %.0f Hz, %d frames, %.2f seconds",
            ohNo.sampleRate, ohNo.pcm.count, ohNo.duration))
    }
    // Decoding a sound is not the same as an event having one bound to it.
    // This checks the mapping the game actually plays through.
    var bound: [ClassicSoundEffect] = []
    var unbound: [ClassicSoundEffect] = []
    for effect in ClassicSoundEffect.allCases {
        if let name = ClassicSoundMapping.macintoshNames[effect], byName[name] != nil {
            bound.append(effect)
        } else {
            unbound.append(effect)
        }
    }
    print("PASS \(bound.count) of \(ClassicSoundEffect.allCases.count) game events have a sound")
    if !unbound.isEmpty {
        print("     unbound: \(unbound.map(\.rawValue).joined(separator: ", "))")
    }
    try require(
        unbound.isEmpty,
        "these events would be silent: \(unbound.map(\.rawValue).joined(separator: ", "))")

    print("Classic Mac sound tests passed.")
} catch {
    FileHandle.standardError.write(Data("Mac sound tests failed: \(error)\n".utf8))
    exit(1)
}
