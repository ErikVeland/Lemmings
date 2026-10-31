#if os(macOS)
import AppKit
import LemmingsGameArt

@MainActor enum LemmingSelectionGlow {
    static func draw(at point: CGPoint, scale: CGFloat, radius: CGFloat = 7,
                     tint: NSColor, animated: Bool = true, marker: Bool = true, direction: Int = 0, pulseTime: TimeInterval? = nil) {
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
        if marker { drawTargetMarker(at: point, pixel: pixel, direction: direction, animated: animated, pulseTime: pulseTime) }
    }

    /// A solid pointer stays visible when the soft halo meets bright terrain.
    private static func drawTargetMarker(at point: CGPoint, pixel: CGFloat, direction: Int, animated: Bool, pulseTime: TimeInterval?) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        LemmingSelectionRenderer.drawPlumbob(in: CGRect(
            x: floor(point.x / pixel) * pixel - 4 * pixel,
            y: floor(point.y / pixel) * pixel - 21 * pixel,
            width: 9 * pixel, height: 13 * pixel), direction: direction,
            time: animated ? (pulseTime ?? 0) : nil, context: context)
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
#endif
