import Foundation
import NxlvKit

// Checks the Amiga color reduction. Four bits per channel means sixteen
// levels, evenly spread, with black and white preserved exactly.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func testSixteenLevelsPerChannel() throws {
    var seen = Set<UInt8>()
    for value in 0...255 {
        let color = ClassicRGBColor(red: UInt8(value), green: 0, blue: 0)
        seen.insert(color.quantizedToAmigaOCS.red)
    }
    try require(seen.count == 16, "expected 16 levels per channel, found \(seen.count)")
    print("PASS sixteen levels per channel")
}

private func testEndpointsArePreserved() throws {
    let black = ClassicRGBColor(red: 0, green: 0, blue: 0).quantizedToAmigaOCS
    let white = ClassicRGBColor(red: 255, green: 255, blue: 255).quantizedToAmigaOCS
    try require(
        black.red == 0 && black.green == 0 && black.blue == 0,
        "black shifted to \(black.red),\(black.green),\(black.blue)")
    try require(
        white.red == 255 && white.green == 255 && white.blue == 255,
        "white shifted to \(white.red),\(white.green),\(white.blue)")
    print("PASS black and white are unchanged")
}

private func testErrorStaysSmall() throws {
    // No color should move far enough to read as a different shade.
    var worst = 0
    for value in 0...255 {
        let quantized = ClassicRGBColor(red: UInt8(value), green: 0, blue: 0)
            .quantizedToAmigaOCS.red
        worst = max(worst, abs(Int(quantized) - value))
    }
    try require(worst <= 9, "a channel moved by \(worst), which is too far")
    print("PASS the largest channel shift is \(worst)")
}

private func testPaletteHelper() throws {
    let palette = ClassicLemmingPalette.panelVGA
    let reduced = palette.quantizedToAmigaOCS
    try require(reduced.count == palette.count, "the palette changed length")
    for color in reduced {
        try require(
            color.red & 0x0F == color.red >> 4,
            "a channel is not a repeated four bit level")
    }
    print("PASS a whole palette reduces to Amiga depth")
}

do {
    try testSixteenLevelsPerChannel()
    try testEndpointsArePreserved()
    try testErrorStaysSmall()
    try testPaletteHelper()
    print("Amiga palette tests passed.")
} catch {
    FileHandle.standardError.write(Data("Amiga palette tests failed: \(error)\n".utf8))
    exit(1)
}
