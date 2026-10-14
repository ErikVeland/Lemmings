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
    /// A faint, single-pixel rim leaves the game artwork untouched.
    public static func draw(in rect: CGRect, amount: CGFloat, context: CGContext) {
        let amount = min(1, max(0, amount)) * 0.1
        guard amount > 0, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.setBlendMode(.normal)
        context.setStrokeColor(CGColor(srgbRed: 1, green: 0.73, blue: 0.22, alpha: amount))
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }
    #endif
}

/// Changes only on entry, reset or brief expiry, using the existing game clock.
@MainActor public final class RescueCelebrationTransition {
    private var active = false
    private var brief = false
    private var startedAt: TimeInterval = 0
    public private(set) var amount: CGFloat = 0
    public var onChange: ((CGFloat) -> Void)?
    public init() {}

    public func set(active: Bool, brief: Bool = false,
                    now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard active else {
            guard self.active || amount > 0 else { return }
            self.active = false
            updateAmount(0)
            return
        }
        if !self.active {
            self.active = true; self.brief = brief; startedAt = now
        }
        advance(at: now)
    }

    public func advance(at now: TimeInterval) {
        guard active else { return }
        let elapsed = max(0, now - startedAt)
        updateAmount(brief && elapsed >= 1.5 ? 0 : 1)
    }

    private func updateAmount(_ next: CGFloat) {
        guard amount != next else { return }
        amount = next; onChange?(amount)
    }
}
