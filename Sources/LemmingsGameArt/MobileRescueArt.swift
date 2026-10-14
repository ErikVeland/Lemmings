import CoreGraphics
import LemmingsMobileCore

public enum MobileRescueArt {
    @MainActor public static func effects(sprites: [MobileSpriteHighlight], viewport: MobileViewport,
        amount: CGFloat, enabled: Bool, maximumEffects: Int = 8,
        image: (MobileSpriteHighlight) -> CGImage?) -> [LemmingSelectionEffect] {
        guard amount > 0, enabled else { return [] }
        let content = viewport.contentFrame
        let clip = CGRect(x: content.x, y: content.y, width: content.width, height: content.height)
        var effects: [LemmingSelectionEffect] = []
        for sprite in sprites {
            guard effects.count < maximumEffects else { break }
            let origin = viewport.viewPoint(fromLevel: .init(x: sprite.rect.x, y: sprite.rect.y))
            let rect = CGRect(x: origin.x, y: origin.y, width: sprite.rect.width * viewport.zoom * viewport.pixelAspect,
                height: sprite.rect.height * viewport.zoom)
            let padding = Double(LemmingSelectionRenderer.padding)
            guard rect.insetBy(dx: -padding * viewport.zoom * viewport.pixelAspect - 2,
                dy: -padding * viewport.zoom - 2).intersects(clip) else { continue }
            // One silhouette glow covers a stack entering the same goal.
            guard !effects.contains(where: { $0.rect.intersects(rect) }), let bitmap = image(sprite) else { continue }
            var effect = LemmingSelectionEffect(sprite: bitmap, rect: rect, clipRect: clip)
            effect.rescueAmount = amount
            effects.append(effect)
        }
        return effects
    }
}
