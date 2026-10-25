#if os(iOS) || os(tvOS)
import LemmingsGameArt
import UIKit

/// Shipped Macintosh portraits and menu lettering, shared with the Mac app.
@MainActor enum MobileGameArt {
    static let portraits = Bundle.main.resourceURL.flatMap {
        GamePortraitArt(directory: $0.appendingPathComponent("MacArtwork/lemmings"))
    }
    static let typography: GameMenuTypography? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("MacArtwork/lemmings") else { return nil }
        return GameMenuTypography(directory: url)
    }()
}

@MainActor enum MobilePixelText {
    typealias Palette = GamePixelTypography.Palette
    static func draw(_ text: String, in rect: CGRect, palette: Palette = .blue,
                     maximumScale: CGFloat = 4, alignment: NSTextAlignment = .center,
                     face: GameMenuTypography.Face = .small, alpha: CGFloat = 1, bitmapOnly: Bool = false) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GamePixelTypography.draw(text, in: rect, context: context, typography: MobileGameArt.typography,
                                 palette: palette, maximumScale: maximumScale,
                                 alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                                 face: face, alpha: alpha, bitmapOnly: bitmapOnly)
    }
}

@MainActor final class MobilePixelLabel: UIView {
    var text = "" { didSet { accessibilityLabel = text; setNeedsDisplay() } }
    var preservesCase = false { didSet { setNeedsDisplay() } }
    var wraps = false { didSet { setNeedsDisplay() } }
    var palette = MobilePixelText.Palette.blue { didSet { setNeedsDisplay() } }
    var alignment = NSTextAlignment.center { didSet { setNeedsDisplay() } }
    var maximumScale: CGFloat = 4 { didSet { setNeedsDisplay() } }
    var face = GameMenuTypography.Face.small { didSet { setNeedsDisplay() } }
    var displayHeight: CGFloat? { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        if let displayHeight, let context = UIGraphicsGetCurrentContext(),
           GameLemmingsTypography.draw(text, in: bounds, height: displayHeight,
            interface: MobileGameArt.typography?.interface, face: face,
            palette: palette == .blue ? .blue : palette == .warning ? .warning : .green,
            alignment: alignment == .left ? .left : alignment == .right ? .right : .center, context: context) {
            // Display lettering uses the same size-specific face as the Mac and TV countdowns.
        } else if wraps, let context = UIGraphicsGetCurrentContext(), let typography = MobileGameArt.typography {
            GameTextLayout.draw(text, in: bounds, typography: typography, face: face,
                                palette: palette == .blue ? .blue : .green,
                                alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                                preservesCase: preservesCase, context: context)
        } else {
            MobilePixelText.draw(text, in: bounds, palette: palette,
                                 maximumScale: maximumScale, alignment: alignment, face: face)
        }
        accessibilityLabel = text
    }
}

@MainActor final class MobilePixelButton: UIControl {
    var title = "" { didSet { accessibilityLabel = title; setNeedsDisplay() } }
    var isPrimary = false { didSet { setNeedsDisplay() } }
    var isSelectedState = false { didSet { setNeedsDisplay() } }
    var redNightVision = false { didSet { setNeedsDisplay() } }
    var icon: GameFrontEnd.Action.Icon? { didSet { setNeedsDisplay() } }
    var onPress: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        contentMode = .redraw
        addTarget(self, action: #selector(pressed), for: .gameActivation)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    @objc private func pressed() { onPress?() }

    #if os(tvOS)
    override var canBecomeFocused: Bool { isEnabled && !isHidden }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        layer.borderWidth = isFocused ? 2 : 0
        layer.borderColor = UIColor.white.cgColor
        setNeedsDisplay()
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if isFocused && isEnabled && presses.contains(where: { $0.type == .select }) { onPress?(); return }
        super.pressesEnded(presses, with: event)
    }
    #endif

    override var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override var isEnabled: Bool {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let chosen = isEnabled && (isPrimary || isSelectedState || isHighlighted)
        GameStoneArt.draw(in: context, frame: bounds, selected: chosen, pixel: 1, shape: MobileSystemRegions.controlShape(in: self))
        if icon == .favourite {
            context.saveGState()
            context.setAlpha(isEnabled ? 1 : 0.45)
            GameStarArt.draw(in: bounds, earned: isSelectedState, context: context)
            context.restoreGState()
            return
        }
        MobilePixelText.draw(title, in: CGRect(x: 12, y: bounds.midY - 10, width: bounds.width - 24, height: 20),
                             palette: chosen ? .green : .blue, alpha: isEnabled ? 1 : 0.45)
        if redNightVision {
            context.saveGState()
            context.setBlendMode(.multiply)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(bounds)
            context.restoreGState()
        }
    }
}
/// The black page with the stone edging and moss cap the Mac menu pages use.
@MainActor final class MobileMenuBackdrop: UIView {
    var board = CGRect.zero { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !board.isEmpty else { return }
        GameMenuFrameArt.draw(in: context, board: board, shape: MobileSystemRegions.controlShape(in: self))
    }
}
#else
public enum LemmingsMobileUIUnavailable {}
#endif
