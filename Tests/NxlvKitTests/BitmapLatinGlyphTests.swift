import Foundation
@testable import NxlvKit
import XCTest

final class BitmapLatinGlyphTests: XCTestCase {
    private func artwork() throws -> ClassicMacArtwork {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("manifest.json").path) else {
            throw XCTSkip("Decoded Macintosh font banks are required.")
        }
        return try ClassicMacArtwork(directory: folder)
    }

    func testBothFacesPreserveASCIIAndCoverLatinRepertoire() throws {
        let art = try artwork(), ui = try XCTUnwrap(ClassicMacUserInterface(artwork: art))
        for face in ClassicMacUserInterface.Face.allCases {
            let font = try XCTUnwrap(ui.font(face))
            let bank = try XCTUnwrap(art.bank(named: face.rawValue))
            for code in 33...126 {
                let glyph = try XCTUnwrap(font.glyph(for: Character(String(Unicode.Scalar(code)!))))
                let original = try XCTUnwrap(art.frame(bank, code - 32))
                XCTAssertEqual(glyph.rgba, original.rgba)
                XCTAssertEqual([glyph.x, glyph.y, glyph.width, glyph.height], [original.x, original.y, original.width, original.height])
            }
            for character in BitmapLatinGlyphs.characters {
                let glyph = try XCTUnwrap(font.glyph(for: character), "Missing \(character) in \(face)")
                XCTAssertEqual(glyph.rgba.count, glyph.width * glyph.height * 4)
                XCTAssertTrue(stride(from: 3, to: glyph.rgba.count, by: 4).contains { glyph.rgba[$0] != 0 })
                XCTAssertEqual(font.width(of: String(character)), font.cellWidth)
            }
            for (plain, extended): (Character, Character) in [("A", "Å"), ("O", "Ø"), ("D", "Ð"), ("B", "ẞ"), ("A", "Æ")] {
                XCTAssertNotEqual(font.glyph(for: plain)?.rgba, font.glyph(for: extended)?.rgba)
            }
            XCTAssertEqual(font.glyph(for: "Å")?.rgba, font.glyph(for: "A\u{030A}")?.rgba)
            XCTAssertEqual(font.height(of: "ASCII"), font.cellHeight)
            XCTAssertGreaterThan(font.height(of: "ÅȘÇ"), font.cellHeight)
            XCTAssertFalse(font.covers("ΩЖ漢"))
        }
    }

    func testUnicodeUppercaseKeepsAccentsAndSingleCellSharpS() {
        XCTAssertEqual(BitmapLatinGlyphs.uppercase("Æøå é\u{0301} straße"), "ÆØÅ É\u{0301} STRAẞE")
        XCTAssertEqual(BitmapLatinGlyphs.uppercase("A\u{030A}"), "Å")
        XCTAssertEqual(BitmapLatinGlyphs.uppercase("i", locale: Locale(identifier: "tr")), "İ")
    }
}
