import AppKit
import NxlvKit

/// Draws the selected skill as a small, pixel-aligned cursor companion.
@MainActor enum SkillCursorBadge {
    private static let nativeSide: CGFloat = 6
    private static var displayPixel: CGFloat {
        let deviceScale = abs(NSGraphicsContext.current?.cgContext.convertToDeviceSpace(
            CGSize(width: 1, height: 0)).width ?? 1)
        return 1 / max(1, deviceScale)
    }
    private static var cornerGap: CGFloat {
        10 * displayPixel
    }

    /**
     * Returns a badge frame diagonally below the reticle’s lower-right corner.
     */
    static func frame(at point: CGPoint, scale: CGFloat, size: SkillCursorIconSize = .one, in bounds: CGRect) -> CGRect {
        let pixel = displayPixel
        let side = nativeSide * CGFloat(size.multiplier)
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        let gap = cornerGap
        let safeBounds = bounds.insetBy(dx: pixel, dy: pixel)
        var x = reticle.maxX + gap
        var y = reticle.maxY + gap
        x = min(max(safeBounds.minX, x), max(safeBounds.minX, floor((safeBounds.maxX - side) / pixel) * pixel))
        y = min(max(safeBounds.minY, y), max(safeBounds.minY, floor((safeBounds.maxY - side) / pixel) * pixel))
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// Count every live lemming whose sprite centre lies inside the corners.
    static func count(centres: [CGPoint], at point: CGPoint, scale: CGFloat) -> Int {
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        return centres.reduce(0) { $0 + (reticle.contains($1) ? 1 : 0) }
    }

    static func countFrame(count: Int, at point: CGPoint, scale: CGFloat,
                           size: SkillCursorIconSize, icon: NSImage? = nil, in bounds: CGRect) -> CGRect {
        let effectiveSize: SkillCursorIconSize = size == .none ? .one : size
        let multiplier = CGFloat(effectiveSize.multiplier)
        let pixel = max(1, floor(scale))
        let badge = frame(at: point, scale: scale, size: effectiveSize, in: bounds)
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        let width = CGFloat(String(count).count * 6) * multiplier
        let height = 7 * multiplier
        let available = badge
        let iconHeight: CGFloat
        if let icon {
            let fit = min(multiplier, available.width / max(1, icon.size.width), available.height / max(1, icon.size.height))
            iconHeight = icon.size.height * fit
        } else { iconHeight = height }
        let y = floor(available.minY + (iconHeight - height) / 2)
        let x = reticle.minX - cornerGap - width
        return CGRect(x: max(bounds.minX + pixel, min(x, bounds.maxX - pixel - width)),
                      y: max(bounds.minY, min(y, bounds.maxY - height)), width: width, height: height)
    }

    static func drawCount(_ count: Int, at point: CGPoint, scale: CGFloat,
                          size: SkillCursorIconSize, icon: NSImage? = nil, in bounds: CGRect) {
        let rect = countFrame(count: count, at: point, scale: scale, size: size, icon: icon, in: bounds)
        GamePixelText.draw(String(count), in: rect,
            maxScale: CGFloat(size == .none ? 2 : size.multiplier), palette: .blue)
    }

    /**
     * Gently fades the last finite use; reduced motion and unlimited skills stay steady.
     */
    static func opacity(remaining: Int?, now: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard remaining == 1, !reduceMotion else { return 1 }
        return CGFloat(0.875 + 0.125 * cos(now * (2 * .pi / 2.4)))
    }

    static func draw(icon: NSImage?, index _: Int, at point: CGPoint, scale: CGFloat,
                     tint: NSColor, size: SkillCursorIconSize = .one, reduceMotion: Bool,
                     remaining: Int?, now: TimeInterval = ProcessInfo.processInfo.systemUptime, in bounds: CGRect) {
        guard size != .none else { return }
        let multiplier = CGFloat(size.multiplier)
        let pixel = displayPixel
        let rect = frame(at: point, scale: scale, size: size, in: bounds)
        if remaining == 0 {
            drawEmptyMark(in: rect, pixel: pixel, multiplier: multiplier)
            return
        }
        let alpha = opacity(remaining: remaining, now: now, reduceMotion: reduceMotion)
        if let icon {
            let available = rect
            let fit = min(multiplier, available.width / max(1, icon.size.width),
                          available.height / max(1, icon.size.height))
            let size = CGSize(width: icon.size.width * fit, height: icon.size.height * fit)
            let iconRect = CGRect(
                x: available.minX,
                y: available.minY,
                width: size.width,
                height: size.height)
            icon.draw(in: iconRect, from: .zero,
                operation: .sourceOver,
                fraction: alpha,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none.rawValue])
        } else {
            tint.withAlphaComponent(0.9 * alpha).setFill()
            let marker = 2 * pixel
            CGRect(x: rect.maxX - marker - pixel,
                   y: rect.maxY - marker - pixel,
                   width: marker,
                   height: marker).fill()
        }
    }

    private static func drawEmptyMark(in rect: CGRect, pixel: CGFloat, multiplier: CGFloat) {
        let stroke = pixel * multiplier
        let inset = stroke / 2 + pixel
        let mark = NSBezierPath()
        mark.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        mark.line(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        mark.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
        mark.line(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
        mark.lineCapStyle = .square
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = false
        mark.lineWidth = stroke + pixel
        NSColor.black.setStroke()
        mark.stroke()
        mark.lineWidth = stroke
        NSColor(calibratedRed: 0.95, green: 0.17, blue: 0.16, alpha: 1).setStroke()
        mark.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
