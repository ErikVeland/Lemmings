#if canImport(CoreGraphics)
import CoreGraphics
import LemmingsMobileCore

/// Remaining stock stays in the mobile HUD. The replay panel shows successful uses.
public enum MobileReplaySkillArt {
    public static let size = CGSize(width: 240, height: 84)
    public static func draw(uses: [MobileReplaySkillUse], tick: Int, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / size.width, y: rect.height / size.height)
        GameStoneArt.draw(in: context, frame: CGRect(origin: .zero, size: size), selected: false, pixel: 1)
        GamePixelTypography.draw("USED @ TICK", in: CGRect(x: 8, y: 6, width: 224, height: 18),
            context: context, typography: typography, palette: .green)
        for (index, use) in uses.suffix(3).enumerated() {
            let palette: GamePixelTypography.Palette = use.tick == tick ? .green : .blue
            let y = CGFloat(26 + index * 18)
            GamePixelTypography.draw(String(use.tick), in: CGRect(x: 8, y: y, width: 72, height: 18),
                context: context, typography: typography, palette: palette)
            GamePixelTypography.draw(use.name, in: CGRect(x: 86, y: y, width: 146, height: 18),
                context: context, typography: typography, palette: palette)
        }
    }
}
#endif
