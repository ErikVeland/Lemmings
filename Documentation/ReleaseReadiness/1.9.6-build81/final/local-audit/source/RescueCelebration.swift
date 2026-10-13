import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Rescue-target feedback shared by the three engines.
public enum RescueCelebration {
    public static func requiresAll(required: Int, total: Int) -> Bool {
        total > 0 && required >= total
    }

    public static func isSecured(saved: Int, required: Int, isComplete: Bool, didWin: Bool) -> Bool {
        if isComplete { return didWin }
        return required > 0 && saved >= required
    }

    #if canImport(CoreGraphics)
    /// A steady golden haze. Whole-pixel bands keep the playfield artwork crisp.
    public static func draw(in rect: CGRect, amount: CGFloat, context: CGContext) {
        let amount = min(1, max(0, amount)) * 0.3
        guard amount > 0, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.setBlendMode(.screen)
        let bands = max(4, min(20, Int(min(rect.width, rect.height) / 24)))
        for inset in 0..<bands {
            let falloff = 1 - CGFloat(inset) / CGFloat(bands)
            context.setStrokeColor(CGColor(srgbRed: 1, green: 0.73, blue: 0.22,
                                            alpha: amount * 0.34 * falloff * falloff))
            context.setLineWidth(1)
            context.stroke(rect.insetBy(dx: CGFloat(inset) + 0.5, dy: CGFloat(inset) + 0.5))
        }
    }
    #endif
}

/// A secured target stays lit, except an all-rescued level gets one brief glow.
@MainActor public final class RescueCelebrationTransition {
    nonisolated(unsafe) private var timer: Timer?
    private var active = false
    private var brief = false
    private var animated = true
    private var startedAt: TimeInterval = 0
    public private(set) var amount: CGFloat = 0
    public var onChange: ((CGFloat) -> Void)?
    public init() {}

    public func set(active: Bool, brief: Bool = false,
                    now: TimeInterval = ProcessInfo.processInfo.systemUptime, animated: Bool = true) {
        guard active else {
            guard self.active || amount > 0 else { return }
            self.active = false
            timer?.invalidate(); timer = nil
            amount = 0; onChange?(amount)
            return
        }
        if !self.active {
            self.active = true; self.brief = brief; self.animated = animated; startedAt = now
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advance(at: ProcessInfo.processInfo.systemUptime) }
            }
        }
        self.animated = animated
        advance(at: now)
    }

    public func advance(at now: TimeInterval) {
        guard active else { return }
        let elapsed = max(0, now - startedAt)
        func ease(_ value: Double) -> CGFloat {
            let p = min(1, max(0, value))
            return CGFloat(p * p * (3 - 2 * p))
        }
        if brief {
            amount = animated ? min(ease(elapsed / 0.35), ease((2.2 - elapsed) / 0.65)) : (elapsed < 1.5 ? 1 : 0)
        } else {
            amount = animated ? ease(elapsed / 1.4) : 1
        }
        onChange?(amount)
        if brief ? elapsed >= (animated ? 2.2 : 1.5) : amount == 1 {
            timer?.invalidate(); timer = nil
        }
    }

    deinit { timer?.invalidate() }
}
