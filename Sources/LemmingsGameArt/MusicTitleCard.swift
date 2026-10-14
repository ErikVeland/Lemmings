import CoreGraphics
import Foundation

/// A broadcast credit box with complete, wrapped bitmap titles on every platform.
public enum MusicTitleCard {
    public struct Line {
        public let text: String
        public let frame: CGRect
        public let face: GameMenuTypography.Face
        public let palette: GameMenuTypography.Palette
    }
    public struct Page {
        public let lines: [Line]
        public let duration: TimeInterval
    }
    public struct Layout {
        public let size: CGSize
        public let pages: [Page]
        public var duration: TimeInterval { pages.reduce(0) { $0 + $1.duration } + 0.5 }
        public func pageIndex(at elapsed: TimeInterval) -> Int {
            var end: TimeInterval = 0
            for (index, page) in pages.enumerated() {
                end += page.duration
                if elapsed < end { return index }
            }
            return max(0, pages.count - 1)
        }
        public func nextPageTime(after elapsed: TimeInterval) -> TimeInterval {
            var end: TimeInterval = 0
            for page in pages {
                end += page.duration
                if end > elapsed { return end }
            }
            return duration
        }
    }

    public static func layout(title: String, soundtrack: String, maximumWidth: CGFloat,
                              maximumHeight: CGFloat) -> Layout {
        let titleFace: GameMenuTypography.Face = maximumWidth >= 440 ? .large : .small
        let titleCell: CGFloat = titleFace == .large ? 16 : 12
        let titleText = GameMenuTypography.menuText(title)
        let sourceText = GameMenuTypography.menuText(soundtrack)
        let naturalWidth = max(CGFloat(titleText.count) * titleCell, CGFloat(sourceText.count) * 12) + 40
        let width = floor(min(600, maximumWidth, max(280, naturalWidth)))
        guard width >= 56, maximumHeight >= 54 else { return .init(size: .zero, pages: []) }
        let titleLines = GameTextLayout.lines(title, width: width - 40, face: titleFace)
        let sourceLines = GameTextLayout.lines(soundtrack, width: width - 40)
        var pages: [Page] = [], lines: [Line] = []
        var y: CGFloat = 14, height: CGFloat = 0
        func finish() {
            guard !lines.isEmpty else { return }
            let words = lines.reduce(0) { $0 + $1.text.split(whereSeparator: { $0.isWhitespace }).count }
            pages.append(.init(lines: lines, duration: max(4, Double(words) / 3 + 1)))
            height = max(height, y + 12)
            lines = []; y = 14
        }
        for (text, face, palette, gap) in titleLines.map({ ($0, titleFace, GameMenuTypography.Palette.green, CGFloat(0)) })
            + sourceLines.enumerated().map({ ($0.element, .small, .blue, $0.offset == 0 ? CGFloat(8) : 0) }) {
            let pitch = GameTextLayout.linePitch(text, face: face)
            let spacing = lines.isEmpty ? 0 : gap
            if y + spacing + pitch + 12 > maximumHeight, !lines.isEmpty { finish() }
            if !lines.isEmpty { y += gap }
            lines.append(.init(text: text, frame: CGRect(x: 26, y: y, width: width - 40, height: pitch),
                               face: face, palette: palette))
            y += pitch
        }
        finish()
        return .init(size: CGSize(width: width, height: height), pages: pages)
    }

    public static func frame(size: CGSize, in area: CGRect, flipped: Bool = true, margin: CGFloat = 12) -> CGRect {
        CGRect(x: floor(area.minX + margin), y: floor(flipped ? area.minY + margin : area.maxY - margin - size.height),
               width: size.width, height: size.height)
    }

    public static func draw(_ layout: Layout, elapsed: TimeInterval, typography: GameMenuTypography?, in context: CGContext) {
        guard !layout.pages.isEmpty else { return }
        let bounds = CGRect(origin: .zero, size: layout.size)
        GameStoneArt.draw(in: context, frame: bounds, selected: false, pixel: 1)
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(GameStoneArt.well(bounds, pixel: 1))
        context.setFillColor(CGColor(srgbRed: 0.6755, green: 0.8639, blue: 0.2804, alpha: 1))
        context.fill(CGRect(x: 12, y: 14, width: 3, height: layout.size.height - 28))
        for line in layout.pages[layout.pageIndex(at: elapsed)].lines {
            if let typography {
                typography.menuLine(line.text, in: line.frame, context: context, face: line.face,
                                    alignment: .left, palette: line.palette)
            } else {
                GamePixelTypography.draw(line.text, in: line.frame, context: context, typography: nil,
                    palette: line.palette == .green ? .green : .blue, maximumScale: 1, alignment: .left)
            }
        }
    }
}
