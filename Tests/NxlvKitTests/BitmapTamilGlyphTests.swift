import Foundation
@testable import NxlvKit
import XCTest

final class BitmapTamilGlyphTests: XCTestCase {
    func testSequelWrappingPreservesLigaturesAndParagraphs() throws {
        let font = sequel(shades: [130, 131])
        let text = "க்ஷீஸ்ரீக்ஷீஸ்ரீக்ஷீஸ்ரீ"
        let units = BitmapTamilGlyphs.sequences(in: text)
        let width = try XCTUnwrap(units.map { font.width(of: $0) }.max())
        let lines = font.wrapped(text, toWidth: width)
        XCTAssertGreaterThan(lines.count, 1)
        XCTAssertEqual(lines.flatMap { BitmapTamilGlyphs.sequences(in: $0) }, units)
        XCTAssertTrue(lines.allSatisfy { font.width(of: $0) <= width })
        XCTAssertEqual(font.wrapped("A\r\n\r\nB", toWidth: 16), ["A", "", "B"])
        XCTAssertEqual(font.wrapped("ONE TWO", toWidth: 24), ["ONE", "TWO"])
    }

    private func classic() throws -> ClassicMacUserInterface.Font {
        let frames: [ClassicMacArtwork.Frame?] = (32...126).map { code in
            guard code != 32 else { return nil }
            var bytes = [UInt8](repeating: 0, count: 12 * 18 * 4)
            for y in 2..<16 { for x in 1..<11 {
                let offset = (y * 12 + x) * 4
                bytes.replaceSubrange(offset..<offset + 4, with: [UInt8(code), 96, 192, 255])
            } }
            return ClassicMacArtwork.Frame(x: 0, y: 0, width: 12, height: 18, rgba: Data(bytes))
        }
        return try XCTUnwrap(ClassicMacUserInterface.Font(frames: frames))
    }

    private func sequel(shades: [UInt8]) -> SequelBitmapFont {
        let originals = Dictionary(uniqueKeysWithValues: (32...126).map { code -> (Character, [UInt8]) in
            var pixels = [UInt8](repeating: 0, count: 64)
            if code != 32 {
                for y in 1..<7 { for x in 1..<7 { pixels[y * 8 + x] = shades[(x + y) % shades.count] } }
            }
            return (Character(String(Unicode.Scalar(code)!)), pixels)
        })
        return SequelBitmapFont(originals: originals, sourceWidth: 8, height: 8,
                                transparent: 0, shades: shades, style: .sequelPanel)
    }

    func testBundledResourceCoversModernGranthaConjunctsAndHistoricSymbols() throws {
        XCTAssertEqual(BitmapTamilGlyphs.supportedSequences.count, 400)
        XCTAssertEqual(Set(BitmapTamilGlyphs.supportedSequences).count, 400)
        let consonants = Array("கஙசஞடணதநபமயரலவழளறனஜஶஷஸஹ").map(String.init)
        XCTAssertEqual(consonants.count, 23)
        let signs = ["", "்", "ா", "ி", "ீ", "ு", "ூ", "ெ", "ே", "ை", "ொ", "ோ", "ௌ"]
        for base in consonants + ["க்ஷ"] {
            for sign in signs { XCTAssertTrue(BitmapTamilGlyphs.supports(base + sign), base + sign) }
        }
        for scalar in Array(0x11FC0...0x11FF1) + [0x11FFF] {
            XCTAssertTrue(BitmapTamilGlyphs.supports(String(Unicode.Scalar(scalar)!)))
        }
        for text in BitmapTamilGlyphs.supportedSequences {
            XCTAssertFalse(text.unicodeScalars.contains(where: \.isASCII))
            for size in [7, 18, 20, 30] {
                let frame = try XCTUnwrap(BitmapTamilGlyphs.frame(for: text, cellHeight: size, baseline: size - 2), text)
                let metrics = try XCTUnwrap(BitmapTamilGlyphs.metrics(for: text, cellHeight: size, baseline: size - 2))
                XCTAssertEqual([frame.x, frame.y, frame.width, frame.height],
                               [metrics.x, metrics.y, metrics.width, metrics.height])
                XCTAssertEqual(frame.rgba.count, frame.width * frame.height * 4)
                XCTAssertTrue(stride(from: 3, to: frame.rgba.count, by: 4).contains { frame.rgba[$0] != 0 }, text)
            }
        }
        XCTAssertFalse(BitmapTamilGlyphs.supports("ா"), "Isolated dotted-circle diagnostics are not runtime letters.")
        XCTAssertFalse(BitmapTamilGlyphs.supports("ΩЖ漢"))
    }

