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
        CGFloat(lines(text, width: width, face: face, scale: scale).count) * CGFloat((face == .large ? 26 : 24) * scale)
    }
    public static func draw(_ text: String, in box: CGRect, typography: GameMenuTypography, face: GameMenuTypography.Face = .small,
                            scale: Int = 1, palette: GameMenuTypography.Palette = .blue,
                            alignment: GameMenuTypography.Alignment = .center, alpha: CGFloat = 1, context: CGContext) {
        let lines = lines(text, width: box.width, face: face, scale: scale)
        let pitch = CGFloat((face == .large ? 26 : 24) * scale)
        let top = box.midY - CGFloat(lines.count) * pitch / 2
        for (index, line) in lines.enumerated() {
            typography.menuLine(line, in: CGRect(x: box.minX, y: top + CGFloat(index) * pitch + 3 * CGFloat(scale), width: box.width, height: pitch),
                                context: context, face: face, scale: scale, alignment: alignment, alpha: alpha, palette: palette)
        }
    }
}
