import Foundation

/// Western Latin additions made from the current font's own pixels and colour ramp.
public enum BitmapLatinGlyphs {
    public enum Style: Sendable { case macintosh, sequelFrontEnd, sequelPanel }
    private typealias Frame = ClassicMacArtwork.Frame
    private struct Point: Hashable { let x: Int, y: Int }
    private static let accents: Set<UInt32> = [0x300, 0x301, 0x302, 0x303, 0x304, 0x306, 0x307, 0x308, 0x30A, 0x30B, 0x30C, 0x327, 0x328, 0x326]
    private static let special = Set(Array("ÆæŒœØøÐðÞþŁłĐđĦħŦŧŊŋıĸſßẞĲĳŉ¡¿"))

    /// Latin-1, Latin Extended-A, Romanian comma-below letters and capital sharp S.
    public static let characters: [Character] = {
        let scalars = Array(0xC0...0x17F) + Array(0x218...0x21B) + [0x1E9E, 0xA1, 0xBF]
        return scalars.compactMap { Unicode.Scalar($0).map { Character(String($0)) } }.filter {
            special.contains($0) || decomposition($0) != nil
        }
    }()
    private static let covered = Set(characters)

    public static func supports(_ character: Character) -> Bool {
        character.isASCII || covered.contains(character)
    }

    /// Keep one cell for sharp S and canonical equivalents for combining accents.
    public static func uppercase(_ text: String, locale: Locale = Locale(identifier: "en")) -> String {
        text.precomposedStringWithCanonicalMapping.map {
            $0 == "ß" ? "ẞ" : String($0).uppercased(with: locale)
        }.joined().precomposedStringWithCanonicalMapping
    }

    /// Extra space for the uppercase menu faces, without changing ASCII spacing.
    public static func verticalPadding(in text: String) -> (above: Int, below: Int) {
        var above = 0, below = 0
        for character in text {
            if character == "Ŋ" || character == "ŋ" { below = max(below, 3) }
            guard let (_, marks) = decomposition(character) else { continue }
            for mark in marks {
                switch mark {
                case 0x327, 0x328: below = max(below, 3)
                case 0x326: below = max(below, 4)
                case 0x30A: above = max(above, 6)
                case 0x304: above = max(above, 2)
                case 0x303, 0x306, 0x307, 0x308: above = max(above, 3)
                default: above = max(above, 4)
                }
            }
        }
        return (above, below)
    }

    private static func decomposition(_ character: Character) -> (Character, [UInt32])? {
        let scalars = Array(String(character).decomposedStringWithCanonicalMapping.unicodeScalars)
        guard scalars.count >= 2, let first = scalars.first,
              first.isASCII, CharacterSet.letters.contains(first),
              scalars.dropFirst().allSatisfy({ accents.contains($0.value) }) else { return nil }
        return (Character(String(first)), scalars.dropFirst().map(\.value))
    }

    /// Existing glyphs are returned untouched. Added forms keep the same cell advance.
    public static func extending(_ original: [Character: ClassicMacArtwork.Frame], cellWidth: Int, cellHeight: Int,
                                 style: Style = .macintosh) -> [Character: ClassicMacArtwork.Frame] {
        guard cellWidth >= 5, cellHeight >= 7 else { return original }
        let builder = Builder(original: original, width: cellWidth, height: cellHeight, style: style)
        var result = original
        for character in characters where result[character] == nil {
            if let glyph = builder.specialGlyph(character) { result[character] = glyph }
        }
        for character in characters where result[character] == nil {
            guard let (base, marks) = decomposition(character), var glyph = result[base] ?? builder.base(base) else { continue }
            if base == "i" || base == "j" || (style == .sequelPanel && (base == "I" || base == "J")) {
                glyph = builder.withoutDot(glyph)
            }
            for mark in marks { glyph = builder.accent(mark, on: glyph) }
            result[character] = glyph
        }
        return result
    }

