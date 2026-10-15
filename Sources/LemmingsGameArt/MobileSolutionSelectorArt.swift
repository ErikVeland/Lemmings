import CoreGraphics
import NxlvKit

/// Shared geometry keeps bitmap rows and native touch/focus targets together.
public enum MobileSolutionSelectorArt {
    public enum Style: Equatable, Sendable { case touch, television }
    public struct Layout {
        public let size: CGSize
        public let modes: [CGRect]
        public let ghost: CGRect?
        public var targets: [CGRect] { modes + (ghost.map { [$0] } ?? []) }
    }

    public struct Presentation {
        public let controls: CGRect
        public let content: CGRect
        public let scale: CGFloat
    }

    public static func presentation(in region: CGRect, showsGhost: Bool, style: Style) -> Presentation {
        let scale: CGFloat = style == .television ? 2 : 1
        let width = style == .television
            ? min(region.width - 296, min(640, max(608, floor(region.width * 0.34))))
            : region.width - 16
        let height = layout(width: width / scale, showsGhost: showsGhost, style: style).size.height * scale
        let controls = CGRect(x: region.minX + 8, y: region.minY + 8, width: width, height: height)
        let content = style == .television
            ? CGRect(x: controls.maxX + 16, y: region.minY, width: region.maxX - controls.maxX - 16, height: region.height)
            : CGRect(x: region.minX, y: controls.maxY + 8, width: region.width, height: region.maxY - controls.maxY - 8)
        return Presentation(controls: controls, content: content, scale: scale)
    }

    public static func layout(width: CGFloat, showsGhost: Bool, style: Style) -> Layout {
        let modes = style == .television
            ? [CGRect(x: 0, y: 0, width: width, height: 48), CGRect(x: 0, y: 56, width: width, height: 48)]
            : SolutionSwitchArt.frames(in: CGRect(x: 0, y: 0, width: width, height: 48))
        let ghost = showsGhost ? CGRect(x: 0, y: modes[1].maxY + 8, width: width, height: 56) : nil
        return Layout(size: CGSize(width: width, height: ghost?.maxY ?? modes[1].maxY), modes: modes, ghost: ghost)
    }

    public static func draw(mode: SolutionReplayMode, ghostEnabled: Bool, focusedIndex: Int? = nil,
                            layout: Layout, typography: GameMenuTypography?, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        for (value, rect) in zip(SolutionReplayMode.allCases, layout.modes) {
            GameStoneArt.draw(in: context, frame: rect, selected: false, pixel: 1)
            if value == mode {
                context.setFillColor(CGColor(srgbRed: 0.48, green: 0.80, blue: 0.24, alpha: 1))
                context.fill(CGRect(x: rect.minX + 8, y: rect.maxY - 5, width: rect.width - 16, height: 2))
            }
            GamePixelTypography.draw(value == .game ? L10n.text("Your game") : L10n.text("Solution"),
                in: rect.insetBy(dx: 12, dy: 6), context: context, typography: typography,
                palette: .blue, maximumScale: 1)
        }
        if let rect = layout.ghost {
            GameStoneArt.draw(in: context, frame: rect, selected: false, pixel: 1)
            GamePixelTypography.draw(L10n.text("Ghost solution"),
                in: CGRect(x: rect.minX + 12, y: rect.minY, width: rect.width - 128, height: rect.height),
                context: context, typography: typography, palette: .blue, maximumScale: 1, alignment: .left)
            GamePixelTypography.draw(ghostEnabled ? L10n.text("On") : L10n.text("Off"),
                in: CGRect(x: rect.maxX - 108, y: rect.minY, width: 40, height: rect.height),
                context: context, typography: typography, palette: .blue, maximumScale: 1)
            let track = CGRect(x: rect.maxX - 64, y: rect.midY - 14, width: 52, height: 28)
            GameStoneArt.drawSocket(in: context, frame: track, selected: false, pixel: 1)
            let thumb = CGRect(x: ghostEnabled ? track.maxX - 24 : track.minX + 4,
                y: track.minY + 4, width: 20, height: 20)
            GameStoneArt.draw(in: context, frame: thumb, selected: ghostEnabled, pixel: 1)
        }
        if let index = focusedIndex, layout.targets.indices.contains(index) {
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(2)
            context.stroke(layout.targets[index].insetBy(dx: 2, dy: 2))
        }
    }
}
