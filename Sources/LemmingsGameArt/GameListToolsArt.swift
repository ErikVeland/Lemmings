import CoreGraphics
import NxlvKit

/// List tools use a fixed band. Search is a flat input well, distinct from destination buttons.
public enum GameListToolsArt {
    public static func layout(width: CGFloat, actions: [GameFrontEnd.Action], scale: CGFloat = 1) -> GameFrontEnd.Layout {
        let inset: CGFloat = 6, gap: CGFloat = 8
        let inner = max(0, width - inset * 2)
        let compact = width >= 620 * scale && actions.contains(where: { $0.id == "search" })
        let searchWidth = compact ? floor(inner * 0.4) : inner
        var y = inset
        var targets: [GameFrontEnd.Target] = []
        if let search = actions.first(where: { $0.id == "search" }) {
            let clear = actions.first { $0.id == "searchClear" }
            let clearWidth: CGFloat = clear == nil ? 0 : 44 * scale + 4
            targets.append(.init(action: search, frame: CGRect(x: inset, y: y, width: searchWidth - clearWidth, height: 44 * scale)))
            if let clear {
                targets.append(.init(action: clear, frame: CGRect(x: inset + searchWidth - 44 * scale, y: y, width: 44 * scale, height: 44 * scale)))
            }
            if !compact { y += 44 * scale + gap }
        }
        let commands = actions.filter { $0.id != "search" && $0.id != "searchClear" }
        if !commands.isEmpty {
            let commandWidth = compact ? inner - searchWidth - gap : inner
            let cell = (commandWidth - CGFloat(commands.count - 1) * gap) / CGFloat(commands.count)
            let height = max(44 * scale, commands.map { GameTextLayout.height($0.title, width: (cell - 24) / scale) * scale + 12 }.max() ?? 0)
            for (index, action) in commands.enumerated() {
                targets.append(.init(action: action, frame: CGRect(x: inset + (compact ? searchWidth + gap : 0) + CGFloat(index) * (cell + gap), y: y, width: cell, height: height)))
            }
            y += height + gap
        }
        if compact, commands.isEmpty { y += 44 * scale + gap }
        return .init(size: CGSize(width: width, height: targets.isEmpty ? 0 : y), board: .zero, heading: .zero,
            subtitle: .zero, preview: .zero, details: [], targets: targets)
    }

    public static func draw(_ layout: GameFrontEnd.Layout, typography: GameMenuTypography?,
                            highlighted: String? = nil, scale: CGFloat = 1, shape: GameControlShape = .square, in context: CGContext) {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: layout.size))
        for target in layout.targets {
            let frame = target.frame
            if target.action.id == "search" {
                context.setFillColor(CGColor(gray: 0.045, alpha: 1))
                shape.fill(frame, in: context)
                context.setStrokeColor(CGColor(gray: highlighted == "search" ? 1 : 0.48, alpha: 1))
                context.setLineWidth(1)
                shape.stroke(frame, inset: 0.5, in: context)
                let p = scale
                let origin = CGPoint(x: frame.minX + 12, y: frame.midY - 8 * p)
                context.setStrokeColor(CGColor(srgbRed: 0.35, green: 0.7, blue: 1, alpha: 1))
                context.setLineWidth(2 * p)
                context.stroke(CGRect(x: origin.x, y: origin.y, width: 10 * p, height: 10 * p))
                context.move(to: CGPoint(x: origin.x + 10 * p, y: origin.y + 10 * p))
                context.addLine(to: CGPoint(x: origin.x + 16 * p, y: origin.y + 16 * p))
                context.strokePath()
                let box = CGRect(x: frame.minX + 36 * p, y: frame.minY + 8,
                    width: max(0, frame.width - 48 * p), height: frame.height - 16)
                var caption = target.action.title
                while caption.count > 1 && GameTextLayout.width(of: caption) * scale > box.width { caption.removeFirst() }
                GamePixelTypography.draw(caption, in: box, context: context, typography: typography,
                    maximumScale: scale, alignment: .left)
            } else if target.action.id == "searchClear" {
                context.setStrokeColor(CGColor(gray: highlighted == "searchClear" ? 1 : 0.65, alpha: 1))
                context.setLineWidth(2 * scale)
                let box = frame.insetBy(dx: 15 * scale, dy: 15 * scale)
                context.move(to: CGPoint(x: box.minX, y: box.minY))
                context.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
                context.move(to: CGPoint(x: box.maxX, y: box.minY))
                context.addLine(to: CGPoint(x: box.minX, y: box.maxY))
                context.strokePath()
            } else {
                context.setFillColor(CGColor(gray: 0.025, alpha: 1))
                shape.fill(frame, in: context)
                context.setStrokeColor(CGColor(gray: 0.35, alpha: target.action.enabled ? 1 : 0.45))
                context.setLineWidth(1)
                shape.stroke(frame, inset: 0.5, in: context)
                context.saveGState()
                context.setAlpha(target.action.enabled ? 1 : 0.45)
                context.translateBy(x: frame.minX + 12, y: frame.minY + 6)
                context.scaleBy(x: scale, y: scale)
                let box = CGRect(x: 0, y: 0, width: (frame.width - 24) / scale, height: (frame.height - 12) / scale)
                if let typography {
                    GameTextLayout.draw(target.action.title, in: box, typography: typography, context: context)
                } else {
                    GamePixelTypography.draw(target.action.title, in: box, context: context, typography: nil, maximumScale: 1)
                }
                context.restoreGState()
                if target.action.id == highlighted {
                    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
                    context.setLineWidth(2)
                    shape.stroke(frame, inset: 3, in: context)
                }
            }
        }
    }
}
