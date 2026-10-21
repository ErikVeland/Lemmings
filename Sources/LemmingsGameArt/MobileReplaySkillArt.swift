#if canImport(CoreGraphics)
import CoreGraphics
import NxlvKit
import LemmingsMobileCore

/// Remaining stock stays in the mobile HUD. The replay panel shows successful uses.
public enum MobileReplaySkillArt {
    public static let size = CGSize(width: 240, height: 84)
    /// Keep the passive panel inside the playfield and clear of every input target.
    public static func frame(in playfield: CGRect, below top: CGFloat, avoiding obstacles: [CGRect]) -> CGRect? {
        let available = playfield.insetBy(dx: 8, dy: 8)
        guard available.width >= 120, available.height >= 42 else { return nil }
        let start = max(available.minY, top)
        let rows = ([start] + obstacles.map { max(start, $0.maxY + 8) }).sorted()
        for y in rows {
            let width = floor(min(size.width, available.width, (available.maxY - y) * size.width / size.height))
            guard width >= 120 else { continue }
            for x in [available.maxX - width, available.minX] {
                let candidate = CGRect(x: x, y: y, width: width, height: width * size.height / size.width)
                if available.contains(candidate), obstacles.allSatisfy({ !candidate.intersects($0) }) { return candidate }
            }
        }
        return nil
    }
    public static func draw(uses: [MobileReplaySkillUse], tick: Int, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / size.width, y: rect.height / size.height)
        GameDisplayArt.draw(in: context, frame: CGRect(origin: .zero, size: size))
        GamePixelTypography.draw(L10n.text("USED @ TICK"), in: CGRect(x: 8, y: 6, width: 224, height: 18),
            context: context, typography: typography, palette: .green)
        for (index, use) in uses.suffix(3).enumerated() {
            let palette: GamePixelTypography.Palette = use.tick == tick ? .green : .blue
            let y = CGFloat(26 + index * 18)
            GamePixelTypography.draw(String(use.tick), in: CGRect(x: 8, y: y, width: 72, height: 18),
                context: context, typography: typography, palette: palette)
            GamePixelTypography.draw(SkillVocabulary.title(use.name), in: CGRect(x: 86, y: y, width: 146, height: 18),
                context: context, typography: typography, palette: palette)
        }
    }
}
#endif
