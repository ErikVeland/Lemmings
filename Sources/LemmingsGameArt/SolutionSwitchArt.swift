import CoreGraphics
import NxlvKit

/// Both platforms draw and hit-test the same two stone segments.
public enum SolutionSwitchArt {
    public static let size = CGSize(width: 320, height: 48)
    public static func frames(in rect: CGRect) -> [CGRect] {
        let width = floor((rect.width - 8) / 2)
        return [CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height),
                CGRect(x: rect.minX + width + 8, y: rect.minY, width: rect.width - width - 8, height: rect.height)]
    }
    public static func mode(at point: CGPoint, in rect: CGRect) -> SolutionReplayMode? {
        zip(SolutionReplayMode.allCases, frames(in: rect)).first { $0.1.contains(point) }?.0
    }
    public static func draw(mode: SolutionReplayMode, focused: SolutionReplayMode? = nil,
                            in rect: CGRect, typography: GameMenuTypography?, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        for (value, frame) in zip(SolutionReplayMode.allCases, frames(in: rect)) {
            GameStoneArt.draw(in: context, frame: frame, selected: focused == value, pixel: 1)
            if value == mode {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
                context.fill(CGRect(x: frame.minX + 8, y: frame.maxY - 5, width: frame.width - 16, height: 2))
            }
            GamePixelTypography.draw(value == .game ? "Your game" : "Solution", in: frame.insetBy(dx: 8, dy: 4),
                context: context, typography: typography, palette: value == mode ? .green : .blue, maximumScale: 1)
        }
    }
}
