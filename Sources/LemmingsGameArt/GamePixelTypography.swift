import CoreGraphics
import Foundation
import NxlvKit

/// Bitmap lettering shared by mobile drawing and headless captures.
public enum GamePixelTypography {
    private static let columns: [Character: [UInt8]] = [
        "A":[126,9,9,9,126], "B":[127,73,73,73,54], "C":[62,65,65,65,34],
        "D":[127,65,65,34,28], "E":[127,73,73,73,65], "F":[127,9,9,9,1],
        "G":[62,65,73,73,122], "H":[127,8,8,8,127], "I":[0,65,127,65,0],
        "J":[32,64,65,63,1], "K":[127,8,20,34,65], "L":[127,64,64,64,64],
        "M":[127,2,12,2,127], "N":[127,4,8,16,127], "O":[62,65,65,65,62],
        "P":[127,9,9,9,6], "Q":[62,65,81,33,94], "R":[127,9,25,41,70],
        "S":[70,73,73,73,49], "T":[1,1,127,1,1], "U":[63,64,64,64,63],
        "V":[31,32,64,32,31], "W":[63,64,56,64,63], "X":[99,20,8,20,99],
        "Y":[3,4,120,4,3], "Z":[97,81,73,69,67],
        "0":[62,81,73,69,62], "1":[0,66,127,64,0], "2":[98,81,73,73,70],
        "3":[34,65,73,73,54], "4":[24,20,18,127,16], "5":[39,69,69,69,57],
        "6":[60,74,73,73,48], "7":[1,113,9,5,3], "8":[54,73,73,73,54],
        "9":[6,73,73,41,30], ":":[0,54,54,0,0], ".":[0,96,96,0,0],
        "-":[8,8,8,8,8], "+":[8,8,62,8,8], "/":[32,16,8,4,2],
        "*":[20,8,62,8,20], "%":[99,19,8,100,99], "(":[0,28,34,65,0],
        ")":[0,65,34,28,0], "'":[0,3,0,0,0], "!":[0,0,95,0,0],
        ",":[0,64,48,0,0], "<":[8,20,34,65,0], ">":[0,65,34,20,8],
        "?":[2,1,81,9,6], "=":[20,20,20,20,20],
        "z":[0,68,100,84,76], "∞":[28,34,28,34,28], "💀":[14,123,63,123,14]
    ]

    private static let glyphs = BitmapLatinGlyphs.monochrome(columns: columns)
    private static let masks = GameAssetCache<Data>(capacity: 768)
    public static func bitmapGlyph(for character: Character) -> ClassicMacArtwork.Frame? { glyphs[character] }

    public static func bitmapGlyph(forSequence sequence: String) -> ClassicMacArtwork.Frame? {
        if sequence.count == 1, let character = sequence.first, let glyph = glyphs[character] { return glyph }
        return BitmapTamilGlyphs.frame(for: sequence, cellHeight: 7, baseline: 7)
    }

    /// Keep Tamil counters open when a compact destination tints the glyph with one colour.
    public static func monochromeMask(forSequence sequence: String) -> Data? {
        if let cached = masks.value(for: sequence) { return cached }
        guard let glyph = bitmapGlyph(forSequence: sequence) else { return nil }
        let tamil = BitmapTamilGlyphs.supports(sequence)
        let pixels = [UInt8](glyph.rgba)
        let mask = Data(stride(from: 0, to: pixels.count, by: 4).map { index -> UInt8 in
            let outline = tamil && pixels[index] == 0 && pixels[index + 1] == 0 && pixels[index + 2] == 64
            return outline ? 0 : pixels[index + 3]
        })
        masks.insert(mask, for: sequence)
        return mask
    }

    public struct PositionedGlyph {
        public let sequence: String
        public let glyph: ClassicMacArtwork.Frame?
        public let x: Int
        public let advance: Int
    }

    public static func layout(_ text: String) -> [PositionedGlyph] {
        var pen = 0
        return BitmapTamilGlyphs.sequences(in: text).map { sequence in
            let glyph = bitmapGlyph(forSequence: sequence)
            let latin = sequence.count == 1 && sequence.first.map { glyphs[$0] != nil || $0 == " " } == true
            let advance = latin ? 6 : BitmapTamilGlyphs.advance(for: sequence, cellHeight: 7) ?? 6
            defer { pen += advance }
            return PositionedGlyph(sequence: sequence, glyph: glyph, x: pen, advance: advance)
        }
    }

    public static func width(of text: String) -> Int {
        let bounds = horizontalBounds(of: text)
        return max(1, bounds.right - bounds.left)
    }