    /// The compact emergency font uses the same repertoire and composition rules.
    public static func monochrome(columns: [Character: [UInt8]]) -> [Character: ClassicMacArtwork.Frame] {
        let originals = columns.mapValues { columns -> Frame in
            var bytes = [UInt8](repeating: 0, count: columns.count * 7 * 4)
            for (x, column) in columns.enumerated() {
                for y in 0..<7 where column & (1 << y) != 0 {
                    let i = (y * columns.count + x) * 4
                    bytes.replaceSubrange(i..<i + 4, with: [255, 255, 255, 255])
                }
            }
            return Frame(x: 0, y: 0, width: columns.count, height: 7, rgba: Data(bytes))
        }
        return extending(originals, cellWidth: 6, cellHeight: 7)
    }

    private struct Builder {
        let original: [Character: Frame]
        let width: Int, height: Int
        let style: Style
        var compact: Bool { width <= 6 }
        var smallMarks: Bool { compact || style != .macintosh }
        var stroke: Int { width >= 16 ? 2 : 1 }
        var outline: Int { compact || style == .sequelPanel ? 0 : 1 }
        var shadow: Int { style == .sequelPanel ? 1 : outline }
        let ramp: [[UInt8]]

        init(original: [Character: Frame], width: Int, height: Int, style: Style) {
            self.original = original; self.width = width; self.height = height
            self.style = style
            var colours: [UInt32: Int] = [:]
            for character: Character in ["A", "E", "O", "S", "N"] {
                guard let frame = original[character] else { continue }
                let bytes = [UInt8](frame.rgba)
                for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
                    let key = UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2])
                    colours[key, default: 0] += 1
                }
            }
            // Frequent colours carry the original bevel; isolated sparkle pixels are not a new ramp.
            let frequent = colours.filter { $0.value >= 3 }.keys.sorted {
                Self.light($0) < Self.light($1)
            }.map { [UInt8(($0 >> 16) & 255), UInt8(($0 >> 8) & 255), UInt8($0 & 255), 255] }
            ramp = frequent.isEmpty ? [[255, 255, 255, 255]] : frequent
        }
        static func light(_ rgb: UInt32) -> UInt32 {
            ((rgb >> 16) & 255) * 3 + ((rgb >> 8) & 255) * 6 + (rgb & 255)
        }
        static func light(_ pixel: [UInt8]) -> UInt32 {
            UInt32(pixel[0]) * 3 + UInt32(pixel[1]) * 6 + UInt32(pixel[2])
        }
        func joining(_ left: [UInt8]?, _ right: [UInt8]?) -> [UInt8]? {
            guard let left else { return right }
            guard let right else { return left }
            return Self.light(left) >= Self.light(right) ? left : right
        }
        func pixel(_ glyph: Frame, _ x: Int, _ y: Int) -> [UInt8]? {
            guard x >= glyph.x, y >= glyph.y, x < glyph.x + glyph.width, y < glyph.y + glyph.height else { return nil }
            let start = ((y - glyph.y) * glyph.width + x - glyph.x) * 4
            let bytes = Array(glyph.rgba[start..<start + 4])
            return bytes[3] == 0 ? nil : bytes
        }
        func render(_ glyph: Frame, adding shape: Set<Point>) -> Frame {
            guard !shape.isEmpty else { return glyph }
            let left = min(glyph.x, (shape.map(\.x).min() ?? 0) - outline)
            let top = min(glyph.y, (shape.map(\.y).min() ?? 0) - outline)
            let right = max(glyph.x + glyph.width, (shape.map(\.x).max() ?? 0) + 1 + shadow)
            let bottom = max(glyph.y + glyph.height, (shape.map(\.y).max() ?? 0) + 1 + shadow)
            let w = right - left, h = bottom - top
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            for y in top..<bottom { for x in left..<right {
                let p = Point(x: x, y: y)
                var colour = pixel(glyph, x, y)
                if shape.contains(p) {
                    let upperEdge = !shape.contains(Point(x: x - 1, y: y - 1))
                    let lowerEdge = !shape.contains(Point(x: x + 1, y: y + 1))
                    let tone = style == .sequelPanel ? ramp.count - 1 : compact ? 0 : upperEdge ? max(0, ramp.count - 2) : lowerEdge ? min(2, ramp.count - 1) : min(3, ramp.count - 1)
                    colour = ramp[tone]
                } else if colour == nil && style == .sequelPanel && shape.contains(Point(x: x - 1, y: y - 1)) {
                    colour = ramp[0]
                } else if colour == nil && outline > 0 && (-outline...outline).contains(where: { dy in
                    (-outline...outline).contains { dx in shape.contains(Point(x: x + dx, y: y + dy)) }
                }) { colour = style == .sequelFrontEnd ? ramp[ramp.count - 1] : ramp[0] }
                if let colour { bytes.replaceSubrange(((y - top) * w + x - left) * 4..<((y - top) * w + x - left) * 4 + 4, with: colour) }
            }}
            return Frame(x: left, y: top, width: w, height: h, rgba: Data(bytes))
        }
        func mask(_ rows: [String], x: Int, y: Int) -> Set<Point> {
            var result = Set<Point>()
            for (dy, row) in rows.enumerated() { for (dx, c) in row.enumerated() where c != "." {
                result.insert(Point(x: x + dx, y: y + dy))
            }}
            return result
        }
        func topCentre(_ glyph: Frame) -> Int {
            var xs: [Int] = []
            for y in glyph.y..<min(glyph.y + 4, glyph.y + glyph.height) { for x in glyph.x..<glyph.x + glyph.width {
                if let p = pixel(glyph, x, y), ramp.count <= 1 || p != ramp[0] { xs.append(x) }
            }}
            return xs.isEmpty ? width / 2 : ((xs.min() ?? 0) + (xs.max() ?? width - 1)) / 2
        }
        func accent(_ code: UInt32, on glyph: Frame) -> Frame {
            let rows: [String]
            switch code {
            case 0x300: rows = smallMarks ? ["#.", ".#"] : ["##..", ".##.", "..##"]
            case 0x301: rows = smallMarks ? [".#", "#."] : ["..##", ".##.", "##.."]
            case 0x302: rows = smallMarks ? [".#.", "#.#"] : ["..#..", ".###.", "##.##"]
            case 0x303: rows = smallMarks ? [".#.#", "#.#."] : [".##..#", "#..##."]
            case 0x304: rows = smallMarks ? ["###"] : ["#####"]
            case 0x306: rows = smallMarks ? ["#.#", ".#."] : ["##.##", ".###."]
            case 0x307: rows = smallMarks ? ["#"] : ["##", "##"]
            case 0x308: rows = smallMarks ? ["#.#"] : ["##...##", "##...##"]
            case 0x30A: rows = smallMarks && style != .sequelFrontEnd ? [".#.", "#.#", ".#."] : [".###.", "#...#", "#...#", "#...#", ".###."]
            case 0x30B: rows = smallMarks ? [".#.#", "#.#."] : ["..#..#", ".#..#.", "#..#.."]
            case 0x30C: rows = smallMarks ? ["#.#", ".#."] : ["##.##", ".###.", "..#.."]
            case 0x327: rows = smallMarks ? [".#", "#."] : [".#.", "..#", "##."]
            case 0x328: rows = smallMarks ? ["#.", ".#"] : [".#.", "#..", ".##"]
            case 0x326: rows = smallMarks ? ["#", "#"] : [".##", ".##", "##."]
            default: return glyph
            }
            let markWidth = rows.map(\.count).max() ?? 1
            let below = [0x327, 0x328, 0x326].contains(code)
            let centre = below && code == 0x328 ? width - markWidth - shadow : topCentre(glyph) - markWidth / 2
            let x = max(outline, min(width - markWidth - shadow, centre))
            let y = below ? glyph.y + glyph.height - (code == 0x326 ? 0 : 1) : glyph.y - rows.count - (smallMarks ? 0 : 1)
            return render(glyph, adding: mask(rows, x: x, y: y))
        }
        func withoutDot(_ glyph: Frame) -> Frame {
            var gap: Int?
            for y in glyph.y + 1..<glyph.y + glyph.height / 2 {
                if (glyph.x..<glyph.x + glyph.width).allSatisfy({ pixel(glyph, $0, y) == nil }) { gap = y; break }
            }
            if gap == nil && style == .sequelFrontEnd { gap = max(glyph.y, 3) }
            guard let gap, gap + 1 < glyph.y + glyph.height else { return glyph }
            let drop = gap + 1 - glyph.y
            return Frame(x: glyph.x, y: glyph.y + drop, width: glyph.width, height: glyph.height - drop,
                rgba: Data(glyph.rgba.dropFirst(drop * glyph.width * 4)))
        }
        func base(_ character: Character) -> Frame? { original[character] ?? original[Character(String(character).uppercased())] }
        func slash(_ glyph: Frame, full: Bool = true) -> Frame {
            let extendsRim = full && style != .macintosh
            let left = extendsRim ? max(0, glyph.x - 1) : compact ? 0 : 2
            let right = extendsRim ? min(width - 1, glyph.x + glyph.width - 1) : full ? width - (compact ? 2 : 3) : width / 2
            let top = extendsRim ? glyph.y - 1 : glyph.y + (compact ? 1 : 2)
            let bottom = extendsRim ? glyph.y + glyph.height : glyph.y + glyph.height - (compact ? 2 : 3)
            var points = Set<Point>()
            for y in top...max(top, bottom) {
                let x = right - (y - top) * max(1, right - left) / max(1, bottom - top)
                for dx in 0..<stroke { points.insert(Point(x: x + dx, y: y)) }
            }
            return render(glyph, adding: points)
        }
        func bar(_ glyph: Frame, top: Bool = false) -> Frame {
            let y = glyph.y + (top ? max(1, glyph.height / 4) : glyph.height / 2)
            return render(glyph, adding: mask(Array(repeating: String(repeating: "#", count: width - outline * 2), count: stroke), x: outline, y: y))
        }
        func ligature(_ a: Character, _ b: Character) -> Frame? {
            guard let a = base(a), let b = base(b) else { return nil }
            let advance = compact ? 2 : width / 2
            let aWidth = advance + (compact ? 1 : 2), bWidth = width - advance - (compact ? 1 : 0)
            let top = min(a.y, b.y), bottom = max(a.y + a.height, b.y + b.height)
            var bytes = [UInt8](repeating: 0, count: width * (bottom - top) * 4)
            for y in top..<bottom { for x in 0..<width {
                let left = x < aWidth ? pixel(a, a.x + x * a.width / aWidth, y) : nil
                let right = (advance..<advance + bWidth).contains(x) ? pixel(b, b.x + (x - advance) * b.width / bWidth, y) : nil
                // The shared stem joins the letters. An outline must not erase its face.
                let selected = joining(left, right)
                if let selected { bytes.replaceSubrange(((y - top) * width + x) * 4..<((y - top) * width + x) * 4 + 4, with: selected) }
            }}
            return Frame(x: 0, y: top, width: width, height: bottom - top, rgba: Data(bytes))
        }
        func specialGlyph(_ character: Character) -> Frame? {
            switch character {
            case "Æ": return ligature("A", "E")
            case "æ": return ligature("a", "e")
            case "Œ": return ligature("O", "E")
            case "œ": return ligature("o", "e")
            case "Ĳ": return ligature("I", "J")
            case "ĳ": return ligature("i", "j")
            case "Ø", "ø": return base(character == "Ø" ? "O" : "o").map { slash($0) }
            case "Ł", "ł": return base(character == "Ł" ? "L" : "l").map { slash($0, full: false) }
            case "Ð", "Đ", "ð", "đ": return base(character.isUppercase ? "D" : "d").map { bar($0, top: !character.isUppercase) }
            case "Ħ", "ħ": return base(character == "Ħ" ? "H" : "h").map { bar($0, top: true) }
            case "Ŧ", "ŧ": return base(character == "Ŧ" ? "T" : "t").map { bar($0) }
            case "Þ", "þ":
                guard let p = base(character == "Þ" ? "P" : "p") else { return nil }
                var bytes = [UInt8](repeating: 0, count: width * height * 4)
                // Move the bowl down and retain a stem above and below it, as in thorn.
                for y in 0..<height { for x in 0..<width {
                    let sourceY = p.y + max(0, y - 2) * p.height / height
                    let q = pixel(p, x, sourceY)
                    if let q, y >= 2 || x <= (compact ? 0 : 3) { bytes.replaceSubrange((y * width + x) * 4..<(y * width + x) * 4 + 4, with: q) }
                }}
                return Frame(x: 0, y: 0, width: width, height: height, rgba: Data(bytes))
            case "Ŋ", "ŋ":
                guard let n = base(character == "Ŋ" ? "N" : "n") else { return nil }
                return render(n, adding: mask(compact ? [".#", "#."] : ["..##", "..##", "###."], x: width - (compact ? 3 : 6), y: height - 1))
            case "ı": return base("i").map(withoutDot)
            case "ſ":
                guard let f = base("f") else { return nil }
                var bytes = [UInt8](f.rgba)
                let stem = topCentre(f)
                // Long S retains the ascender of f, but has no right crossbar.
                for y in f.y + f.height / 3..<f.y + f.height * 2 / 3 {
                    for x in max(f.x, stem + stroke)..<f.x + f.width {
                        let i = ((y - f.y) * f.width + x - f.x) * 4
                        bytes.replaceSubrange(i..<i + 4, with: [0, 0, 0, 0])
                    }
                }
                return Frame(x: f.x, y: f.y, width: f.width, height: f.height, rgba: Data(bytes))
            case "ĸ":
                guard let k = base("k"), let n = base("n") else { return nil }
                var bytes = [UInt8](repeating: 0, count: k.width * n.height * 4)
                for y in 0..<n.height { for x in 0..<k.width {
                    let sourceY = k.y + y * k.height / n.height
                    if let p = pixel(k, k.x + x, sourceY) {
                        let i = (y * k.width + x) * 4
                        bytes.replaceSubrange(i..<i + 4, with: p)
                    }
                }}
                return Frame(x: k.x, y: n.y, width: k.width, height: n.height, rgba: Data(bytes))
            case "ŉ": return base("n").map {
                render($0, adding: mask(compact ? ["#", "#"] : [".##", ".##", "##."], x: outline, y: $0.y - (compact ? 2 : 4)))
            }
            case "ß", "ẞ": return sharpS(lowercase: character == "ß")
            case "¡", "¿":
                guard let glyph = base(character == "¡" ? "!" : "?") else { return nil }
                var bytes = [UInt8](glyph.rgba)
                for y in 0..<glyph.height { for x in 0..<glyph.width {
                    let source = ((glyph.height - y - 1) * glyph.width + x) * 4
                    bytes.replaceSubrange((y * glyph.width + x) * 4..<(y * glyph.width + x) * 4 + 4, with: glyph.rgba[source..<source + 4])
                }}
                return Frame(x: glyph.x, y: glyph.y, width: glyph.width, height: glyph.height, rgba: Data(bytes))
            default: return nil
            }
        }
        func sharpS(lowercase: Bool) -> Frame? {
            guard let b = base(lowercase ? "b" : "B") else { return nil }
            // An open upper bowl and a descending S distinguish sharp S from B.
            let rows = [".###.", "#...#", "#..#.", "#.#..", "#..#.", "#...#", "#.##."]
            let top = lowercase ? min(b.y, 2) : b.y
            let w = compact ? 5 : width - 2 * outline - (style == .sequelPanel ? 1 : 0)
            let h = height - top - outline
            var shape = Set<Point>()
            for y in 0..<h { for x in 0..<w {
                let row = Array(rows[min(6, y * 7 / max(1, h))])
                if row[min(4, x * 5 / max(1, w))] == "#" { shape.insert(Point(x: x + outline, y: y + top)) }
            }}
            let blank = Frame(x: 0, y: top, width: width, height: height - top, rgba: Data(repeating: 0, count: width * (height - top) * 4))
            return render(blank, adding: shape)
        }
    }
}
