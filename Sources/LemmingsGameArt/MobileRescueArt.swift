import CoreGraphics
import LemmingsMobileCore

public enum MobileRescueArt {
    @MainActor public static func effects(sprites: [MobileSpriteHighlight], viewport: MobileViewport,
        amount: CGFloat, enabled: Bool, image: (MobileSpriteHighlight) -> CGImage?) -> [LemmingSelectionEffect] {
        guard amount > 0, enabled else { return [] }
        let content = viewport.contentFrame
        let clip = CGRect(x: content.x, y: content.y, width: content.width, height: content.height)
        return sprites.compactMap { sprite in
            let origin = viewport.viewPoint(fromLevel: .init(x: sprite.rect.x, y: sprite.rect.y))
            let rect = CGRect(x: origin.x, y: origin.y, width: sprite.rect.width * viewport.zoom * viewport.pixelAspect,
                height: sprite.rect.height * viewport.zoom)
            let padding = Double(LemmingSelectionRenderer.padding)
            guard rect.insetBy(dx: -padding * viewport.zoom * viewport.pixelAspect - 2,
                dy: -padding * viewport.zoom - 2).intersects(clip), let bitmap = image(sprite) else { return nil }
            var effect = LemmingSelectionEffect(sprite: bitmap, rect: rect, clipRect: clip)
            effect.rescueAmount = amount
            return effect
        }
    }
}
