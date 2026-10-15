import CoreGraphics
import Foundation
import NxlvKit

/// Titles and player names use green; quantities and interface text use blue.
public enum GameSemanticText {
    public static func title(_ text: String) -> [GameFrontEnd.TextRun] {
        if let status = text.range(of: " Preview", options: .caseInsensitive) {
            return [.init(String(text[..<status.lowerBound]), .green), .init(String(text[status.lowerBound...]), .blue)]
        }
        guard let split = text.firstIndex(where: { $0.isNumber }) else { return [.init(text, .green)] }
        return [.init(String(text[..<split]), .green), .init(String(text[split...]), .blue)]
    }

    public static func players(_ text: String) -> [GameFrontEnd.TextRun] {
        let normal = text.replacingOccurrences(of: " vs ", with: " v ", options: .caseInsensitive)
        var names: [String] = [], remainder = normal[...]
        while let separator = remainder.range(of: " v ", options: .caseInsensitive) {
            names.append(String(remainder[..<separator.lowerBound]))
            remainder = remainder[separator.upperBound...]
        }
        names.append(String(remainder))
        return names.enumerated().flatMap { index, name in
            (index == 0 ? [] : [GameFrontEnd.TextRun(" v ", .blue)]) + [.init(name, .green)]
        }
    }

    public static func named(_ text: String, name: String) -> [GameFrontEnd.TextRun] {
        guard !name.isEmpty, let range = text.range(of: name, options: .backwards) else { return [.init(text, .blue)] }
        return [.init(String(text[..<range.lowerBound]), .blue), .init(String(text[range]), .green),
                .init(String(text[range.upperBound...]), .blue)].filter { !$0.text.isEmpty }
    }

    public static func resume(_ text: String) -> [GameFrontEnd.TextRun] {
        guard let separator = text.range(of: " - ") else { return [.init(text, .blue)] }
        return [.init(String(text[..<separator.upperBound]), .blue)] + players(String(text[separator.upperBound...]))
    }

    public static func draw(_ runs: [GameFrontEnd.TextRun], in box: CGRect, typography: GameMenuTypography,
                            face: GameMenuTypography.Face = .small, scale: Int = 1,
                            alignment: GameMenuTypography.Alignment = .center,
                            alpha: CGFloat = 1, context: CGContext) {
        guard let font = typography.font(face) else { return }
        typealias Letter = (sequence: String, palette: GameMenuTypography.Palette)
        let text = GameMenuTypography.menuText(runs.map(\.text).joined())
        var boundaries: [(end: Int, palette: GameMenuTypography.Palette)] = [], offset = 0
        var prefix = ""
        for run in runs {
            prefix += run.text
            boundaries.append((GameMenuTypography.menuText(prefix).unicodeScalars.count, run.palette))
        }
        offset = 0
        let letters: [Letter] = BitmapTamilGlyphs.sequences(in: text).map { sequence in
            let palette = boundaries.first { offset < $0.end }?.palette ?? .blue
            offset += sequence.unicodeScalars.count
            return (sequence, palette)
        }
        let lines = GameTextLayout.wrapped(letters, width: box.width, space: (" ", .blue),
            text: { $0.sequence }, measure: { CGFloat(font.width(of: $0, scale: scale)) })
        let bounds = font.verticalBounds(of: text)
        let pitch = CGFloat(font.height(of: text, scale: scale))
        let top = floor(box.midY - CGFloat(lines.count) * pitch / 2)
        for (row, letters) in lines.enumerated() {
            let lineText = letters.map(\.sequence).joined()
            let textWidth = CGFloat(font.width(of: lineText, scale: scale))
            let left: CGFloat
            switch alignment {
            case .left: left = floor(box.minX)
            case .right: left = floor(box.maxX - textWidth)
            case .center: left = floor(box.midX - textWidth / 2)
            }
            let bearing = CGFloat(font.horizontalBounds(of: lineText).left * scale)
            var start = 0, pen = 0
            while start < letters.count {
                var end = start + 1
                while end < letters.count, letters[end].palette == letters[start].palette { end += 1 }
                let run = letters[start..<end].map(\.sequence).joined()
                typography.draw(run, face: face,
                    at: CGPoint(x: left - bearing + CGFloat(pen * scale), y: top + CGFloat(row) * pitch - CGFloat(bounds.top * scale)),
                    scale: scale, in: context, alpha: alpha, palette: letters[start].palette)
                pen += font.layout(run).reduce(0) { $0 + $1.advance }
                start = end
            }
        }
    }
}