    func testCanonicalFormsAndBothShriiSpellingsSharePixels() throws {
        XCTAssertEqual(BitmapTamilGlyphs.sequences(in: "கொ ஔ"), BitmapTamilGlyphs.sequences(in: "கொ ஔ"))
        for (first, second) in [("கொ", "கொ"), ("ஔ", "ஔ"), ("ஶ்ரீ", "ஸ்ரீ")] {
            let a = try XCTUnwrap(BitmapTamilGlyphs.frame(for: first, cellHeight: 18, baseline: 16))
            let b = try XCTUnwrap(BitmapTamilGlyphs.frame(for: second, cellHeight: 18, baseline: 16))
            XCTAssertEqual(a.rgba, b.rgba)
            XCTAssertEqual([a.x, a.y, a.width, a.height], [b.x, b.y, b.width, b.height])
            XCTAssertEqual(BitmapTamilGlyphs.advance(for: first, cellHeight: 18),
                           BitmapTamilGlyphs.advance(for: second, cellHeight: 18))
        }
        XCTAssertEqual(BitmapTamilGlyphs.sequences(in: "A\u{030A}🙂"), ["Å", "🙂"])
        XCTAssertEqual(BitmapTamilGlyphs.sequences(in: "க\u{0301}"), ["க\u{0301}"], "Unknown marks must not split a Unicode character.")
    }

    func testClassicKeepsASCIIAndPositionsMultiCharacterLigatures() throws {
        let font = try classic()
        for code in 32...126 {
            let text = String(Unicode.Scalar(code)!), character = Character(text)
            let original = font.glyphs[code - 32]
            XCTAssertEqual(font.glyph(for: character)?.rgba, original?.rgba)
            XCTAssertEqual(font.glyph(forSequence: text)?.rgba, original?.rgba)
            XCTAssertEqual(font.advance(forSequence: text), font.cellWidth)
            XCTAssertEqual(font.width(of: text), font.cellWidth)
        }
        let ascii = "ASCII ! 123"
        XCTAssertEqual(font.width(of: ascii), ascii.count * font.cellWidth)
        XCTAssertEqual(font.height(of: ascii), font.cellHeight)
        for ligature in ["க்ஷீ", "ஶ்ரீ", "ஸ்ரீ"] {
            XCTAssertGreaterThan(ligature.count, 1)
            let items = font.layout("A" + ligature + "B")
            XCTAssertEqual(items.map(\.sequence), ["A", ligature, "B"])
            XCTAssertEqual(items[1].x, font.cellWidth)
            XCTAssertEqual(items[2].x, font.cellWidth + items[1].advance)
            XCTAssertNotNil(items[1].glyph)
        }
        XCTAssertNotEqual(font.advance(forSequence: "அ"), font.advance(forSequence: "ஔ"))
        XCTAssertTrue(font.covers("தமிழ் க்ஷீ ஸ்ரீ"))
        XCTAssertFalse(font.covers("Ω"))
        XCTAssertEqual(font.layout("Ω").first?.glyph?.rgba, font.glyph(for: "?")?.rgba)
        let text = "கூகீ ஔ"
        let horizontal = font.horizontalBounds(of: text), vertical = font.verticalBounds(of: text)
        for item in font.layout(text) {
            guard let glyph = item.glyph else { continue }
            XCTAssertGreaterThanOrEqual(item.x + glyph.x, horizontal.left)
            XCTAssertLessThanOrEqual(item.x + glyph.x + glyph.width, horizontal.right)
            XCTAssertGreaterThanOrEqual(glyph.y, vertical.top)
            XCTAssertLessThanOrEqual(glyph.y + glyph.height, vertical.bottom)
        }
        XCTAssertLessThan(horizontal.left, 0)
    }

