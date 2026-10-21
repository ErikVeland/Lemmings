import CoreGraphics
import LemmingsMobileCore

/// A persistent replay identity in the same stone and lettering as the pause overview.
public enum MobileReplayTitleArt {
    public static func size(level: MobileLevelSummary, width: CGFloat) -> CGSize {
        let width = max(44, width)
        let textWidth = max(12, width - 24)
        return CGSize(width: width, height: 20 + GameTextLayout.height(level.locationLabel, width: textWidth)
            + GameTextLayout.height(level.title, width: textWidth))
    }

    public static func draw(level: MobileLevelSummary, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard let typography, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        GameDisplayArt.draw(in: context, frame: rect)
        let height = GameTextLayout.height(level.locationLabel, width: rect.width - 24)
        GameTextLayout.draw(level.locationLabel,
            in: CGRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: height),
            typography: typography, palette: .blue, context: context)
        GameTextLayout.draw(level.title,
            in: CGRect(x: rect.minX + 12, y: rect.minY + 10 + height, width: rect.width - 24,
                height: rect.height - 20 - height), typography: typography, palette: .green, context: context)
    }
}
