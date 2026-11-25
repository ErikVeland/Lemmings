#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import NxlvKit
import LemmingsMobileCore

/// Replay time is elapsed simulation time, independent of the chosen playback speed.
public enum ReplayGameTime {
    public static func clock(tick: Int, rate: Double) -> String {
        let value = rate > 0 && rate.isFinite ? (Double(max(0, tick)) / rate * 100).rounded() : 0
        let hundredths = Int(exactly: value) ?? 0
        return String(format: "%ld:%02ld.%02ld", hundredths / 6000, hundredths / 100 % 60, hundredths % 100)
    }

    public static func skillUse(_ name: String, tick: Int, rate: Double) -> String {
        L10n.text("\(SkillVocabulary.title(name)) at \(clock(tick: tick, rate: rate))")
    }
}

/// Remaining stock stays in the mobile HUD. The replay panel shows successful uses.
public enum MobileReplaySkillArt {
    private static let headingHeight: CGFloat = 26
    private static let rowHeight: CGFloat = 22
    public static let size = CGSize(width: 240, height: headingHeight + 3 * rowHeight)
    /// Keep the passive panel inside the playfield and clear of every input target.
    public static func frame(in playfield: CGRect, below top: CGFloat, avoiding obstacles: [CGRect]) -> CGRect? {
        let available = playfield.insetBy(dx: 8, dy: 8)
        let width = min(size.width, floor(available.width))
        guard width >= 160, available.height >= headingHeight + rowHeight else { return nil }
        let start = max(available.minY, top)
        let rows = ([start] + obstacles.map { max(start, $0.maxY + 8) }).sorted()
        for y in rows {
            for count in [3, 2, 1] {
                let height = headingHeight + CGFloat(count) * rowHeight
                for x in [available.maxX - width, available.minX] {
                    let candidate = CGRect(x: x, y: y, width: width, height: height)
                    if available.contains(candidate), obstacles.allSatisfy({ !candidate.intersects($0) }) { return candidate }
                }
            }
        }
        return nil
    }
    public static func draw(uses: [MobileReplaySkillUse], tick: Int, rate: Double, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        GameDisplayArt.draw(in: context, frame: rect)
        let inner = rect.insetBy(dx: 8, dy: 4)
        let font = typography?.font(.small)
        let heading = GameTextLayout.truncated(L10n.text("Skills used"), width: inner.width, font: font)
        GamePixelTypography.draw(heading, in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: rowHeight),
            context: context, typography: typography, palette: .green, maximumScale: 2)
        let capacity = max(0, min(3, Int((rect.height - headingHeight) / rowHeight)))
        let clockWidth = GameTextLayout.width(of: "88:88.88", font: font)
        let nameX = inner.minX + clockWidth + 6
        let nameWidth = max(0, inner.maxX - nameX)
        for (index, use) in uses.suffix(capacity).enumerated() {
            let palette: GamePixelTypography.Palette = use.tick == tick ? .green : .blue
            let y = rect.minY + headingHeight + CGFloat(index) * rowHeight
            GamePixelTypography.draw(ReplayGameTime.clock(tick: use.tick, rate: rate),
                in: CGRect(x: inner.minX, y: y, width: clockWidth, height: rowHeight),
                context: context, typography: typography, palette: palette, maximumScale: 2, alignment: .left)
            let name = GameTextLayout.truncated(SkillVocabulary.title(use.name), width: nameWidth, font: font)
            GamePixelTypography.draw(name, in: CGRect(x: nameX, y: y, width: nameWidth, height: rowHeight),
                context: context, typography: typography, palette: palette, maximumScale: 2, alignment: .left)
        }
    }
}
#endif
