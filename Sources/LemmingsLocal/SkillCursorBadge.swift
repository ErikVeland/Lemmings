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
                     tint: NSColor, reduceMotion _: Bool, in _: CGRect) {
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
            let rect = CGRect(x: reticle.maxX - size.width - badgeInset * pixel,
                              y: reticle.maxY - size.height - badgeInset * pixel,
                              width: size.width, height: size.height)
            icon.draw(in: rect, from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none.rawValue])
        } else {
            // Keep the indicator present when source artwork is unavailable, without
            // drawing a tile or label over the reticle.
            tint.withAlphaComponent(0.9).setFill()
            let marker = pixel
            CGRect(x: reticle.maxX - marker - badgeInset * pixel,
                y: reticle.maxY - marker - badgeInset * pixel,
                width: marker,
                height: marker).fill()
        }
    }
}
