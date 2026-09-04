import Foundation
import NxlvKit

// The Macintosh release carries its own front-end artwork: two character sets,
// the title logo and the publisher screen. The menus draw from these, so the
// test checks that every release provides them and that the character sets
// cover the text a menu writes.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

/// Lines the front end actually draws. A character missing from the set would
/// leave a hole in one of these.
private let menuText = [
    "FULL QUEST", "LEMMINGS", "OH NO! MORE LEMMINGS", "XMAS LEMMINGS 1991",
    "HOLIDAY LEMMINGS 1994", "LEMMINGS 2: THE TRIBES",
    "UP AND DOWN TO CHOOSE * ENTER TO BEGIN * Q TO QUIT",
    "0/502  (100%)", "Just dig!", "Release rate 50", "Time 5:00",
]

private func testFontsAndPictures(_ name: String, _ directory: URL) throws {
    let artwork = try ClassicMacArtwork(directory: directory)
    guard let interface = ClassicMacUserInterface(artwork: artwork) else {
        throw Failure(description: "\(name) carries no character set")
    }

    for face in ClassicMacUserInterface.Face.allCases {
        guard let font = interface.font(face) else {
            throw Failure(description: "\(name) is missing \(face.rawValue)")
        }
        try require(
            font.cellWidth > 0 && font.cellHeight > 0,
            "\(name) \(face.rawValue) has an empty cell")

        // Space is the only blank glyph. Anything else missing is a hole.
        let blanks = font.glyphs.enumerated().filter { $0.element == nil }
        try require(
            blanks.count == 1 && blanks[0].offset == 0,
            "\(name) \(face.rawValue) has \(blanks.count) blank glyphs, expected only space")

        for line in menuText {
            try require(
                font.covers(line),
                "\(name) \(face.rawValue) cannot draw \"\(line)\"")
        }

        // Monospaced, so a line is exactly its length in cells.
        try require(
            font.width(of: "ABC", scale: 2) == 6 * font.cellWidth,
            "\(name) \(face.rawValue) is not monospaced at scale")
    }

    try require(interface.logo != nil, "\(name) is missing its title logo")
    try require(interface.publisher != nil, "\(name) is missing its publisher screen")
    try require(!interface.icons.isEmpty, "\(name) is missing its status bar icons")

    let small = interface.font(.small)!
    let large = interface.font(.large)!
    try require(
        large.cellWidth > small.cellWidth,
        "\(name) large face is not larger than the small one")

    let logo = interface.logo!
    print("""
      PASS \(name): \(small.cellWidth)x\(small.cellHeight) and \
    \(large.cellWidth)x\(large.cellHeight) cells, logo \(logo.width)x\(logo.height), \
    \(interface.icons.count) icons
    """)
}

let arguments = CommandLine.arguments
let root = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : ".build/mac-artwork/export")
guard let families = try? FileManager.default.contentsOfDirectory(
    at: root, includingPropertiesForKeys: nil), !families.isEmpty
else {
    print("No exported Macintosh artwork found. Run the Mac artwork tests first.")
    exit(0)
}

do {
    var checked = 0
    for family in families.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        guard FileManager.default.fileExists(
            atPath: family.appendingPathComponent("manifest.json").path) else { continue }
        try testFontsAndPictures(family.lastPathComponent, family)
        checked += 1
    }
    try require(checked > 0, "no release carried front-end artwork")
    print("Classic Mac interface tests passed.")
} catch {
    FileHandle.standardError.write(Data("Classic Mac interface tests failed: \(error)\n".utf8))
    exit(1)
}
