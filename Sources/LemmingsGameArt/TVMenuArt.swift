import CoreGraphics
import Foundation

/// Television pages use the shipped lettering and stone artwork at whole-pixel scales.
public enum TVMenuArt {
    public static let size = CGSize(width: 864, height: 480)
    public struct Target {
        public let action: GameFrontEnd.Action
        public let frame: CGRect
    }
    public struct Layout {
        public let board: CGRect
        public let heading: CGRect
        public let subtitle: CGRect
        public let preview: CGRect
        public let details: [CGRect]
        public let targets: [Target]
    }
    public static func layout(_ page: GameFrontEnd.Page) -> Layout {
        let preview = page.preview ? CGRect(x: 40, y: 142, width: 320, height: 192) : .zero
        let x: CGFloat = page.preview ? 392 : 104
        let width: CGFloat = page.preview ? 432 : 656
        var targets = page.rows.enumerated().map { index, action in
            Target(action: action, frame: CGRect(x: x, y: 130 + CGFloat(index) * (page.preview ? 88 : 54), width: width, height: page.preview ? 82 : 46))
        }
        let grid = GameFooterGrid(actions: page.orderedFooter, columns: page.footer.count)
        let gap: CGFloat = 12
        let cell = (784 - CGFloat(grid.columns - 1) * gap) / CGFloat(grid.columns)
        targets += grid.slots.map { slot in
            Target(action: slot.action, frame: CGRect(x: 40 + CGFloat(slot.column) * (cell + gap), y: 406, width: cell, height: 48))
        }
        let details = page.details.enumerated().map { index, _ in
            CGRect(x: page.preview ? 40 : 60, y: (page.preview ? 346 : 138) + CGFloat(index) * (page.preview ? 28 : 30),
                   width: page.preview ? 320 : 744, height: 24)
        }
        return Layout(board: CGRect(x: 16, y: 16, width: 832, height: 448),
            heading: CGRect(x: 40, y: 32, width: 784, height: 62),
            subtitle: CGRect(x: 40, y: 96, width: 784, height: 26),
            preview: preview, details: details, targets: targets)
    }

