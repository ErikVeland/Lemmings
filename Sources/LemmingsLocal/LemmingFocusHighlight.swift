import AppKit

/// A pixel-aligned selection cue for a focused or hovered lemming.
@MainActor enum LemmingSelectionGlow {
    static func draw(at point: CGPoint, scale: CGFloat, radius: CGFloat = 7,
                     tint: NSColor, animated: Bool = true) {
        let pixel = max(1, floor(scale))
        let ringRadius = max(4 * pixel, floor(radius * scale / pixel) * pixel)
        let now = ProcessInfo.processInfo.systemUptime
        let phase = animated
            ? CGFloat(now.truncatingRemainder(dividingBy: 1.2) / 1.2)
            : 0.15

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = false

        let ring = NSBezierPath(ovalIn: pixelRect(around: point, radius: ringRadius))
        tint.withAlphaComponent(0.28).setStroke()
        ring.lineWidth = pixel
        ring.stroke()

        let shimmerStart = phase * 360
        let shimmer = NSBezierPath()
        shimmer.appendArc(withCenter: point, radius: ringRadius,
                          startAngle: shimmerStart, endAngle: shimmerStart + 28)
        tint.withAlphaComponent(animated ? 0.42 : 0.18).setStroke()
        shimmer.lineWidth = pixel
        shimmer.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func pixelRect(around point: CGPoint, radius: CGFloat) -> CGRect {
        let x = floor(point.x - radius) + 0.5
        let y = floor(point.y - radius) + 0.5
        let diameter = radius * 2
        return CGRect(x: x, y: y, width: diameter, height: diameter)
    }
}

@MainActor final class LemmingFocusHighlight {
    private var notice: String?
    private var noticeUntil: TimeInterval = 0
    func showNotice(_ text: String) { notice = text; noticeUntil = ProcessInfo.processInfo.systemUptime + 2 }
    func drawNotice() {
        guard let notice, ProcessInfo.processInfo.systemUptime < noticeUntil else { return }
        GameTypography.annotation(notice, at: CGPoint(x: 12, y: 12))
    }
    private var id: Int?
    private var until: TimeInterval = 0
    var target: Int? { ProcessInfo.processInfo.systemUptime < until ? id : nil }
    var reduceMotion = false
    func show(_ id: Int) { self.id = id; until = ProcessInfo.processInfo.systemUptime + 2 }
    func clear() { id = nil }
    func draw(at point: CGPoint, scale: CGFloat, tint: NSColor = .systemYellow, radius: CGFloat = 7) {
        guard target != nil else { return }
        LemmingSelectionGlow.draw(at: point, scale: scale, radius: radius,
                                  tint: tint, animated: !reduceMotion)
    }
}
