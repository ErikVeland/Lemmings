#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

/// Shows how far back rewind has gone and how fast it is travelling.
/// Speed is separate from forward play speed: chevrons count rewind presses, not the 1×–10× tiers.
/// The view keeps one width for every value, so the label never shifts as it counts.
@MainActor final class MobileRewindCueView: UIView {
    var cue: RewindCue? {
        didSet {
            guard cue != oldValue else { return }
            isHidden = cue == nil
            accessibilityLabel = cue?.accessibilityLabel
            if let cue, cue.speed != oldValue?.speed || oldValue == nil {
                UIAccessibility.post(notification: .announcement, argument: cue.accessibilityLabel)
            }
            setNeedsDisplay()
        }
    }
    /// Whole bitmap scale: 2 on wide or TV screens, 1 on phones.
    var pixelScale: CGFloat = 1 { didSet { if pixelScale != oldValue { invalidateIntrinsicContentSize(); setNeedsDisplay() } } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isHidden = true
        isAccessibilityElement = true
        accessibilityTraits = [.updatesFrequently]
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize {
        CGSize(width: CGFloat(GamePixelTypography.width(of: RewindCue.widestText) + 8) * pixelScale,
               height: 20 * pixelScale)
    }

    override func draw(_ rect: CGRect) {
        guard let cue, let context = UIGraphicsGetCurrentContext() else { return }
        let scale = pixelScale
        let text = CGRect(x: 4 * scale, y: 0, width: bounds.width - 8 * scale, height: 11 * scale)
        GamePixelTypography.draw(cue.text, in: text, context: context, typography: nil,
            palette: .blue, maximumScale: scale, alignment: .left, bitmapOnly: true)
        // The rail places the shown moment between the level start and where rewind began.
        let rail = CGRect(x: 4 * scale, y: 14 * scale, width: bounds.width - 8 * scale, height: max(1, scale))
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 1, alpha: 0.3))
        context.fill(rail)
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 1, alpha: 0.9))
        context.fill(CGRect(x: floor(rail.minX + rail.width * cue.position - scale), y: rail.minY - scale,
                            width: 2 * scale, height: rail.height + 2 * scale))
    }
}
#endif
