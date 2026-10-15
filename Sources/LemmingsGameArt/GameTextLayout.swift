import CoreGraphics
import Foundation
import NxlvKit

/// Bitmap layout preserves complete Tamil syllables and fixed Latin sizes.
public enum GameTextLayout {
    public static func width(of text: String, face: GameMenuTypography.Face = .small, scale: Int = 1,
                             font: ClassicMacUserInterface.Font? = nil) -> CGFloat {
        let plain = GameMenuTypography.menuText(text)
        if let font { return CGFloat(font.width(of: plain, scale: scale)) }
        let cellWidth = face == .large ? 16 : 12
        let cellHeight = face == .large ? 20 : 18
        var pen = 0, left = 0, right = 0
        for sequence in BitmapTamilGlyphs.sequences(in: plain) {
            if sequence.count == 1 && sequence.allSatisfy({ BitmapLatinGlyphs.supports($0) || $0 == "💀" }) {
                pen += cellWidth
            } else if let advance = BitmapTamilGlyphs.advance(for: sequence, cellHeight: cellHeight) {
                if let glyph = BitmapTamilGlyphs.metrics(for: sequence, cellHeight: cellHeight, baseline: cellHeight) {
                    left = min(left, pen + glyph.x)
                    right = max(right, pen + glyph.x + glyph.width)
                }
                pen += advance
            } else {
                pen += cellWidth
            }
        }
        return CGFloat(max(pen, right) - left) * CGFloat(scale)
    }

    /// Adds an ellipsis without cutting a syllable or ligature.
    public static func truncated(_ text: String, width: CGFloat, face: GameMenuTypography.Face = .small,
                                 scale: Int = 1, font: ClassicMacUserInterface.Font? = nil) -> String {
        guard width > 0 else { return "" }
        let plain = GameMenuTypography.menuText(text)
        let measure: (String) -> CGFloat = { self.width(of: $0, face: face, scale: scale, font: font) }
        guard measure(plain) > width else { return plain }
        var suffix = "..."
        while !suffix.isEmpty, measure(suffix) > width { suffix.removeLast() }
        var prefix = ""
        for sequence in BitmapTamilGlyphs.sequences(in: plain) {
            guard measure(prefix + sequence + suffix) <= width else { break }
            prefix += sequence
        }
        return prefix + suffix
    }

    public static func lines(_ text: String, width: CGFloat, face: GameMenuTypography.Face = .small, scale: Int = 1,
                             font: ClassicMacUserInterface.Font? = nil) -> [String] {
        guard !text.isEmpty else { return [] }
        return wrapped(BitmapTamilGlyphs.sequences(in: GameMenuTypography.menuText(text)), width: width,
                       space: " ", text: { $0 }, measure: { self.width(of: $0, face: face, scale: scale, font: font) })
            .map { $0.joined() }
    }

    /// Shared wrapping keeps palette runs and plain text on the same boundaries.
    static func wrapped<Element>(_ elements: [Element], width: CGFloat, space: Element,
                                 text: (Element) -> String, measure: (String) -> CGFloat) -> [[Element]] {
        let limit = max(1, width)
        var paragraphs: [[Element]] = [[]]
        for element in elements {
            if text(element).contains(where: \.isNewline) { paragraphs.append([]) }
            else { paragraphs[paragraphs.count - 1].append(element) }
        }
        return paragraphs.flatMap { paragraph -> [[Element]] in
            let words = paragraph.split { text($0).allSatisfy(\.isWhitespace) }.map(Array.init)
            var result: [[Element]] = [], line: [Element] = []
            for token in words {
                var word = token
                if !line.isEmpty, measure((line + [space] + word).map(text).joined()) > limit {
                    result.append(line); line = []
                }
                while measure(word.map(text).joined()) > limit {
                    var count = 0, part: [Element] = []
                    for element in word {
                        if !part.isEmpty, measure((part + [element]).map(text).joined()) > limit { break }
                        part.append(element); count += 1
                    }
                    result.append(part)
                    word.removeFirst(count)
                }
                if !word.isEmpty {
                    if !line.isEmpty { line.append(space) }
                    line += word
                }
            }
            if !line.isEmpty || result.isEmpty { result.append(line) }
            return result
        }
    }

    public static func height(_ text: String, width: CGFloat, face: GameMenuTypography.Face = .small, scale: Int = 1,
                              font: ClassicMacUserInterface.Font? = nil) -> CGFloat {
        CGFloat(lines(text, width: width, face: face, scale: scale, font: font).count)
            * linePitch(text, face: face, scale: scale, font: font)
    }

    public static func linePitch(_ text: String, face: GameMenuTypography.Face = .small, scale: Int = 1,
                                 font: ClassicMacUserInterface.Font? = nil) -> CGFloat {
        let cell = font?.cellHeight ?? (face == .large ? 20 : 18)
        return max(CGFloat(cell + 6) * CGFloat(scale), glyphHeight(of: text, face: face, scale: scale, font: font) + CGFloat(2 * scale))
    }

    public static func glyphHeight(of text: String, face: GameMenuTypography.Face = .small, scale: Int = 1,
                                   font: ClassicMacUserInterface.Font? = nil) -> CGFloat {
        let plain = GameMenuTypography.menuText(text)
        let padding = BitmapLatinGlyphs.verticalPadding(in: plain)
        let cell = font?.cellHeight ?? (face == .large ? 20 : 18)
        var top = -padding.above, bottom = cell + padding.below
        if let font {
            let bounds = font.verticalBounds(of: plain)
            top = min(top, bounds.top); bottom = max(bottom, bounds.bottom)
        } else {
            for sequence in BitmapTamilGlyphs.sequences(in: plain) {
                guard let glyph = BitmapTamilGlyphs.metrics(for: sequence, cellHeight: cell, baseline: cell) else { continue }
                top = min(top, glyph.y); bottom = max(bottom, glyph.y + glyph.height)
            }
        }
        return CGFloat((bottom - top) * scale)
    }
    public static func draw(_ text: String, in box: CGRect, typography: GameMenuTypography, face: GameMenuTypography.Face = .small,
                            scale: Int = 1, palette: GameMenuTypography.Palette = .blue,
                            alignment: GameMenuTypography.Alignment = .center, alpha: CGFloat = 1, context: CGContext) {
        let font = typography.font(face)
        let lines = lines(text, width: box.width, face: face, scale: scale, font: font)
        let pitch = linePitch(text, face: face, scale: scale, font: font)
        let top = box.midY - CGFloat(lines.count) * pitch / 2
        for (index, line) in lines.enumerated() {
            let height = typography.height(of: line, face: face, scale: scale)
            typography.menuLine(line, in: CGRect(x: box.minX, y: top + CGFloat(index) * pitch + (pitch - height) / 2, width: box.width, height: height),
                                context: context, face: face, scale: scale, alignment: alignment, alpha: alpha, palette: palette)
        }
    }
}
