import Foundation
import NxlvKit

// Availability has to be measured, not declared. A profile that quietly
// borrowed another machine's audio would be worse than one that says what it
// still needs.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let levels = root.appendingPathComponent("Content/lemming1.pc")
let modules = root.appendingPathComponent("Sources/Music")
let macImage = root
    .appendingPathComponent("Sources/Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk")

do {
    try require(PlatformProfile.all.count >= 4, "expected at least four profiles")

    // Identifiers must be unique, since they key a stored preference.
    let identifiers = Set(PlatformProfile.all.map(\.identifier))
    try require(
        identifiers.count == PlatformProfile.all.count,
        "two profiles share an identifier")
    print("PASS \(PlatformProfile.all.count) profiles, all uniquely identified")

    // The Amiga profile must reduce colour depth. That is the whole point.
    try require(
        PlatformProfile.amiga.colorLevels == 16,
        "the Amiga profile does not use four bits per channel")
    try require(
        PlatformProfile.dosVGA.pixelAspect > 1.0,
        "DOS pixels at 320 by 200 on a 4:3 screen are not square")
    try require(
        PlatformProfile.modern.colorLevels == 0,
        "the modern profile should not reduce colour")
    print("PASS each profile describes its own machine")

    print("")
    print("  profile      levels  music   sound   complete  missing")
    var anyComplete = false
    for profile in PlatformProfile.all {
        let state = PlatformLibrary.availability(
            profile: profile,
            levelDirectory: levels,
            moduleDirectory: modules,
            macImage: macImage)
        if state.isComplete { anyComplete = true }
        func mark(_ value: Bool) -> String { value ? "yes" : "-" }
        func pad(_ text: String, _ width: Int) -> String {
            text.count >= width
                ? text : text + String(repeating: " ", count: width - text.count)
        }
        print(
            "  " + pad(profile.identifier, 13)
                + pad(mark(state.hasLevels), 8)
                + pad(mark(state.hasMusic), 8)
                + pad(mark(state.hasSound), 8)
                + pad(mark(state.isComplete), 10)
                + state.missing.joined(separator: ", "))
    }

    // The Ad-Lib sequencer is still undecoded, so DOS audio must report as
    // unavailable rather than claiming to work.
    let dos = PlatformLibrary.availability(
        profile: .dosVGA, levelDirectory: levels, moduleDirectory: modules, macImage: macImage)
    try require(!dos.hasMusic, "DOS music reported as available while the sequencer is undecoded")
    try require(!dos.hasSound, "DOS sound reported as available while the sequencer is undecoded")
    print("")
    print("PASS undecoded formats report as unavailable rather than claiming to work")
    try require(anyComplete, "no profile can be delivered from the data present")
    print("PASS at least one profile is fully deliverable")
    print("Platform profile tests passed.")
} catch {
    FileHandle.standardError.write(Data("Platform profile tests failed: \(error)\n".utf8))
    exit(1)
}
