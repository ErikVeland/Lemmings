import CoreGraphics

/// The stone socket every game control shares, drawn the same way on every platform.
///
/// Colours are sRGB equivalents of the Mac app's calibrated values, so both look alike.
///
/// Rectangles use a top-left origin, so a context must already be flipped to that
/// orientation. AppKit views that return `isFlipped` and UIKit views both are.
public enum GameStoneArt {
    private static let light = CGColor(srgbRed: 0.7084, green: 0.7154, blue: 0.6550, alpha: 1)
    private static let stone = CGColor(srgbRed: 0.4245, green: 0.4435, blue: 0.3937, alpha: 1)
    private static let shadow = CGColor(srgbRed: 0.1457, green: 0.1718, blue: 0.1325, alpha: 1)
    private static let wellIdle = CGColor(srgbRed: 0.0876, green: 0.1166, blue: 0.0728, alpha: 1)
    private static let wellSelected = CGColor(srgbRed: 0.2211, green: 0.3123, blue: 0.1319, alpha: 1)
    private static let accent = CGColor(srgbRed: 0.6755, green: 0.8639, blue: 0.2804, alpha: 1)

    /// The recessed area inside the bevel, where a glyph belongs.
    public static func well(_ frame: CGRect, pixel: CGFloat) -> CGRect {
        frame.insetBy(dx: 4 * pixel, dy: 4 * pixel)
    }

    /// Bevel, rim and well. A caller may paint artwork into the well before `drawAccent`.
    public static func drawSocket(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat, monochrome: Bool = false) {
        let light = monochrome ? CGColor(gray: 1, alpha: 1) : Self.light
        let stone = monochrome ? CGColor(gray: 1, alpha: 1) : Self.stone
        let shadow = monochrome ? CGColor(gray: 0, alpha: 1) : Self.shadow
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        func fill(_ rect: CGRect, _ color: CGColor) {
            context.setFillColor(color)
            context.fill(rect)
        }
        let rim = frame.insetBy(dx: pixel, dy: pixel)
        fill(rim, stone)
        // Top and left catch the light; the selected button sinks into its socket.
        let upper = selected ? shadow : light
        let lower = selected ? light : shadow
        for step in 0..<2 {
            let edge = rim.insetBy(dx: CGFloat(step) * pixel, dy: CGFloat(step) * pixel)
            fill(CGRect(x: edge.minX, y: edge.minY, width: edge.width, height: pixel), upper)
            fill(CGRect(x: edge.minX, y: edge.minY, width: pixel, height: edge.height), upper)
            fill(CGRect(x: edge.minX, y: edge.maxY - pixel, width: edge.width, height: pixel), lower)
            fill(CGRect(x: edge.maxX - pixel, y: edge.minY, width: pixel, height: edge.height), lower)
        }
        let inner = well(frame, pixel: pixel)
        fill(inner.insetBy(dx: -pixel, dy: -pixel), shadow)
        fill(CGRect(x: inner.minX, y: inner.maxY, width: inner.width, height: pixel), light)
        fill(CGRect(x: inner.maxX, y: inner.minY, width: pixel, height: inner.height), light)
        fill(inner, monochrome ? CGColor(gray: 0, alpha: 1) : selected ? wellSelected : wellIdle)
    }

    /// Draws an original panel tile at the scale that fills the whole button, cropped to the
    /// well. The tile keeps its size, and its textured edge gives way to the stone bevel.
    /// A button wider than the tile repeats it side by side.
    public static func drawTile(in context: CGContext, image: CGImage, logicalSize: CGSize,
                                frame: CGRect, pixel: CGFloat) {
        let width = logicalSize.width
        guard width > 0 else { return }
        let copies = max(1, Int(ceil(well(frame, pixel: pixel).width / width)))
        let left = floor(frame.midX - CGFloat(copies) * width / 2)
        let top = floor(frame.midY - logicalSize.height / 2)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: well(frame, pixel: pixel))
        context.interpolationQuality = .none
        for copy in 0..<copies {
            drawImage(image, in: CGRect(x: left + CGFloat(copy) * width, y: top,
                                        width: width, height: logicalSize.height), context: context)
        }
    }

    /// Draws an image into a top-left-origin context without flipping it.
    public static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    /// The moss line along the foot of a selected socket.
    public static func drawAccent(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat, monochrome: Bool = false) {
        guard selected else { return }
        let inner = well(frame, pixel: pixel)
        context.saveGState()
        context.setShouldAntialias(false)
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1) : accent)
        context.fill(CGRect(x: inner.minX + pixel, y: inner.maxY - 2 * pixel,
                            width: inner.width - 2 * pixel, height: pixel))
        context.restoreGState()
    }

    public static func draw(in context: CGContext, frame: CGRect, selected: Bool, pixel: CGFloat) {
        drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
        drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
    }
}
