import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible { let description: String }
private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private let bankDirectory = URL(fileURLWithPath: "Sources/Ports/amiga_extracted/lemmings")

private func bank(_ name: String) throws -> [AmigaSound] {
    try AmigaSoundBank.decode(Data(contentsOf: bankDirectory.appendingPathComponent(name)))
}

private func testBanksDecode() throws {
    let basic = try bank("basicfx")
    let full = try bank("fullfx")
    try require(basic.count == 11, "basicfx held \(basic.count) sounds, expected 11")
    try require(full.count == 10, "fullfx held \(full.count) sounds, expected 10")

    for sound in basic + full {
        try require(!sound.samples.isEmpty, "\(sound.name ?? "unnamed") decoded to no samples")
        try require(
            sound.sampleRate >= 1000 && sound.sampleRate <= 48000,
            "\(sound.name ?? "unnamed") reported \(sound.sampleRate) Hz")
        // Eight bit signed samples cannot leave this range once scaled.
        try require(
            sound.samples.allSatisfy { $0 >= -1 && $0 < 1 },
            "\(sound.name ?? "unnamed") produced a sample outside -1 to 1")
    }
    print("PASS both Amiga banks decode to 21 sounds with sane rates and levels")
}

private func testTheNamedSoundsAreTheOnesTheGameAsksFor() throws {
    let names = Set((try bank("basicfx") + (try bank("fullfx")))
        .compactMap { $0.name?.lowercased() })

    // Every name the cue table binds has to exist in a bank, or the effect
    // would silently never play.
    for (effect, name) in ClassicSoundMapping.amigaVoiceNames {
        try require(
            names.contains(name.lowercased()),
            "\(effect) is bound to \"\(name)\", which is in neither bank")
    }
    // The banks really do carry the recognisable ones.
    for expected in ["letsgo", "ohno1", "splat", "changeopt2", "door2", "water1"] {
        try require(names.contains(expected), "the banks are missing \(expected)")
    }
    print("PASS every bound name exists in a bank, including the voices")
}

private func testUnboundEffectsAreDeclared() throws {
    // These have no named sample, so they must be listed rather than guessed.
    let unbound = Set(ClassicSoundMapping.amigaUnboundEffects)
    try require(
        unbound.contains(.explode) && unbound.contains(.nuke) && unbound.contains(.yippee),
        "an effect with no Amiga name is missing from the unbound list")
    for effect in unbound {
        try require(
            ClassicSoundMapping.amigaVoiceNames[effect] == nil,
            "\(effect) is both bound and listed as unbound")
    }
    print("PASS effects with no named sample are declared rather than guessed")
}

private func testRubbishIsReported() throws {
    do {
        _ = try AmigaSoundBank.decode(Data([0, 1, 2, 3, 4, 5, 6, 7, 8]))
        throw Failure(description: "a file that is not IFF was accepted")
    } catch let error as AmigaSoundBankError {
        try require(error == .notIFF(offset: 0), "wrong error: \(error)")
    }
    print("PASS a file that is not a sound bank is reported rather than decoded")
}

do {
    try testBanksDecode()
    try testTheNamedSoundsAreTheOnesTheGameAsksFor()
    try testUnboundEffectsAreDeclared()
    try testRubbishIsReported()
    print("Amiga sound tests passed.")
} catch {
    FileHandle.standardError.write(Data("Amiga sound tests failed: \(error)\n".utf8))
    exit(1)
}
