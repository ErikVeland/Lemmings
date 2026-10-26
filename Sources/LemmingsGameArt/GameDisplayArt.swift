import CoreGraphics

/// Passive content has a flat, neutral frame. Bevels belong to controls.
public enum GameDisplayArt {
    /// Fill the preview interior without stretching or smoothing the level pixels.
    public static func drawPreview(in context: CGContext, frame: CGRect, image: CGImage?, pixel: CGFloat = 2, shape: GameControlShape = .square) {
        draw(in: context, frame: frame, pixel: pixel, shape: shape)
        let content = frame.insetBy(dx: pixel, dy: pixel)
        guard let image, content.width > 0, content.height > 0 else { return }
        let scale = max(content.width / CGFloat(image.width), content.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.addPath(shape.path(in: frame, inset: pixel))
        context.clip()
        GameStoneArt.drawImage(image, in: CGRect(x: content.midX - size.width / 2,
            y: content.midY - size.height / 2, width: size.width, height: size.height), context: context)
    }

    public static func draw(in context: CGContext, frame: CGRect, pixel: CGFloat = 1, shape: GameControlShape = .square) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0.015, alpha: 1))
        shape.fill(frame, in: context)
        outline(in: context, frame: frame, color: CGColor(gray: 0.32, alpha: 1), pixel: pixel, shape: shape)
    }

    /// A single colour on every edge keeps selection frames flat.
    public static func outline(in context: CGContext, frame: CGRect, color: CGColor, pixel: CGFloat = 1, shape: GameControlShape = .square) {
        guard frame.width > 0, frame.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(color)
        if shape == .rounded {
            context.setStrokeColor(color)
            context.setLineWidth(pixel)
            shape.stroke(frame, inset: pixel / 2, in: context)
            return
        }
        context.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: pixel))
        context.fill(CGRect(x: frame.minX, y: frame.maxY - pixel, width: frame.width, height: pixel))
        context.fill(CGRect(x: frame.minX, y: frame.minY, width: pixel, height: frame.height))
        context.fill(CGRect(x: frame.maxX - pixel, y: frame.minY, width: pixel, height: frame.height))
    }
}
