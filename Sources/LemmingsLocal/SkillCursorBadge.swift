import AppKit

/// Draws the selected skill as a small, pixel-aligned cursor companion.
@MainActor enum SkillCursorBadge {
    private static let nativeSide: CGFloat = 8
    private static let nativeGap: CGFloat = 3

    /**
     * Returns the badge frame, flipping it at an edge so it stays visible.
     */
    static func frame(at point: CGPoint, scale: CGFloat, in bounds: CGRect) -> CGRect {
        let pixel = max(1, floor(scale))
        let side = nativeSide * pixel
        let gap = nativeGap * pixel
        let safeBounds = bounds.insetBy(dx: pixel, dy: pixel)
        var x = floor((point.x + gap) / pixel) * pixel
        var y = floor((point.y + gap) / pixel) * pixel
        if x + side > safeBounds.maxX {
            x = floor((point.x - gap - side) / pixel) * pixel
        }
        if y + side > safeBounds.maxY {
            y = floor((point.y - gap - side) / pixel) * pixel
        }
        x = min(max(safeBounds.minX, x), max(safeBounds.minX, safeBounds.maxX - side))
        y = min(max(safeBounds.minY, y), max(safeBounds.minY, safeBounds.maxY - side))
        return CGRect(x: x, y: y, width: side, height: side)
    }

    static func draw(icon: NSImage?, index _: Int, at point: CGPoint, scale: CGFloat,
                     tint: NSColor, reduceMotion _: Bool, in bounds: CGRect) {
        let pixel = max(1, floor(scale))
        let rect = frame(at: point, scale: scale, in: bounds)
        NSColor.black.withAlphaComponent(0.62).setFill()
        rect.fill()
        if let icon {
            let available = rect.insetBy(dx: pixel, dy: pixel)
            let fit = min(available.width / max(1, icon.size.width),
                          available.height / max(1, icon.size.height))
            let size = CGSize(width: icon.size.width * fit, height: icon.size.height * fit)
            let iconRect = CGRect(
                x: floor((available.midX - size.width / 2) / pixel) * pixel,
                y: floor((available.midY - size.height / 2) / pixel) * pixel,
                width: size.width,
                height: size.height)
            icon.draw(in: iconRect, from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none.rawValue])
        } else {
            tint.withAlphaComponent(0.9).setFill()
            let marker = 2 * pixel
            CGRect(x: rect.maxX - marker - pixel,
                   y: rect.maxY - marker - pixel,
                   width: marker,
                   height: marker).fill()
        }
    }
}
