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
        typealias Letter = (character: Character, palette: GameMenuTypography.Palette)
        let letters: [Letter] = runs.flatMap { run in
            GameMenuTypography.menuText(run.text).map { ($0, run.palette) }
        }
        let columns = max(1, Int(box.width) / (font.cellWidth * scale))
        let words = letters.split { $0.character.isWhitespace }.map(Array.init)
        var lines: [[Letter]] = [], line: [Letter] = []
        for token in words {
            var word = token
            if !line.isEmpty, line.count + word.count + 1 > columns { lines.append(line); line = [] }
            while word.count > columns { lines.append(Array(word.prefix(columns))); word.removeFirst(columns) }
            if !word.isEmpty {
                if !line.isEmpty { line.append((" ", .blue)) }
                line += word
            }
        }
        if !line.isEmpty { lines.append(line) }
        let text = String(letters.map(\.character))
        let bounds = font.verticalBounds(of: text)
        let pitch = CGFloat(font.height(of: text, scale: scale))
        let top = floor(box.midY - CGFloat(lines.count) * pitch / 2)
        for (row, letters) in lines.enumerated() {
            let textWidth = CGFloat(letters.count * font.cellWidth * scale)
            let left: CGFloat
            switch alignment {
            case .left: left = floor(box.minX)
            case .right: left = floor(box.maxX - textWidth)
            case .center: left = floor(box.midX - textWidth / 2)
            }
            var start = 0
            while start < letters.count {
                var end = start + 1
                while end < letters.count, letters[end].palette == letters[start].palette { end += 1 }
                typography.draw(String(letters[start..<end].map(\.character)), face: face,
                    at: CGPoint(x: left + CGFloat(start * font.cellWidth * scale), y: top + CGFloat(row) * pitch - CGFloat(bounds.top * scale)),
                    scale: scale, in: context, alpha: alpha, palette: letters[start].palette)
                start = end
            }
        }
    }
}
