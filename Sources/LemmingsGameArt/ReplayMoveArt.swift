import CoreGraphics
import NxlvKit

public enum ReplayMoveArt {
    public static func height(width: CGFloat) -> CGFloat { (width - 8) / 2 < 180 ? 68 : 48 }
    public static func draw(previous: Bool, next: Bool, in rect: CGRect,
                            typography: GameMenuTypography?, context: CGContext) {
        guard let typography else { return }
        for (index, frame) in SolutionSwitchArt.frames(in: rect).enumerated() {
            GameStoneArt.draw(in: context, frame: frame, selected: false, pixel: 1)
            GameTextLayout.draw(index == 0 ? L10n.text("Previous move") : L10n.text("Next move"), in: frame.insetBy(dx: 8, dy: 6),
                typography: typography, alpha: (index == 0 ? previous : next) ? 1 : 0.45, context: context)
        }
    }
}
