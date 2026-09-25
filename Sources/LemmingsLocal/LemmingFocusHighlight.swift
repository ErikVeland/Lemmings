import AppKit

/// A pixel-aligned selection cue for a focused or hovered lemming.
@MainActor enum LemmingSelectionGlow {
    static func draw(at point: CGPoint, scale: CGFloat, radius: CGFloat = 7,
                     tint: NSColor, animated: Bool = true) {
        let pixel = max(1, floor(scale))
        let haloRadius = max(4 * pixel, radius * scale * 0.7)
        let now = ProcessInfo.processInfo.systemUptime
        // Modulate brightness gently, without moving a ring around the sprite.
        let shimmer = animated ? 0.008 * sin(now * .pi) : 0
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = true
        if let halo = NSGradient(starting: tint.withAlphaComponent(0.055 + shimmer),
                                 ending: tint.withAlphaComponent(0)) {
            let rect = CGRect(x: point.x - haloRadius, y: point.y - haloRadius,
                              width: haloRadius * 2, height: haloRadius * 2)
            halo.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
        }
        NSGraphicsContext.restoreGraphicsState()
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
