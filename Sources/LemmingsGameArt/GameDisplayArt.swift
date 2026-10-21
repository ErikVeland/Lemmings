import CoreGraphics

/// Passive content has a flat, neutral frame. Bevels belong to controls.
public enum GameDisplayArt {
    public static func draw(in context: CGContext, frame: CGRect, pixel: CGFloat = 1) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0.015, alpha: 1))
        context.fill(frame)
        outline(in: context, frame: frame, color: CGColor(gray: 0.32, alpha: 1), pixel: pixel)
    }

    /// A single colour on every edge keeps selection frames flat.
    public static func outline(in context: CGContext, frame: CGRect, color: CGColor, pixel: CGFloat = 1) {
        guard frame.width > 0, frame.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(color)
        context.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: pixel))
        context.fill(CGRect(x: frame.minX, y: frame.maxY - pixel, width: frame.width, height: pixel))
        context.fill(CGRect(x: frame.minX, y: frame.minY, width: pixel, height: frame.height))
        context.fill(CGRect(x: frame.maxX - pixel, y: frame.minY, width: pixel, height: frame.height))
    }
}
