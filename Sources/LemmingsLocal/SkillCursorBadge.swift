import AppKit

/// Draws the selected skill as a small, pixel-aligned cursor companion.
@MainActor enum SkillCursorBadge {
    static func draw(icon: NSImage?, index: Int, at point: CGPoint, scale: CGFloat,
                     tint: NSColor, reduceMotion: Bool, in bounds: CGRect) {
        let pixel = max(1, floor(scale))
        let side = 18 * pixel
        let gap = 6 * pixel
        let x = min(max(bounds.minX + pixel, point.x + gap), bounds.maxX - side - pixel)
        let y = min(max(bounds.minY + pixel, point.y + gap), bounds.maxY - side - pixel)
        let rect = CGRect(x: floor(x / pixel) * pixel, y: floor(y / pixel) * pixel,
                          width: side, height: side)

        NSColor.black.withAlphaComponent(0.86).setFill()
        rect.fill()
        tint.withAlphaComponent(0.88).setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: pixel, dy: pixel))
        border.lineWidth = pixel
        border.stroke()

        let iconRect = rect.insetBy(dx: 3 * pixel, dy: 3 * pixel)
        if let icon {
            let fit = min(iconRect.width / max(1, icon.size.width), iconRect.height / max(1, icon.size.height))
            let size = CGSize(width: icon.size.width * fit, height: icon.size.height * fit)
            icon.draw(in: CGRect(x: iconRect.midX - size.width / 2, y: iconRect.midY - size.height / 2,
                                 width: size.width, height: size.height), from: .zero,
                      operation: .sourceOver, fraction: 1, respectFlipped: true,
                      hints: [.interpolation: NSImageInterpolation.none.rawValue])
        } else {
            let label = "\(max(0, index) + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8 * pixel, weight: .bold),
                .foregroundColor: tint,
            ]
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                       withAttributes: attributes)
        }

        guard !reduceMotion else { return }
        let shimmer = rect.minX + pixel * CGFloat(2 + (Int(ProcessInfo.processInfo.systemUptime * 12) % 12))
        tint.withAlphaComponent(0.24).setFill()
        CGRect(x: shimmer, y: rect.minY + pixel, width: pixel, height: pixel).fill()
    }
}
