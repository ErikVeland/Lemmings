import AppKit

/// A pixel-aligned selection cue for a focused or hovered lemming.
@MainActor enum LemmingSelectionGlow {
    static func draw(at point: CGPoint, scale: CGFloat, radius: CGFloat = 10,
                     tint: NSColor, animated: Bool = true) {
        let pixel = max(1, floor(scale))
        let outerRadius = max(6 * pixel, floor(radius * scale / pixel) * pixel)
        let innerRadius = max(4 * pixel, outerRadius - 2 * pixel)
        let now = ProcessInfo.processInfo.systemUptime
        let phase = animated
            ? CGFloat(now.truncatingRemainder(dividingBy: 1.2) / 1.2)
            : 0.15

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = false

        let outer = pixelRect(around: point, radius: outerRadius)
        let inner = pixelRect(around: point, radius: innerRadius)
        tint.withAlphaComponent(0.12).setStroke()
        let outerRing = NSBezierPath(ovalIn: outer)
        outerRing.lineWidth = 2 * pixel
        outerRing.stroke()

        tint.withAlphaComponent(0.28).setStroke()
        let innerRing = NSBezierPath(ovalIn: inner)
        innerRing.lineWidth = pixel
        innerRing.stroke()

        let shimmerStart = phase * 360
        for index in 0..<3 {
            let start = shimmerStart + CGFloat(index) * 120
            let shimmer = NSBezierPath()
            shimmer.appendArc(withCenter: point, radius: outerRadius,
                              startAngle: start, endAngle: start + 22)
            tint.withAlphaComponent(index == 0 ? 0.72 : 0.28).setStroke()
            shimmer.lineWidth = pixel
            shimmer.stroke()
        }

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
    func draw(at point: CGPoint, scale: CGFloat, tint: NSColor = .systemYellow, radius: CGFloat = 10) {
        guard target != nil else { return }
        LemmingSelectionGlow.draw(at: point, scale: scale, radius: radius,
                                  tint: tint, animated: !reduceMotion)
    }
}
