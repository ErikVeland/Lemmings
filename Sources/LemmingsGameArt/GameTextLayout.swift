import CoreGraphics
import Foundation
import NxlvKit

/// Fixed bitmap sizes keep titles, section headings and body text distinct.
public enum GameTextLayout {
    public static func lines(_ text: String, width: CGFloat, face: GameMenuTypography.Face = .small, scale: Int = 1) -> [String] {
        let columns = max(1, Int(width) / ((face == .large ? 16 : 12) * scale))
        guard !text.isEmpty else { return [] }
        return GameMenuTypography.menuText(text).components(separatedBy: "\n").flatMap { paragraph -> [String] in
            var lines: [String] = [], line = ""
            for token in paragraph.split(whereSeparator: { $0.isWhitespace }) {
                var word = String(token)
                if !line.isEmpty && line.count + word.count + 1 > columns { lines.append(line); line = "" }
                while word.count > columns { lines.append(String(word.prefix(columns))); word = String(word.dropFirst(columns)) }
                if !word.isEmpty { line += (line.isEmpty ? "" : " ") + word }
            }
            lines.append(line)
            return lines
        }
    }
    public static func height(_ text: String, width: CGFloat, face: GameMenuTypography.Face = .small, scale: Int = 1) -> CGFloat {
        CGFloat(lines(text, width: width, face: face, scale: scale).count) * linePitch(text, face: face, scale: scale)
    }
    public static func linePitch(_ text: String, face: GameMenuTypography.Face = .small, scale: Int = 1) -> CGFloat {
        let padding = BitmapLatinGlyphs.verticalPadding(in: GameMenuTypography.menuText(text))
        let cell = face == .large ? 20 : 18
        return CGFloat(max(cell + 6, cell + padding.above + padding.below + 2) * scale)
    }
    public static func draw(_ text: String, in box: CGRect, typography: GameMenuTypography, face: GameMenuTypography.Face = .small,
                            scale: Int = 1, palette: GameMenuTypography.Palette = .blue,
                            alignment: GameMenuTypography.Alignment = .center, alpha: CGFloat = 1, context: CGContext) {
        let lines = lines(text, width: box.width, face: face, scale: scale)
        let pitch = linePitch(text, face: face, scale: scale)
        let top = box.midY - CGFloat(lines.count) * pitch / 2
        for (index, line) in lines.enumerated() {
            let height = typography.height(of: line, face: face, scale: scale)
            typography.menuLine(line, in: CGRect(x: box.minX, y: top + CGFloat(index) * pitch + (pitch - height) / 2, width: box.width, height: height),
                                context: context, face: face, scale: scale, alignment: alignment, alpha: alpha, palette: palette)
        }
    }
}