    public static func draw(_ page: GameFrontEnd.Page, focused: String? = nil,
                            preview: CGImage? = nil, typography: GameMenuTypography? = nil,
                            portraits: GamePortraitArt? = nil, textScale: CGFloat = 1,
                            in context: CGContext) {
        let layout = layout(page)
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
        GameMenuFrameArt.draw(in: context, board: layout.board)
        if page.home, let image = typography?.menuLogo {
            let size = GameMenuLogo.logicalSize(of: image)
            let frame = GameMenuLogo.frame(canvasSize: size,
                originalWidth: typography?.interface.logo.map { CGFloat($0.width) } ?? size.width,
                in: layout.heading, wholeNumberScale: false)
            GameStoneArt.drawImage(image, in: frame, context: context)
        } else { text(page.title, box: layout.heading, title: true, green: true, typography: typography, context: context) }
        if let typography, !page.subtitleRuns.isEmpty {
            GameSemanticText.draw(page.subtitleRuns, in: layout.subtitle, typography: typography, context: context)
        } else { text(page.subtitle, box: layout.subtitle, typography: typography, context: context) }
        if page.preview {
            GameDisplayArt.draw(in: context, frame: layout.preview, pixel: 2)
            if let preview { fitted(preview, in: layout.preview.insetBy(dx: 10, dy: 10), context: context) }
        }
        for (index, pair) in zip(page.details, layout.details).enumerated() {
            text(pair.0, box: pair.1, reading: page.readsDetail(index), typography: typography, context: context)
        }
        for target in layout.targets {
            let action = target.action
            GameStoneArt.draw(in: context, frame: target.frame, selected: action.selected, pixel: 1)
            if action.primary && action.enabled {
                context.setStrokeColor(CGColor(srgbRed: 0.55, green: 0.85, blue: 0.25, alpha: 1))
                context.setLineWidth(2); context.stroke(target.frame.insetBy(dx: 1, dy: 1))
                text(">", box: CGRect(x: target.frame.maxX - 28, y: target.frame.midY - 11, width: 20, height: 22), green: true, typography: typography, context: context)
            }
            if focused == action.id && action.enabled {
                context.setStrokeColor(CGColor(gray: 1, alpha: 1)); context.setLineWidth(2)
                context.stroke(target.frame.insetBy(dx: -3, dy: -3))
            }
            if action.selected {
                context.setFillColor(CGColor(srgbRed: 0.55, green: 0.85, blue: 0.25, alpha: 1))
                context.fill(CGRect(x: target.frame.minX + 12, y: target.frame.maxY - 6, width: target.frame.width - 24, height: 2))
            }
            if let portrait = action.portrait { portraits?.draw(portrait, in: CGRect(x: target.frame.minX + 8, y: target.frame.midY - 19, width: 38, height: 38), context: context) }
            let inset: CGFloat = action.portrait == nil ? 32 : 52
            let box = CGRect(x: target.frame.minX + inset, y: target.frame.minY + 5,
                width: target.frame.width - inset - 32, height: target.frame.height - 10)
            if let game = action.gameLogo, let image = typography?.homeLogos.image(game) {
                context.saveGState(); context.setAlpha(action.enabled ? 1 : 0.45)
                fitted(image, in: target.frame.insetBy(dx: 24, dy: 8), context: context)
                context.restoreGState()
            } else if let typography, !action.titleRuns.isEmpty {
                GameSemanticText.draw(action.titleRuns, in: box, typography: typography,
                    alpha: action.enabled ? 1 : 0.45, context: context)
            } else if page.preview, textScale > 1, let separator = action.title.range(of: " - ") {
                // The action and owner have distinct hierarchy, with uniform lettering for peer rows.
                text(String(action.title[..<separator.lowerBound]), box: CGRect(x: box.minX, y: box.minY, width: box.width, height: 38),
                     green: false, enabled: action.enabled,
                     typography: typography, textScale: textScale, context: context)
                text(String(action.title[separator.upperBound...]), box: CGRect(x: box.minX, y: box.maxY - 28, width: box.width, height: 28),
                     green: true, enabled: action.enabled,
                     typography: typography, context: context)
            } else { text(action.title, box: box,
                green: action.portrait != nil,
                enabled: action.enabled, typography: typography, textScale: textScale, context: context) }
        }
    }

    public static func text(_ value: String, box: CGRect, title: Bool = false, green: Bool = false,
                            enabled: Bool = true, reading: Bool = false, typography: GameMenuTypography? = nil,
                            textScale: CGFloat = 1, context: CGContext) {
        // Scale the original bitmap face uniformly; labels never expand individually to fill sockets.
        context.saveGState(); defer { context.restoreGState() }
        context.clip(to: box)
        if let typography {
            let face: GameMenuTypography.Face = title ? .large : .small
            let scale = textScale > 1 ? 2 : 1
            let height = typography.height(of: value, face: face, scale: scale)
            typography.menuLine(value, in: CGRect(x: box.minX, y: floor(box.midY - height / 2), width: box.width, height: height),
                context: context, face: face, scale: scale, alignment: reading ? .left : .center,
                alpha: enabled ? 1 : 0.4, palette: green ? .green : .blue, preservesCase: reading)
        } else {
            GamePixelTypography.draw(value, in: box, context: context, typography: nil,
                palette: green ? .green : .blue, maximumScale: title ? 4 : 2,
                alpha: enabled ? 1 : 0.4, bitmapOnly: true)
        }
    }

    private static func fitted(_ image: CGImage, in box: CGRect, context: CGContext) {
        let scale = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        let size = CGSize(width: floor(CGFloat(image.width) * scale), height: floor(CGFloat(image.height) * scale))
        GameStoneArt.drawImage(image, in: CGRect(x: floor(box.midX - size.width / 2), y: floor(box.midY - size.height / 2), width: size.width, height: size.height), context: context)
    }
}