    public static func horizontalBounds(of text: String) -> (left: Int, right: Int) {
        let items = layout(BitmapLatinGlyphs.uppercase(text, locale: L10n.interface.locale))
        let left = min(0, items.compactMap { item in item.glyph.map { item.x + $0.x } }.min() ?? 0)
        let ink = items.compactMap { item in item.glyph.map { item.x + $0.x + $0.width } }.max() ?? 0
        let advance = items.last.map { $0.x + $0.advance - 1 } ?? 0
        return (left, max(ink, advance))
    }

    public static func lines(_ text: String, width: CGFloat) -> [String] {
        guard !text.isEmpty else { return [] }
        let plain = GameMenuTypography.menuText(text)
        return GameTextLayout.wrapped(BitmapTamilGlyphs.sequences(in: plain), width: width, space: " ",
            text: { $0 }, measure: { CGFloat(self.width(of: $0)) }).map { $0.joined() }
    }

    public static func verticalBounds(of text: String) -> (top: Int, bottom: Int) {
        let frames = layout(BitmapLatinGlyphs.uppercase(text, locale: L10n.interface.locale)).compactMap(\.glyph)
        return (min(0, frames.map(\.y).min() ?? 0), max(7, frames.map { $0.y + $0.height }.max() ?? 7))
    }

    public enum Palette {
        case blue
        case green
        case warning

        var menu: GameMenuTypography.Palette { self == .blue ? .blue : .green }

        var colour: CGColor {
            switch self {
            case .blue: return CGColor(srgbRed: 0.20, green: 0.50, blue: 1, alpha: 1)
            case .green: return CGColor(srgbRed: 0.45, green: 1, blue: 0.10, alpha: 1)
            case .warning: return CGColor(srgbRed: 1, green: 0.42, blue: 0.12, alpha: 1)
            }
        }
    }

    public static func draw(
        _ text: String,
        in rect: CGRect,
        context: CGContext, typography: GameMenuTypography?,
        palette: Palette = .blue,
        maximumScale: CGFloat = 4,
        alignment: GameMenuTypography.Alignment = .center,
        face: GameMenuTypography.Face = .small,
        alpha: CGFloat = 1,
        bitmapOnly: Bool = false, color: CGColor? = nil
    ) {
        guard rect.width > 0, rect.height > 0 else { return }
        if !bitmapOnly, let typography {
            // Lettering keeps one size by purpose. Titles take 2× when they fit, as on the Mac pages.
            let plain = GameMenuTypography.menuText(text)
            let doubled = face == .large
                && typography.width(of: plain, face: face, scale: 2) <= rect.width
                && typography.height(of: plain, face: face, scale: 2) <= rect.height
            let scale = doubled ? 2 : 1
            let height = typography.height(of: plain, face: face, scale: scale)
            typography.menuLine(
                text,
                in: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height),
                context: context,
                face: face,
                scale: scale,
                alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                alpha: alpha,
                palette: palette.menu
            )
            return
        }
        let plain = BitmapLatinGlyphs.uppercase(text, locale: L10n.interface.locale).replacingOccurrences(of: "×", with: "X")
        var normalized = plain
        if CGFloat(width(of: plain)) > rect.width {
            var suffix = "..."
            while !suffix.isEmpty, CGFloat(width(of: suffix)) > rect.width { suffix.removeLast() }
            normalized = ""
            for sequence in BitmapTamilGlyphs.sequences(in: plain) {
                guard CGFloat(width(of: normalized + sequence + suffix)) <= rect.width else { break }
                normalized += sequence
            }
            normalized += suffix
        }
        guard !normalized.isEmpty else { return }
        let naturalWidth = width(of: normalized)
        let items = layout(normalized)
        let bearing = min(0, items.compactMap { item in item.glyph.map { item.x + $0.x } }.min() ?? 0)
        let bounds = verticalBounds(of: normalized)
        let height = CGFloat(bounds.bottom - bounds.top)
        let scale = max(1, min(maximumScale, floor(min(rect.height / height, rect.width / CGFloat(naturalWidth)))))
        let drawnWidth = CGFloat(naturalWidth) * scale
        let start: CGFloat
        switch alignment {
        case .left: start = rect.minX
        case .right: start = rect.maxX - drawnWidth
        default: start = rect.midX - drawnWidth / 2
        }
        let top = floor(rect.midY - height * scale / 2) - CGFloat(bounds.top) * scale
        context.saveGState()
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.setFillColor(color ?? palette.colour)
        context.setAlpha(alpha)
        for item in items {
            guard let glyph = item.glyph, let mask = monochromeMask(forSequence: item.sequence) else { continue }
            for x in 0..<glyph.width {
                for y in 0..<glyph.height where mask[y * glyph.width + x] != 0 {
                    context.fill(CGRect(
                        x: start + CGFloat(item.x - bearing + glyph.x + x) * scale,
                        y: top + CGFloat(glyph.y + y) * scale,
                        width: scale,
                        height: scale
                    ))
                }
            }
        }
        context.restoreGState()
    }
}
