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

    func testCurrencyGlyphsExistInEmergencyAndStyledFacesWithoutExternalArtwork() throws {
        let currencies: [Character] = ["$", "£", "€", "¥", "₹"]
        let compact = BitmapLatinGlyphs.monochrome(columns: [
            "A": [126, 9, 9, 9, 126], "E": [127, 73, 73, 73, 65], "H": [127, 8, 8, 8, 127],
            "O": [62, 65, 65, 65, 62], "S": [70, 73, 73, 73, 49], "N": [127, 4, 8, 16, 127],
            "?": [2, 1, 81, 9, 6]
        ])
        var silhouettes = Set<Data>()
        for character in currencies {
            XCTAssertTrue(BitmapLatinGlyphs.supports(character))
            let glyph = try XCTUnwrap(compact[character], "Missing emergency currency \(character)")
            XCTAssertTrue(stride(from: 3, to: glyph.rgba.count, by: 4).contains { glyph.rgba[$0] != 0 })
            XCTAssertEqual(glyph.rgba.count, glyph.width * glyph.height * 4)
            XCTAssertLessThanOrEqual(glyph.x + glyph.width, 6)
            XCTAssertEqual(glyph.y + glyph.height, 7)
            XCTAssertNotEqual(glyph.rgba, compact["?"]?.rgba)
            silhouettes.insert(glyph.rgba)
        }
        XCTAssertEqual(silhouettes.count, currencies.count)

        for style in [BitmapLatinGlyphs.Style.macintosh, .sequelFrontEnd, .sequelPanel] {
            for (width, height) in [(8, 8), (12, 18), (16, 20)] {
                let original = ClassicMacArtwork.Frame(x: 0, y: 0, width: width, height: height,
                    rgba: Data(repeating: 255, count: width * height * 4))
                let source: [Character: ClassicMacArtwork.Frame] = [
                    "A": original, "E": original, "H": original, "O": original,
                    "S": original, "N": original, "$": original, "?": original
                ]
                let extended = BitmapLatinGlyphs.extending(source, cellWidth: width, cellHeight: height, style: style)
                XCTAssertEqual(extended["$"]?.rgba, original.rgba)
                for character in currencies {
                    let glyph = try XCTUnwrap(extended[character], "Missing styled currency \(character)")
                    XCTAssertEqual(glyph.rgba.count, glyph.width * glyph.height * 4)
                    XCTAssertTrue(stride(from: 3, to: glyph.rgba.count, by: 4).contains { glyph.rgba[$0] != 0 })
                    XCTAssertGreaterThanOrEqual(glyph.x, 0)
                    XCTAssertLessThanOrEqual(glyph.x + glyph.width, width)
                    XCTAssertLessThanOrEqual(glyph.y + glyph.height, height)
                }
            }
        }
    }
}
