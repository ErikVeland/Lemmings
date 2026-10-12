import CoreGraphics
import Foundation

/// The acknowledgement stays clipped to its native sprite.
public enum SpriteAssignmentPulse {
    public static func draw(sprite: CGImage, in rect: CGRect, context: CGContext,
                            progress: Double, reduceMotion: Bool, reduceFlashes: Bool) {
        guard (0..<1).contains(progress), !rect.isEmpty else { return }
        let attack = min(1, 0.18 + progress / 0.18 * 0.82)
        let envelope = CGFloat(min(attack, (1 - progress) / 0.22, 1))
        context.saveGState()
        defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.clip(to: rect, mask: sprite)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 1, blue: 0.2, alpha: (reduceFlashes ? 0.08 : 0.12) * envelope))
        context.fill(rect)
        if !reduceMotion {
            let x = rect.minX + rect.width * CGFloat(progress)
            context.setFillColor(CGColor(srgbRed: 0.2, green: 1, blue: 0.2, alpha: (reduceFlashes ? 0.18 : 0.38) * envelope))
            context.fill(CGRect(x: x - max(1, rect.width * 0.12) / 2, y: rect.minY,
                                width: max(1, rect.width * 0.12), height: rect.height))
            if !reduceFlashes {
                context.setFillColor(CGColor(gray: 1, alpha: 0.5 * envelope))
                context.fill(CGRect(x: floor(x), y: rect.minY, width: 1, height: rect.height))
            }
        }
    }
}
