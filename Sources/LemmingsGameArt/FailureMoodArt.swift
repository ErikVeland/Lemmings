import CoreGraphics

/// Apply the funeral mood to gameplay pixels, not to a transparent sibling layer.
public enum FailureMoodArt {
    public static func saturation(_ amount: CGFloat) -> Float { Float(1 - 0.72 * clamped(amount)) }
    public static func brightness(_ amount: CGFloat) -> Float { Float(1 - 0.26 * clamped(amount)) }

    public static func draw(in rect: CGRect, amount: CGFloat, context: CGContext) {
        let amount = clamped(amount)
        guard amount > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setBlendMode(.color)
        context.setFillColor(CGColor(gray: 0.28, alpha: 0.72 * amount))
        context.fill(rect)
        context.setBlendMode(.normal)
        context.setFillColor(CGColor(gray: 0, alpha: 0.26 * amount))
        context.fill(rect)
    }

    private static func clamped(_ amount: CGFloat) -> CGFloat {
        amount.isFinite ? min(1, max(0, amount)) : 0
    }
}
