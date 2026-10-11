import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Rescue-target feedback shared by the three engines.
public enum RescueCelebration {
    public static func isSecured(saved: Int, required: Int, isComplete: Bool, didWin: Bool) -> Bool {
        if isComplete { return didWin }
        return required > 0 && saved >= required
    }

    #if canImport(CoreGraphics)
    /// A steady golden rim. Whole-pixel bands keep the playfield artwork crisp.
    public static func draw(in rect: CGRect, amount: CGFloat, context: CGContext) {
        let amount = min(1, max(0, amount))
        guard amount > 0, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.setShouldAntialias(false)
        context.setBlendMode(.screen)
        let bands = max(4, min(16, Int(min(rect.width, rect.height) / 28)))
        for inset in 0..<bands {
            let falloff = 1 - CGFloat(inset) / CGFloat(bands)
            context.setStrokeColor(CGColor(srgbRed: 1, green: 0.73, blue: 0.22,
                                            alpha: amount * 0.22 * falloff * falloff))
            context.setLineWidth(1)
            context.stroke(rect.insetBy(dx: CGFloat(inset) + 0.5, dy: CGFloat(inset) + 0.5))
        }
    }
    #endif
}
