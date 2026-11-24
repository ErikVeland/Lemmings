import CoreGraphics
import NxlvKit

/// Geometry and arrows of the speed control that sits beside the skill sockets.
public enum SpeedPanelArt {
    public static func selectionPage(_ speed: GameplaySpeed) -> GameFrontEnd.Page {
        let rows = speed.selectableSteps.map { tier in
            GameFrontEnd.Action(String(Int(tier)), "\(Int(tier))×", selected: tier == speed.target)
        }
        return .init(title: L10n.text("Speed"), rows: rows, footer: [.init("back", L10n.text("Back"))])
    }

    /// -1 for the left arrow, 1 for the right arrow and 0 for the label between them.
    public static func part(at point: CGPoint, in rect: CGRect) -> Int? {
        guard rect.contains(point) else { return nil }
        if point.x < rect.minX + rect.width * 0.22 { return -1 }
        if point.x >= rect.maxX - rect.width * 0.22 { return 1 }
        return 0
    }

    /// The left arrow, label and right arrow boxes.
    public static func boxes(in rect: CGRect) -> [CGRect] {
        let side = rect.width * 0.22
        return [CGRect(x: rect.minX, y: rect.minY, width: side, height: rect.height),
                CGRect(x: rect.minX + side, y: rect.minY, width: rect.width - 2 * side, height: rect.height),
                CGRect(x: rect.maxX - side, y: rect.minY, width: side, height: rect.height)]
    }

    /// The pixel size of the stone bevel and the label inset for a given box height.
    public static func pixel(forHeight height: CGFloat) -> CGFloat { max(1, floor(height / 24)) }

    /// Leave space above the multiplier for the forward transport mark on tall sockets.
    public static func multiplierBox(in box: CGRect, context: CGContext, monochrome: Bool = false) -> CGRect {
        guard box.height >= 28, box.width >= 18 else { return box }
        let pixel = max(1, floor(min(box.width / 20, box.height / 25)))
        let top = floor(box.minY + 2 * pixel)
        let left = floor(box.midX - 4 * pixel)
        context.saveGState()
        context.setShouldAntialias(false)
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1) : CGColor(srgbRed: 0.8, green: 0.9, blue: 0.68, alpha: 1))
        for column in 0..<3 {
            let inset = CGFloat(column) * pixel
            for offset in [CGFloat(0), 4 * pixel] {
                context.fill(CGRect(x: left + offset + inset, y: top + inset, width: pixel, height: 5 * pixel - 2 * inset))
            }
        }
        context.restoreGState()
        let labelY = top + 6 * pixel
        return CGRect(x: box.minX, y: labelY, width: box.width, height: box.maxY - labelY)
    }

    public static func drawArrow(in context: CGContext, box: CGRect, pointsRight: Bool, monochrome: Bool = false) {
        let step = max(1, floor(min(box.width / 8, box.height / 12)))
        let rows = pointsRight ? ["#..", ".#.", "..#", ".#.", "#.."] : ["..#", ".#.", "#..", ".#.", "..#"]
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(monochrome ? CGColor(gray: 1, alpha: 1) : CGColor(srgbRed: 0.8007, green: 0.8956, blue: 0.6815, alpha: 1))
        for (y, row) in rows.enumerated() {
            for (x, mark) in row.enumerated() where mark == "#" {
                context.fill(CGRect(x: floor(box.midX - 1.5 * step) + CGFloat(x) * step,
                                    y: floor(box.midY - 2.5 * step) + CGFloat(y) * step, width: step, height: step))
            }
        }
    }
}
