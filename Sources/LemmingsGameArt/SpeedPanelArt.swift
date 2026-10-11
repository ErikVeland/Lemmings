import CoreGraphics

/// Geometry and arrows of the speed control that sits beside the skill sockets.
public enum SpeedPanelArt {
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

    public static func drawArrow(in context: CGContext, box: CGRect, pointsRight: Bool) {
        let step = max(1, floor(min(box.width / 8, box.height / 12)))
        let rows = pointsRight ? ["#..", ".#.", "..#", ".#.", "#.."] : ["..#", ".#.", "#..", ".#.", "..#"]
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(srgbRed: 0.8007, green: 0.8956, blue: 0.6815, alpha: 1))
        for (y, row) in rows.enumerated() {
            for (x, mark) in row.enumerated() where mark == "#" {
                context.fill(CGRect(x: floor(box.midX - 1.5 * step) + CGFloat(x) * step,
                                    y: floor(box.midY - 2.5 * step) + CGFloat(y) * step, width: step, height: step))
            }
        }
    }
}
