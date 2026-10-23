import CoreGraphics
import LemmingsMobileCore

/// Replay identity shares one HUD line. Accessibility retains the complete title.
public enum MobileReplayTitleArt {
    public static func size(level: MobileLevelSummary, width: CGFloat) -> CGSize {
        CGSize(width: max(44, width), height: 44)
    }

    public static func caption(level: MobileLevelSummary, width: CGFloat,
                               typography: GameMenuTypography?) -> String {
        GameTextLayout.truncated(level.locationLabel + "  " + level.title,
            width: max(0, width - 16), font: typography?.font(.small))
    }

    public static func draw(level: MobileLevelSummary, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        GameDisplayArt.draw(in: context, frame: rect)
        GamePixelTypography.draw(caption(level: level, width: rect.width, typography: typography),
            in: rect.insetBy(dx: 8, dy: 0), context: context, typography: typography,
            palette: .green, maximumScale: 1, alignment: .left)
    }
}
