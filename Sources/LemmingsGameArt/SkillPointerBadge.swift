import CoreGraphics
import Foundation

/// Shared, screen-sized skill feedback for touch and television aiming.
public enum SkillPointerBadge {
    public static func innerGlow(in rect: CGRect, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        let colors = [CGColor(srgbRed: 0.28, green: 1, blue: 0.38, alpha: 0.24),
                      CGColor(srgbRed: 0.12, green: 0.8, blue: 0.2, alpha: 0)]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: max(rect.width, rect.height) * 0.65, options: [])
        context.setStrokeColor(CGColor(srgbRed: 0.4, green: 0.95, blue: 0.45, alpha: 0.85))
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }

    @discardableResult public static func draw(icon: CGImage?, name: String, count: String?,
        at point: CGPoint, within bounds: CGRect, scale: CGFloat = 1, context: CGContext) -> CGRect {
        let text = icon == nil ? name.uppercased() : ""
        let iconWidth: CGFloat = icon.map { min(40, max(16, 28 * CGFloat($0.width) / CGFloat($0.height))) } ?? 0
        let width = max(iconWidth + 12, CGFloat(max(text.count, count?.count ?? 0)) * 6 + 12) * scale
        let height: CGFloat = (icon == nil ? 30 : count == nil ? 36 : 48) * scale
        let gap = 24 * scale
        var x = point.x + gap, y = point.y + gap
        if x + width > bounds.maxX { x = point.x - gap - width }
        if y + height > bounds.maxY { y = point.y - gap - height }
        let box = CGRect(x: floor(max(bounds.minX, min(x, bounds.maxX - width))),
            y: floor(max(bounds.minY, min(y, bounds.maxY - height))), width: width, height: height)
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.setFillColor(CGColor(gray: 0.025, alpha: 0.88)); context.fill(box)
        innerGlow(in: box, context: context)
        if let icon {
            let fit = min((box.width - 12 * scale) / CGFloat(icon.width), 28 * scale / CGFloat(icon.height))
            let size = CGSize(width: CGFloat(icon.width) * fit, height: CGFloat(icon.height) * fit)
            GameStoneArt.drawImage(icon, in: CGRect(x: floor(box.midX - size.width / 2), y: floor(box.minY + 5 * scale),
                width: size.width, height: size.height), context: context)
        } else {
            GamePixelTypography.draw(text, in: box.insetBy(dx: 6 * scale, dy: 4 * scale), context: context,
                typography: nil, palette: .green, maximumScale: scale, bitmapOnly: true)
        }
        if let count {
            GamePixelTypography.draw(count, in: CGRect(x: box.minX + 4 * scale, y: box.maxY - 12 * scale,
                width: box.width - 8 * scale, height: 8 * scale), context: context, typography: nil,
                palette: count == "0" ? .warning : .green, maximumScale: scale, bitmapOnly: true)
        }
        return box
    }
}
