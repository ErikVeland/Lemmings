import CoreGraphics
import LemmingsMobileCore

public enum ReplayMoveArt {
    public static func height(width: CGFloat) -> CGFloat { 44 }

    /// Both actions flank the map, with full-size touch targets.
    public static func frames(in rect: CGRect) -> [CGRect] {
        [CGRect(x: rect.minX, y: rect.midY - 22, width: 44, height: 44),
         CGRect(x: rect.maxX - 44, y: rect.midY - 22, width: 44, height: 44)]
    }

    public static func mapFrame(in rect: CGRect) -> CGRect { rect.insetBy(dx: 48, dy: 0) }

    public static func frame(layout: MobileHUDLayout) -> CGRect? {
        if let map = layout.minimapFrame, map.width >= 144, map.height >= 44 { return map }
        let field = layout.interface.playfieldFrame
        let banks = MobileDisplayRegions.freeFrames(in: field, avoiding: layout.reservedRegions)
        guard let bank = banks.filter({ $0.width >= 160 && $0.height >= 60 })
            .max(by: { $0.width < $1.width }) else { return nil }
        let width = min(384, bank.width - 16)
        return CGRect(x: bank.midX - width / 2, y: bank.maxY - 52, width: width, height: 44)
    }

    public static func draw(previous: Bool, next: Bool, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        for (index, frame) in frames(in: rect).enumerated() {
            GamePlayButtonArt.draw(in: context, frame: frame, selected: false, pixel: 1,
                face: index == 0 ? .stepBackward : .stepForward)
            let glyph: PanelGlyphArt = index == 0 ? .stepBackward : .stepForward
            let scale = glyph.scale(fitting: CGSize(width: 28, height: 28))
            guard let image = glyph.cgImage(scale: scale) else { continue }
            context.saveGState()
            context.setAlpha((index == 0 ? previous : next) ? 1 : 0.35)
            GameStoneArt.drawImage(image, in: CGRect(x: floor(frame.midX - CGFloat(image.width) / 2),
                y: floor(frame.midY - CGFloat(image.height) / 2), width: CGFloat(image.width), height: CGFloat(image.height)), context: context)
            context.restoreGState()
        }
    }
}
