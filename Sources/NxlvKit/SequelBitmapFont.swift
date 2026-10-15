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
    public struct PositionedGlyph: Sendable {
        public let sequence: String
        public let glyph: Glyph?
        public let x: Int, advance: Int
    }
    public let cellWidth: Int, cellHeight: Int
    public let baseline: Int
    public let originals: [Character: Glyph]
    private let letters: [Character: Glyph]
    private let transparent: UInt8
    private let tamilShades: [UInt8]
    private static let tamilCache = GameAssetCache<Glyph>(capacity: 4096)

    init(originals: [Character: [UInt8]], sourceWidth: Int, height: Int,
         advances: [Character: Int] = [:], transparent: UInt8,
         shades: [UInt8], style: BitmapLatinGlyphs.Style) {
        cellWidth = advances.values.max() ?? sourceWidth
        cellHeight = height
        self.transparent = transparent
        tamilShades = shades
        var sourceGlyphs: [Character: Glyph] = [:]
        for (character, pixels) in originals {
            sourceGlyphs[character] = Glyph(x: 0, y: 0, width: sourceWidth, height: height,
                advance: advances[character] ?? sourceWidth, pixels: pixels, opaque: pixels.map { $0 != transparent })
        }
        self.originals = sourceGlyphs
        let capital = sourceGlyphs["H"] ?? sourceGlyphs["A"]
        baseline = capital.flatMap { glyph in
            glyph.opaque.indices.filter { glyph.opaque[$0] }.map { $0 / sourceWidth + 1 }.max()
        } ?? max(1, height - 1)

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
        // L3 has no quote, dash or dot bank. Aliases need a visible base glyph.
        let punctuation: [(Character, [String], Int, Int)] = [
            (".", ["##", "##"], max(0, sourceWidth / 2 - 1), max(0, height - 2)),
            ("'", ["#", "#", "#"], sourceWidth / 2, 0),
            ("\"", ["#.#", "#.#", "#.#"], max(0, sourceWidth / 2 - 1), 0),
            ("-", ["####"], max(0, sourceWidth / 2 - 2), height / 2)
        ]
        for (character, rows, x, y) in punctuation where frames[character] == nil {
            let width = rows.map(\.count).max() ?? 1
            var bytes = [UInt8](repeating: 0, count: width * rows.count * 4)
            for (row, pattern) in rows.enumerated() {
                for (column, pixel) in pattern.enumerated() where pixel == "#" {
                    let offset = (row * width + column) * 4
                    bytes.replaceSubrange(offset..<offset + 4, with: tag(shades.last!))
                }
            }
            frames[character] = ClassicMacArtwork.Frame(x: x, y: y, width: width, height: rows.count, rgba: Data(bytes))
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
        for (character, base): (Character, Character) in [
            ("’", "'"), ("‘", "'"), ("ʼ", "'"), ("“", "\""), ("”", "\""), ("„", "\""), ("«", "\""), ("»", "\""),
            ("–", "-"), ("—", "-"), ("−", "-"), ("‑", "-"), ("\u{00A0}", " "), ("\u{202F}", " "), ("×", "X")
        ] where letters[character] == nil { letters[character] = letters[base] }
        if let dot = letters["."], letters["…"] == nil {
            let step = max(dot.advance, dot.width)
            let width = step * 2 + dot.width
            var pixels = [UInt8](repeating: transparent, count: width * dot.height)
            var opaque = [Bool](repeating: false, count: pixels.count)
            for index in 0..<3 { for y in 0..<dot.height { for x in 0..<dot.width {
                let source = y * dot.width + x, target = y * width + index * step + x
                pixels[target] = dot.pixels[source]; opaque[target] = dot.opaque[source]
            } } }
            letters["…"] = Glyph(x: dot.x, y: dot.y, width: width, height: dot.height,
                advance: step * 3, pixels: pixels, opaque: opaque)
        }
        self.letters = letters
    }

    private func tamilGlyph(for sequence: String) -> Glyph? {
        let canonical = BitmapTamilGlyphs.sequences(in: sequence).joined()
        let key = "\(cellHeight)/\(baseline)/\(transparent)/\(tamilShades)/\(canonical == "ஸ்ரீ" ? "ஶ்ரீ" : canonical)"
        if let cached = Self.tamilCache.value(for: key) { return cached }
        guard let frame = BitmapTamilGlyphs.frame(for: sequence, cellHeight: cellHeight, baseline: baseline),
              let advance = BitmapTamilGlyphs.advance(for: sequence, cellHeight: cellHeight), !tamilShades.isEmpty else { return nil }
        let bytes = [UInt8](frame.rgba)
        var pixels = [UInt8](repeating: transparent, count: frame.width * frame.height)
        var opaque = [Bool](repeating: false, count: pixels.count)
        for index in pixels.indices where bytes[index * 4 + 3] != 0 {
            let offset = index * 4
            // The navy outline is background when the source bank has only a few shades.
            if bytes[offset] == 0, bytes[offset + 1] == 0, bytes[offset + 2] == 64 { continue }
            let light = Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])
            let shade = min(tamilShades.count - 1, light * tamilShades.count / 768)
            pixels[index] = tamilShades[shade]
            opaque[index] = true
        }
        let glyph = Glyph(x: frame.x, y: frame.y, width: frame.width, height: frame.height,
                          advance: advance, pixels: pixels, opaque: opaque)
        Self.tamilCache.insert(glyph, for: key)
        return glyph
    }

    public var supportedSequences: [String] {
        Array(Set(letters.keys.map(String.init)).union(BitmapTamilGlyphs.supportedSequences)).sorted()
    }

    public func glyph(for character: Character) -> Glyph? { letters[character] ?? tamilGlyph(for: String(character)) }
    public func glyph(forSequence sequence: String) -> Glyph? {
        if sequence.count == 1, let character = sequence.first { return glyph(for: character) }
        return tamilGlyph(for: sequence)
    }
    public func covers(_ text: String) -> Bool {
        BitmapTamilGlyphs.sequences(in: text).allSatisfy { glyph(forSequence: $0) != nil }
    }
    public func advance(for character: Character) -> Int {
        (letters[character] ?? tamilGlyph(for: String(character)) ?? letters["?"])?.advance ?? cellWidth
    }
    public func advance(forSequence sequence: String) -> Int {
        if let advance = BitmapTamilGlyphs.advance(for: sequence, cellHeight: cellHeight) { return advance }
        return sequence.count == 1 ? advance(for: sequence.first!) : letters["?"]?.advance ?? cellWidth
    }

    public func layout(_ text: String) -> [PositionedGlyph] {
        var pen = 0
        return BitmapTamilGlyphs.sequences(in: text).map { sequence in
            let advance = advance(forSequence: sequence)
            defer { pen += advance }
            return PositionedGlyph(sequence: sequence, glyph: glyph(forSequence: sequence) ?? letters["?"],
                                   x: pen, advance: advance)
        }
    }

    public func horizontalBounds(of text: String) -> (left: Int, right: Int) {
        var left = 0, right = 0, pen = 0
        for sequence in BitmapTamilGlyphs.sequences(in: text) {
            if let bounds = BitmapTamilGlyphs.metrics(for: sequence, cellHeight: cellHeight, baseline: baseline) {
                left = min(left, pen + bounds.x)
                right = max(right, pen + bounds.x + bounds.width)
            }
            pen += advance(forSequence: sequence)
        }
        return (left, max(pen, right))
    }

    public func width(of text: String) -> Int {
        let bounds = horizontalBounds(of: text)
        return bounds.right - bounds.left
    }

    /**
     * Fit compact panel text by whole Tamil sequences. A kssa or shrii ligature never splits at the boundary.
     */
    public func truncated(_ text: String, toWidth width: Int) -> String {
        var result = ""
        for sequence in BitmapTamilGlyphs.sequences(in: text) {
            let candidate = result + sequence
            guard self.width(of: candidate) <= width else { break }
            result = candidate
        }
        return result
    }

    /**
     * Wrap complete words and split long words only between complete Tamil forms.
     */
    public func wrapped(_ text: String, toWidth width: Int) -> [String] {
        let limit = max(1, width)
        let paragraphs = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        return paragraphs.flatMap { paragraph -> [String] in
            var lines: [String] = [], line = ""
            for word in paragraph.split(whereSeparator: \.isWhitespace).map(String.init) {
                let candidate = line.isEmpty ? word : line + " " + word
                if self.width(of: candidate) <= limit {
                    line = candidate
                    continue
                }
                if !line.isEmpty { lines.append(line); line = "" }
                for sequence in BitmapTamilGlyphs.sequences(in: word) {
                    let candidate = line + sequence
                    if !line.isEmpty, self.width(of: candidate) > limit {
                        lines.append(line)
                        line = sequence
                    } else { line = candidate }
                }
            }
            if !line.isEmpty || lines.isEmpty { lines.append(line) }
            return lines
        }
    }

    public func verticalBounds(of text: String) -> (top: Int, bottom: Int) {
        var top = 0, bottom = cellHeight
        for sequence in BitmapTamilGlyphs.sequences(in: text) {
            if let bounds = BitmapTamilGlyphs.metrics(for: sequence, cellHeight: cellHeight, baseline: baseline) {
                top = min(top, bounds.y)
                bottom = max(bottom, bounds.y + bounds.height)
            } else if let glyph = glyph(forSequence: sequence) ?? letters["?"] {
                top = min(top, glyph.y)
                bottom = max(bottom, glyph.y + glyph.height)
            }
        }
        return (top, bottom)
    }
    public func height(of text: String) -> Int {
        let bounds = verticalBounds(of: text)
        return bounds.bottom - bounds.top
    }

    /// A compact panel band fits the whole row on one pixel grid, including its marks.
    /// ASCII rows use their original pixels without resampling.
    public func raster(_ text: String, fittingHeight: Int? = nil) -> Raster {
        let bounds = verticalBounds(of: text), naturalHeight = bounds.bottom - bounds.top
        let horizontal = horizontalBounds(of: text)
        let width = max(1, horizontal.right - horizontal.left), height = max(1, min(fittingHeight ?? naturalHeight, naturalHeight))
        var pixels = [UInt8](repeating: 0, count: width * height), opaque = [Bool](repeating: false, count: width * height)
        for item in layout(text) {
            guard let glyph = item.glyph else { continue }
            for sourceY in 0..<glyph.height {
                let y = (glyph.y + sourceY - bounds.top) * height / naturalHeight
                guard (0..<height).contains(y) else { continue }
                for x in 0..<glyph.width {
                    let targetX = item.x + glyph.x + x - horizontal.left, source = sourceY * glyph.width + x
                    guard (0..<width).contains(targetX), glyph.opaque[source] else { continue }
                    let target = y * width + targetX
                    let previous = tamilShades.firstIndex(of: pixels[target]) ?? -1
                    let next = tamilShades.firstIndex(of: glyph.pixels[source]) ?? -1
                    if !opaque[target] || height == naturalHeight || next >= previous {
                        pixels[target] = glyph.pixels[source]
                    }
                    opaque[target] = true
                }
            }
        }
        return Raster(width: width, height: height, pixels: pixels, opaque: opaque)
    }
}
