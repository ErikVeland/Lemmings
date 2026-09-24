import AppKit

/// Draws the selected skill as a small, pixel-aligned cursor companion.
@MainActor enum SkillCursorBadge {
    private static let reticleSide: CGFloat = 14
    private static let badgeInset: CGFloat = 1

    /**
     * Returns the cursor reticle in view coordinates without moving its hotspot.
     */
    static func reticleFrame(at point: CGPoint, scale: CGFloat) -> CGRect {
        let pixel = max(1, floor(scale))
        let side = reticleSide * pixel
        return CGRect(x: floor((point.x - side / 2) / pixel) * pixel,
                      y: floor((point.y - side / 2) / pixel) * pixel,
                      width: side, height: side)
    }

    static func draw(icon: NSImage?, index _: Int, at point: CGPoint, scale: CGFloat,
                     tint: NSColor, reduceMotion _: Bool, in bounds: CGRect) {
        let pixel = max(1, floor(scale))
        let reticle = reticleFrame(at: point, scale: scale)
        if let icon {
            let available = CGSize(
                width: max(1, reticle.width - 2 * badgeInset * pixel),
                height: max(1, reticle.height - 2 * badgeInset * pixel))
            // Keep one source pixel as one screen pixel. This prevents a selected
            // skill from becoming a second cursor while retaining nearest-neighbour art.
            let fit = min(1, available.width / max(1, icon.size.width),
                          available.height / max(1, icon.size.height))
            let size = CGSize(width: icon.size.width * fit, height: icon.size.height * fit)
            let inset = badgeInset * pixel
            var x = reticle.maxX - size.width - inset
            var y = reticle.maxY - size.height - inset
            if x < bounds.minX || x + size.width > bounds.maxX { x = reticle.minX + inset }
            if y < bounds.minY || y + size.height > bounds.maxY { y = reticle.minY + inset }
            x = min(max(bounds.minX, x), max(bounds.minX, bounds.maxX - size.width))
            y = min(max(bounds.minY, y), max(bounds.minY, bounds.maxY - size.height))
            icon.draw(in: CGRect(x: x, y: y, width: size.width, height: size.height), from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none.rawValue])
        } else {
            // Keep the indicator present when source artwork is unavailable, without
            // drawing a tile or label over the reticle.
            tint.withAlphaComponent(0.9).setFill()
            let marker = pixel
            let inset = badgeInset * pixel
            var x = reticle.maxX - marker - inset
            var y = reticle.maxY - marker - inset
            if x < bounds.minX || x + marker > bounds.maxX { x = reticle.minX + inset }
            if y < bounds.minY || y + marker > bounds.maxY { y = reticle.minY + inset }
            CGRect(x: min(max(bounds.minX, x), bounds.maxX - marker),
                y: min(max(bounds.minY, y), bounds.maxY - marker),
                width: marker, height: marker).fill()
        }
    }
}
