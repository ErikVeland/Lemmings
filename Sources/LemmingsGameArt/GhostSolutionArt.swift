import CoreGraphics
import NxlvKit

/// The whole checkbox row is one target, on every platform.
public enum GhostSolutionArt {
    public static let height: CGFloat = 44
    public static func draw(enabled: Bool, focused: Bool = false, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        GameStoneArt.draw(in: context, frame: rect, selected: focused, pixel: 1)
        let box = CGRect(x: rect.minX + 12, y: rect.midY - 10, width: 20, height: 20)
        GameStoneArt.drawSocket(in: context, frame: box, selected: enabled, pixel: 1)
        if enabled {
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(2)
            context.move(to: CGPoint(x: box.minX + 4, y: box.midY))
            context.addLine(to: CGPoint(x: box.minX + 8, y: box.maxY - 5))
            context.addLine(to: CGPoint(x: box.maxX - 4, y: box.minY + 5))
            context.strokePath()
        }
        GamePixelTypography.draw(L10n.text("Ghost solution"), in: CGRect(x: rect.minX + 44, y: rect.minY,
            width: rect.width - 52, height: rect.height), context: context, typography: typography,
            palette: enabled ? .green : .blue, maximumScale: 1)
    }
}
