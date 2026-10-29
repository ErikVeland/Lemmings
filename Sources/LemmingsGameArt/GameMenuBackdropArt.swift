import CoreGraphics

/// A menu surface drawn in the same coordinates as its content and targets.
public enum GameMenuBackdropArt {
    public static let margin: CGFloat = 12
    public static let opacity: CGFloat = 0.80

    public static func frame(in bounds: CGRect, margin: CGFloat = margin) -> CGRect {
        bounds.insetBy(dx: margin, dy: margin)
    }

    /// Match the lower contour to the last row of buttons in output coordinates.
    public static func geometry(in bounds: CGRect, layout: GameFrontEnd.Layout, scale: CGFloat,
                                shape: GameControlShape) -> (frame: CGRect, radius: CGFloat) {
        var surface = frame(in: bounds)
        let targets = layout.targets.map { $0.frame.applying(CGAffineTransform(scaleX: scale, y: scale)) }
        guard let bottom = targets.map(\.maxY).max(),
              let button = targets.filter({ abs($0.maxY - bottom) < 0.5 }).max(by: { $0.maxX < $1.maxX }) else {
            return (surface, 20)
        }
        let right = targets.map(\.maxX).max() ?? button.maxX
        let gap = max(0, surface.maxX - right)
        let contentBottom = ([layout.heading, layout.subtitle, layout.preview, layout.initials, layout.stars]
            + layout.details).map { $0.maxY * scale }.max() ?? 0
        guard contentBottom <= bottom, abs(button.maxX - right) < 0.5 else { return (surface, 20) }
        surface.size.height = max(0, bottom + gap - surface.minY)
        let buttonRadius = shape == .rounded ? min(20, min(button.width, button.height) / (4 * scale)) * scale : 0
        return (surface, buttonRadius + gap)
    }

    public static func draw(in context: CGContext, frame: CGRect, radius: CGFloat) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setBlendMode(.overlay)
        context.setFillColor(CGColor(gray: 0, alpha: opacity))
        context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }
}
