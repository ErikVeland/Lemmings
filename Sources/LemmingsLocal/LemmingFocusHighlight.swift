import AppKit

@MainActor enum LemmingSelectionGlow {
    static func draw(at point: CGPoint, scale: CGFloat, radius: CGFloat = 7,
                     tint: NSColor, animated: Bool = true) {
        let pixel = max(1, floor(scale))
        let haloRadius = max(8 * pixel, radius * scale * 1.3)
        let alpha = haloAlpha(at: ProcessInfo.processInfo.systemUptime, animated: animated)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = true
        if let shadow = NSGradient(starting: NSColor.black.withAlphaComponent(0.34),
                                   ending: NSColor.black.withAlphaComponent(0)) {
            let shadowRadius = haloRadius * 1.25
            let rect = CGRect(x: point.x - shadowRadius, y: point.y - shadowRadius,
                              width: shadowRadius * 2, height: shadowRadius * 2)
            shadow.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
        }
        if let halo = NSGradient(starting: tint.withAlphaComponent(alpha),
                                 ending: tint.withAlphaComponent(0)) {
            let rect = CGRect(x: point.x - haloRadius, y: point.y - haloRadius,
                              width: haloRadius * 2, height: haloRadius * 2)
            halo.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
        }
        NSGraphicsContext.restoreGraphicsState()
        drawTargetMarker(at: point, pixel: pixel, tint: tint)
    }

    /// A solid pointer stays visible when the soft halo meets bright terrain.
    private static func drawTargetMarker(at point: CGPoint, pixel: CGFloat, tint: NSColor) {
        let x = floor(point.x / pixel) * pixel
        let y = floor(point.y / pixel) * pixel - 15 * pixel
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = false
        NSColor.black.setFill()
        CGRect(x: x - 4 * pixel, y: y, width: 8 * pixel, height: 3 * pixel).fill()
        CGRect(x: x - 3 * pixel, y: y + 3 * pixel, width: 6 * pixel, height: pixel).fill()
        CGRect(x: x - 2 * pixel, y: y + 4 * pixel, width: 4 * pixel, height: pixel).fill()
        CGRect(x: x - pixel, y: y + 5 * pixel, width: 2 * pixel, height: pixel).fill()
        tint.setFill()
        CGRect(x: x - 3 * pixel, y: y + pixel, width: 6 * pixel, height: 2 * pixel).fill()
        CGRect(x: x - 2 * pixel, y: y + 3 * pixel, width: 4 * pixel, height: pixel).fill()
        CGRect(x: x - pixel, y: y + 4 * pixel, width: 2 * pixel, height: pixel).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The halo's centre opacity. The shimmer modulates brightness only; the
    /// halo never moves. Reduced motion (`animated == false`) keeps it static.
    static func haloAlpha(at now: TimeInterval, animated: Bool) -> CGFloat {
        let base: CGFloat = 0.62
        let shimmer: CGFloat = animated ? 0.06 * sin(now * .pi) : 0
        return base + shimmer
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
    func show(_ id: Int) { self.id = id; until = ProcessInfo.processInfo.systemUptime + 2 }
    func clear() { id = nil }
}
