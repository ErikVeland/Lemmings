import Foundation
import NxlvKit
import XCTest

final class SequelLatinFontTests: XCTestCase {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func read(_ path: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(path)) }
    private func requireLocalAssets(_ paths: String...) throws {
        let missing = paths.filter { !FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
        guard missing.isEmpty else { throw XCTSkip("Original game assets are not present in this checkout: \(missing.joined(separator: ", "))") }
    }

    func testAllThreeSequelFacesKeepSourcePixelsAndCoverWesternLatin() throws {
        try requireLocalAssets("Sources/Ports/Lemm2/FONT.DAT", "Sources/Ports/Lemm2/PANEL.DAT",
            "Sources/Ports/LEM3CD/GRAPHICS/FONT.DIN", "Sources/Ports/LEM3CD/GRAPHICS/FONT.DEL")
        let menu = try Lemmings2FrontEndFont(data: read("Sources/Ports/Lemm2/FONT.DAT"))
        let panel = try Lemmings2Panel(root: root.appendingPathComponent("Sources/Ports/Lemm2"))
        let l3 = try Lemmings3Font(index: read("Sources/Ports/LEM3CD/GRAPHICS/FONT.DIN"), data: read("Sources/Ports/LEM3CD/GRAPHICS/FONT.DEL"))
        let fonts = [(menu.bitmap, Set<UInt8>([6, 7, 15])), (panel.font, Set<UInt8>([130, 131])), (l3.bitmap, Set<UInt8>([132, 135]))]
        for (font, palette) in fonts {
            for (character, original) in font.originals {
                XCTAssertEqual(font.glyph(for: character), original)
            }
            for character in BitmapLatinGlyphs.characters {
                let glyph = try XCTUnwrap(font.glyph(for: character), "Missing \(character)")
                XCTAssertEqual(glyph.pixels.count, glyph.width * glyph.height)
                XCTAssertEqual(glyph.opaque.count, glyph.pixels.count)
                XCTAssertTrue(glyph.opaque.contains(true))
                XCTAssertTrue(glyph.pixels.indices.allSatisfy { !glyph.opaque[$0] || palette.contains(glyph.pixels[$0]) }, "Foreign colour in \(character)")
            }
            for (plain, extended): (Character, Character) in [("A", "Å"), ("O", "Ø"), ("A", "Æ"), ("E", "É"), ("C", "Ç"), ("S", "Ș")] {
                XCTAssertNotEqual(font.glyph(for: plain)?.pixels, font.glyph(for: extended)?.pixels)
            }
            XCTAssertEqual(font.glyph(for: "Å"), font.glyph(for: "A\u{030A}"))
            XCTAssertEqual(font.width(of: "A\u{030A}ØÆ"), font.width(of: "ÅØÆ"))
            XCTAssertEqual(font.height(of: "ASCII"), font.cellHeight)
            XCTAssertGreaterThan(font.height(of: "ÅÇȘ"), font.cellHeight)
            XCTAssertFalse(font.covers("ΩЖ漢"))
            XCTAssertTrue(font.covers("L’outil «prêt»… 2× — Å\u{202F}Ø"))
            XCTAssertEqual(font.glyph(for: "’"), font.glyph(for: "'"))
            XCTAssertEqual(font.width(of: "…"), font.glyph(for: "…")?.advance)
        }
        for code in 32..<123 {
            let glyph = try XCTUnwrap(menu.bitmap.glyph(for: Character(String(Unicode.Scalar(code)!))))
            XCTAssertEqual(glyph.pixels, menu.glyphs[code - 32])
            XCTAssertEqual(glyph.advance, menu.advances[code - 32])
        }
        for code in 32...90 {
            XCTAssertEqual(panel.font.glyph(for: Character(String(Unicode.Scalar(code)!)))?.pixels, panel.glyphs[code - 32])
        }
        XCTAssertEqual(l3.digits.count, 30)
        XCTAssertTrue(l3.digits.allSatisfy { $0.count == 110 })
    }

    func testOrganicArtworkUsesTheOriginalLookupDataWithTextExpansion() throws {
        let image = try SequelMacFrame(width: 3, height: 3,
            rgba: (0..<9).flatMap { index -> [UInt8] in
                let shade = UInt8(64 + (index % 3) * 32)
                return [shade, 48, 24, 255]
            })
        let result = try SequelMacArtwork.reconstruct(image, category: .organic)
        XCTAssertEqual(result.width, 6)
        XCTAssertEqual(result.height, 6)
        XCTAssertEqual(result.rgba.count, 6 * 6 * 4)
        XCTAssertEqual(result, try SequelMacArtwork.reconstruct(image, category: .organic))
    }

    func testPanelRowsKeepASCIIAndFitCombiningLettersWithoutClipping() throws {
        try requireLocalAssets("Sources/Ports/Lemm2/PANEL.DAT")
        let panel = try Lemmings2Panel(root: root.appendingPathComponent("Sources/Ports/Lemm2"))
        let row = panel.font.raster("WALKER", fittingHeight: 8)
        for (index, character) in "WALKER".enumerated() {
            let glyph = try XCTUnwrap(panel.font.glyph(for: character))
            for y in 0..<8 { for x in 0..<8 {
                let i = y * 8 + x, target = y * row.width + index * 8 + x
                XCTAssertEqual(row.opaque[target], glyph.opaque[i])
                if glyph.opaque[i] { XCTAssertEqual(row.pixels[target], glyph.pixels[i]) }
            }}
        }
        let combined = panel.font.raster("A\u{030A}ØÆ ÉÇȘ", fittingHeight: 8)
        let composed = panel.font.raster("ÅØÆ ÉÇȘ", fittingHeight: 8)
        XCTAssertEqual(combined.width, composed.width)
        XCTAssertEqual(combined.pixels, composed.pixels)
        XCTAssertEqual(combined.opaque, composed.opaque)
        XCTAssertEqual(combined.height, 8)
        let supplies = [Int](repeating: 10, count: 8), skills = [Int](repeating: 1, count: 8)
        let palette = Lemmings2Panel.palette(over: [UInt8](repeating: 0, count: 1024))
        let ascii = try panel.render(skills: skills, supplies: supplies, selected: 0, saved: 0, remaining: 1, seconds: 60, label: "AAAA", palette: palette)
        let latin = try panel.render(skills: skills, supplies: supplies, selected: 0, saved: 0, remaining: 1, seconds: 60, label: "ÅØÆȘ", palette: palette)
        XCTAssertNotEqual(ascii.pixels, latin.pixels)
        for y in 9..<40 { XCTAssertEqual(Array(ascii.pixels[y * 320..<(y + 1) * 320]), Array(latin.pixels[y * 320..<(y + 1) * 320])) }
    }

    func testOriginalL2IntroductionRetainsTimingAndScenes() throws {
        try requireLocalAssets("Sources/Ports/Lemm2/FONT.DAT")
        let base = root.appendingPathComponent("Sources/Ports/Lemm2")
        let font = try Lemmings2FrontEndFont(data: Data(contentsOf: base.appendingPathComponent("FONT.DAT")))
        var intro = try Lemmings2Introduction(root: base, font: font), frames = 0, scenes = Set<Int>()
        while !intro.isComplete && frames < 5000 {
            try intro.step(); frames += 1
            if intro.scene < 8 { scenes.insert(intro.scene) }
        }
        XCTAssertTrue(intro.isComplete)
        XCTAssertEqual(frames, 3902)
        XCTAssertEqual(scenes, Set(0..<8))
    }
}
