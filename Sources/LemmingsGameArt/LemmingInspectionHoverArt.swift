import CoreGraphics
import Foundation

/// The passive inspection card shares bitmap measurement and drawing across hosts.
public enum LemmingInspectionHoverArt {
    public struct Layout {
        public let frame: CGRect
        public let title: CGRect
        public let story: CGRect
    }

    public static func layout(title: String, story: String, area: CGRect, pointer: CGPoint,
                              scale: Int, typography: GameMenuTypography?) -> Layout? {
        let available = area.insetBy(dx: 12, dy: 12)
        guard available.width >= 240, available.height >= 120 else { return nil }
        let scale = max(1, scale)
        let width = min(600, floor(available.width * 0.48))
        let padding = CGFloat(12 * scale)
        let textWidth = width - padding * 2
        let font = typography?.font(.small)
        let nameHeight = GameTextLayout.height(title, width: textWidth, scale: scale, font: font)
        let storyHeight = CGFloat(GameTextLayout.lines(story, width: textWidth,
            scale: scale, font: font, preservesCase: true).count)
            * GameTextLayout.linePitch(story, scale: scale, font: font)
        let height = nameHeight + storyHeight + padding * 3
        guard height <= available.height else { return nil }
        let x = pointer.x < available.midX ? available.maxX - width : available.minX
        return Layout(frame: CGRect(x: x, y: available.maxY - height, width: width, height: height),
            title: CGRect(x: padding, y: padding, width: textWidth, height: nameHeight),
            story: CGRect(x: padding, y: padding * 2 + nameHeight, width: textWidth, height: storyHeight))
    }

    public static func draw(title: String, story: String, bounds: CGRect, titleBox: CGRect,
                            storyBox: CGRect, scale: Int, typography: GameMenuTypography, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(bounds)
        context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
        context.setLineWidth(2)
        context.stroke(bounds.insetBy(dx: 1, dy: 1))
        GameTextLayout.draw(title, in: titleBox, typography: typography,
            scale: scale, palette: .green, alignment: .left, context: context)
        GameTextLayout.draw(story, in: storyBox, typography: typography,
            scale: scale, alignment: .left, preservesCase: true, context: context)
    }
}
