import Foundation

/// A sequel font keeps palette indices so palette cycling and Mac reconstruction still work.
public struct SequelBitmapFont: Sendable {
    public struct Glyph: Sendable, Equatable {
        public let x: Int, y: Int, width: Int, height: Int, advance: Int
        public let pixels: [UInt8]
        public let opaque: [Bool]
    }
    public struct Raster: Sendable {
        public let width: Int, height: Int
        public let pixels: [UInt8]
        public let opaque: [Bool]
    }
    public let cellWidth: Int, cellHeight: Int
    public let originals: [Character: Glyph]
    private let letters: [Character: Glyph]

    init(originals: [Character: [UInt8]], sourceWidth: Int, height: Int,
         advances: [Character: Int] = [:], transparent: UInt8,
         shades: [UInt8], style: BitmapLatinGlyphs.Style) {
        cellWidth = advances.values.max() ?? sourceWidth
        cellHeight = height
        var sourceGlyphs: [Character: Glyph] = [:]
        for (character, pixels) in originals {
            sourceGlyphs[character] = Glyph(x: 0, y: 0, width: sourceWidth, height: height,
                advance: advances[character] ?? sourceWidth, pixels: pixels, opaque: pixels.map { $0 != transparent })
        }
        self.originals = sourceGlyphs

        // RGB carries shade order and the original index. Only source colours reach the new glyphs.
        func tag(_ index: UInt8) -> [UInt8] {
            let rank = shades.firstIndex(of: index) ?? 0
            let light = UInt8(min(240, (rank + 1) * 60))
            return [light, light, index, index == transparent ? 0 : 255]
        }
        var frames = originals.mapValues { pixels -> ClassicMacArtwork.Frame in
            let visible = pixels.indices.filter { pixels[$0] != transparent }
            let left = visible.map { $0 % sourceWidth }.min() ?? 0
            let right = visible.map { $0 % sourceWidth }.max().map { $0 + 1 } ?? 1
            let top = visible.map { $0 / sourceWidth }.min() ?? 0
            let bottom = visible.map { $0 / sourceWidth }.max().map { $0 + 1 } ?? height
            var bytes: [UInt8] = []
            for y in top..<bottom { for x in left..<right { bytes += tag(pixels[y * sourceWidth + x]) } }
            return ClassicMacArtwork.Frame(x: left, y: top, width: right - left, height: bottom - top, rgba: Data(bytes))
        }
        // The panel banks draw one case. Lowercase Unicode uses those same authored forms.
        for code in 97...122 {
            let lower = Character(String(Unicode.Scalar(code)!)), upper = Character(String(Unicode.Scalar(code - 32)!))
            if frames[lower] == nil { frames[lower] = frames[upper] }
        }
        if frames["?"] == nil {
            let rows = [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."]
            var bytes = [UInt8](repeating: 0, count: sourceWidth * height * 4)
            for (y, row) in rows.enumerated() { for (x, c) in row.enumerated() where c == "#" {
                let i = (y * sourceWidth + x + 1) * 4
                bytes.replaceSubrange(i..<i + 4, with: tag(shades.last!))
                if x + 2 < sourceWidth, y + 1 < height {
                    let shadow = ((y + 1) * sourceWidth + x + 2) * 4
                    bytes.replaceSubrange(shadow..<shadow + 4, with: tag(shades.first!))
                }
            }}
            frames["?"] = ClassicMacArtwork.Frame(x: 0, y: 0, width: sourceWidth, height: height, rgba: Data(bytes))
        }
        let extended = BitmapLatinGlyphs.extending(frames, cellWidth: cellWidth, cellHeight: height, style: style)
        var letters = self.originals
        for (character, frame) in extended where letters[character] == nil {
            let bytes = [UInt8](frame.rgba)
            let pixels = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0 + 3] == 0 ? transparent : bytes[$0 + 2] }
            let opaque = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] != 0 }
            let base = String(character).decomposedStringWithCanonicalMapping.first ?? character
            let baseAdvance = advances[base] ?? cellWidth
            let advance = advances.isEmpty ? sourceWidth : max(baseAdvance, frame.x + frame.width)
            letters[character] = Glyph(x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                                       advance: advance, pixels: pixels, opaque: opaque)
        }
        self.letters = letters
    }

    public func glyph(for character: Character) -> Glyph? { letters[character] }
    public func covers(_ text: String) -> Bool { text.allSatisfy { letters[$0] != nil } }
    public func advance(for character: Character) -> Int { (letters[character] ?? letters["?"])?.advance ?? cellWidth }
    public func width(of text: String) -> Int { text.reduce(0) { $0 + advance(for: $1) } }
    public func verticalBounds(of text: String) -> (top: Int, bottom: Int) {
        let glyphs = text.compactMap { letters[$0] ?? letters["?"] }
        return (min(0, glyphs.map(\.y).min() ?? 0), max(cellHeight, glyphs.map { $0.y + $0.height }.max() ?? cellHeight))
    }
    public func height(of text: String) -> Int {
        let bounds = verticalBounds(of: text)
        return bounds.bottom - bounds.top
    }

    /// A compact panel band fits the whole row on one pixel grid, including its marks.
    /// ASCII rows use their original pixels without resampling.
    public func raster(_ text: String, fittingHeight: Int? = nil) -> Raster {
        let bounds = verticalBounds(of: text), naturalHeight = bounds.bottom - bounds.top
        let width = max(1, width(of: text)), height = max(1, min(fittingHeight ?? naturalHeight, naturalHeight))
        var pixels = [UInt8](repeating: 0, count: width * height), opaque = [Bool](repeating: false, count: width * height)
        var pen = 0
        for character in text {
            defer { pen += advance(for: character) }
            guard let glyph = letters[character] ?? letters["?"] else { continue }
            for y in 0..<height {
                let sourceY = bounds.top + y * naturalHeight / height - glyph.y
                guard (0..<glyph.height).contains(sourceY) else { continue }
                for x in 0..<glyph.width {
                    let targetX = pen + glyph.x + x, source = sourceY * glyph.width + x
                    guard (0..<width).contains(targetX), glyph.opaque[source] else { continue }
                    pixels[y * width + targetX] = glyph.pixels[source]; opaque[y * width + targetX] = true
                }
            }
        }
        return Raster(width: width, height: height, pixels: pixels, opaque: opaque)
    }
}