    func testAllSequelPalettesPreserveOriginalsAndEveryTamilPixel() throws {
        for shades: [UInt8] in [[6, 7, 15], [130, 131], [135, 132]] {
            let font = sequel(shades: shades)
            for (character, original) in font.originals {
                XCTAssertEqual(font.glyph(for: character), original)
                XCTAssertEqual(font.width(of: String(character)), original.advance)
            }
            for sequence in BitmapTamilGlyphs.supportedSequences {
                let glyph = try XCTUnwrap(font.glyph(forSequence: sequence), sequence)
                let frame = try XCTUnwrap(BitmapTamilGlyphs.frame(for: sequence, cellHeight: font.cellHeight, baseline: font.baseline))
                let bytes = [UInt8](frame.rgba)
                var body: [Int] = []
                for offset in stride(from: 0, to: bytes.count, by: 4) {
                    let outline = bytes[offset] == 0 && bytes[offset + 1] == 0 && bytes[offset + 2] == 64
                    if bytes[offset + 3] != 0 && !outline { body.append(offset) }
                }
                XCTAssertFalse(body.isEmpty, sequence)
                XCTAssertEqual(glyph.opaque.filter { $0 }.count, body.count, "The navy outline must not fill the Tamil counters: \(sequence)")
                let raster = font.raster(sequence)
                let horizontal = font.horizontalBounds(of: sequence), vertical = font.verticalBounds(of: sequence)
                XCTAssertEqual(raster.width, font.width(of: sequence))
                XCTAssertEqual(raster.height, font.height(of: sequence))
                XCTAssertEqual(glyph.opaque.filter { $0 }.count, raster.opaque.filter { $0 }.count,
                               "A negative bearing or mark was clipped: \(sequence)")
                for index in glyph.pixels.indices where glyph.opaque[index] {
                    XCTAssertTrue(shades.contains(glyph.pixels[index]))
                    let x = glyph.x + index % glyph.width - horizontal.left
                    let y = glyph.y + index / glyph.width - vertical.top
                    XCTAssertEqual(raster.pixels[y * raster.width + x], glyph.pixels[index])
                }
            }
            XCTAssertEqual(font.glyph(forSequence: "ஸ்ரீ"), font.glyph(forSequence: "ஶ்ரீ"))
            XCTAssertEqual(font.layout("漢").first?.glyph, font.glyph(for: "?"))
        }
    }

    func testCompactRowsKeepEveryInkColumnAndTruncateWholeLigatures() throws {
        let font = sequel(shades: [130, 131])
        let text = "கீகூ க்ஷீ ஸ்ரீ"
        let natural = font.raster(text), compact = font.raster(text, fittingHeight: 8)
        XCTAssertEqual(compact.height, 8)
        XCTAssertEqual(compact.width, natural.width)
        let naturalColumns = Set(natural.opaque.indices.filter { natural.opaque[$0] }.map { $0 % natural.width })
        let compactColumns = Set(compact.opaque.indices.filter { compact.opaque[$0] }.map { $0 % compact.width })
        XCTAssertEqual(compactColumns, naturalColumns)
        let first = "க்ஷீ", limit = font.width(of: first)
        XCTAssertEqual(font.truncated(first + "ஶ்ரீ", toWidth: limit), first)
        XCTAssertEqual(font.truncated(first, toWidth: limit - 1), "")
        XCTAssertEqual(font.truncated("WALKER", toWidth: 16), "WA")
    }
}
