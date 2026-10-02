import AppKit
import NxlvKit

/// Draws the selected skill as a small, pixel-aligned cursor companion.
@MainActor enum SkillCursorBadge {
    private static var artworkCache: [ObjectIdentifier: (source: NSImage, cropped: NSImage)] = [:]

    private static func artwork(_ image: NSImage) -> NSImage {
        let key = ObjectIdentifier(image)
        if let cached = artworkCache[key] { return cached.cropped }
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        var left = cg.width, top = cg.height, right = -1, bottom = -1
        for y in 0..<cg.height { for x in 0..<cg.width {
            if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        } }
        guard right >= left, bottom >= top,
              let cropped = cg.cropping(to: CGRect(x: left, y: top,
                width: right - left + 1, height: bottom - top + 1)) else { return image }
        let result = NSImage(cgImage: cropped, size: NSSize(
            width: CGFloat(cropped.width) * image.size.width / CGFloat(cg.width),
            height: CGFloat(cropped.height) * image.size.height / CGFloat(cg.height)))
        if artworkCache.count >= 128 { artworkCache.removeAll(keepingCapacity: true) }
        artworkCache[key] = (image, result)
        return result
    }

    private static func glyphScale(_ size: SkillCursorIconSize) -> CGFloat {
        CGFloat((size == .none ? SkillCursorIconSize.one : size).multiplier)
    }
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
    static func frame(at point: CGPoint, scale: CGFloat, size: SkillCursorIconSize = .one,
                      icon: NSImage? = nil, in bounds: CGRect) -> CGRect {
        let pixel = displayPixel
        let height = 7 * glyphScale(size)
        let artSize = icon.map { artwork($0).size }
        let width = artSize.map { max(pixel, floor(height * $0.width / max(1, $0.height) / pixel) * pixel) } ?? height
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        let gap = cornerGap
        let safeBounds = bounds.insetBy(dx: pixel, dy: pixel)
        var x = reticle.maxX + gap
        var y = reticle.maxY + gap
        x = min(max(safeBounds.minX, x), max(safeBounds.minX, floor((safeBounds.maxX - width) / pixel) * pixel))
        y = min(max(safeBounds.minY, y), max(safeBounds.minY, floor((safeBounds.maxY - height) / pixel) * pixel))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Count every live lemming whose sprite centre lies inside the corners.
    static func count(centres: [CGPoint], at point: CGPoint, scale: CGFloat) -> Int {
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        return centres.reduce(0) { $0 + (reticle.contains($1) ? 1 : 0) }
    }

    static func countFrame(count: Int, at point: CGPoint, scale: CGFloat,
                           size: SkillCursorIconSize, icon: NSImage? = nil, in bounds: CGRect) -> CGRect {
        let multiplier = glyphScale(size)
        let pixel = displayPixel
        let badge = frame(at: point, scale: scale, size: size, in: bounds)
        let reticle = GameCursor.playfieldPointerFrame(at: point, scale: scale)
        let width = CGFloat(String(count).count * 6) * multiplier
        let x = reticle.minX - cornerGap - width
        return CGRect(x: max(bounds.minX + pixel, min(x, bounds.maxX - pixel - width)),
                      y: badge.minY, width: width, height: badge.height)
    }

    static func drawCount(_ count: Int, at point: CGPoint, scale: CGFloat,
                          size: SkillCursorIconSize, icon: NSImage? = nil, in bounds: CGRect) {
        let rect = countFrame(count: count, at: point, scale: scale, size: size, icon: icon, in: bounds)
        GamePixelText.draw(String(count), in: rect, maxScale: glyphScale(size), palette: .blue)
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
        let multiplier = glyphScale(size)
        let pixel = displayPixel
        let rect = frame(at: point, scale: scale, size: size, icon: remaining == 0 ? nil : icon, in: bounds)
        if remaining == 0 {
            GamePixelText.draw("X", in: CGRect(x: rect.minX, y: rect.minY,
                width: 6 * multiplier, height: rect.height), maxScale: multiplier,
                color: NSColor(calibratedRed: 0.95, green: 0.17, blue: 0.16, alpha: 1))
            return
        }
        let alpha = opacity(remaining: remaining, now: now, reduceMotion: reduceMotion)
        if let icon {
            artwork(icon).draw(in: rect, from: .zero,
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

}
