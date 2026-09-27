import AppKit

/// A short assignment acknowledgement clipped to the lemming sprite.
@MainActor final class LemmingAssignmentPulse {
    static let duration: TimeInterval = 0.22

    private(set) var target: Int?
    private(set) var startedAt: TimeInterval = 0

    var isActive: Bool {
        target != nil && ProcessInfo.processInfo.systemUptime - startedAt < Self.duration
    }

    var remaining: TimeInterval {
        max(0, Self.duration - (ProcessInfo.processInfo.systemUptime - startedAt))
    }

    func show(_ id: Int) {
        target = id
        startedAt = ProcessInfo.processInfo.systemUptime
    }

    func clear() {
        target = nil
    }

    func draw(sprite: CGImage, in rect: CGRect, scale: CGFloat,
              reduceMotion: Bool, reduceFlashes: Bool = false,
              tint: NSColor = .systemGreen) {
        guard isActive, rect.width > 0, rect.height > 0,
              let context = NSGraphicsContext.current?.cgContext else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let progress = min(1, max(0, elapsed / Self.duration))
        let attack = min(1, 0.18 + progress / 0.18 * 0.82)
        let envelope = CGFloat(min(attack, (1 - progress) / 0.22, 1))
        let pixel = max(1, floor(scale))

        context.saveGState()
        context.interpolationQuality = .none
        context.clip(to: rect, mask: sprite)

        tint.withAlphaComponent((reduceFlashes ? 0.08 : 0.12) * envelope).setFill()
        rect.fill()

        if !reduceMotion {
            let sweepX = rect.minX + rect.width * CGFloat(progress)
            let sweepWidth = max(pixel, floor(rect.width * 0.12 / pixel) * pixel)
            tint.withAlphaComponent((reduceFlashes ? 0.18 : 0.38) * envelope).setFill()
            CGRect(x: sweepX - sweepWidth / 2, y: rect.minY,
                   width: sweepWidth, height: rect.height).fill()

            NSColor.white.withAlphaComponent((reduceFlashes ? 0 : 0.50) * envelope).setFill()
            CGRect(x: floor(sweepX / pixel) * pixel, y: rect.minY,
                   width: pixel, height: rect.height).fill()
        }
        context.restoreGState()
    }
}
