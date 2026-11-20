#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsAppCore
import UIKit

/// Shipped Macintosh portraits and menu lettering, shared with the Mac app.
@MainActor enum MobileGameArt {
    private static var key = ""
    private static var cachedPortraits: GamePortraitArt?
    private static var cachedTypography: GameMenuTypography?
    static var revision: String { MobileLixArtwork.revision }
    private static func refresh() {
        guard key != revision else { return }
        key = revision
        cachedPortraits = GameResources.resourceURL.flatMap { GamePortraitArt(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
        cachedTypography = GameArtworkResources.menuInterface.map { GameMenuTypography(interface: $0) }
    }
    static var portraits: GamePortraitArt? { refresh(); return cachedPortraits }
    static var typography: GameMenuTypography? { refresh(); return cachedTypography }
}

@MainActor enum MobilePixelText {
    enum Palette {
        case blue, green, warning
        var colour: UIColor {
            switch self {
            case .blue: return UIColor(red: 0.20, green: 0.50, blue: 1, alpha: 1)
            case .green: return UIColor(red: 0.45, green: 1, blue: 0.10, alpha: 1)
            case .warning: return UIColor(red: 1, green: 0.42, blue: 0.12, alpha: 1)
            }
        }
    }
    static func draw(_ text: String, in rect: CGRect, palette: Palette = .blue,
                     maximumScale: CGFloat = 4, alignment: NSTextAlignment = .center,
                     face: GameMenuTypography.Face = .small, alpha: CGFloat = 1, bitmapOnly: Bool = false) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let displayedText = GamePresentationText.display(text)
        GamePixelTypography.draw(displayedText, in: rect, context: context, typography: MobileGameArt.typography,
                                 palette: palette == .blue ? .blue : palette == .green ? .green : .warning, maximumScale: maximumScale,
                                 alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                                 face: face, alpha: alpha, bitmapOnly: bitmapOnly || palette == .warning)
    }
}

@MainActor final class MobilePixelLabel: UIView {
    var text = "" { didSet { accessibilityLabel = GamePresentationText.display(text); setNeedsDisplay() } }
    var palette = MobilePixelText.Palette.blue { didSet { setNeedsDisplay() } }
    var alignment = NSTextAlignment.center { didSet { setNeedsDisplay() } }
    var maximumScale: CGFloat = 4 { didSet { setNeedsDisplay() } }
    var displayHeight: CGFloat? { didSet { setNeedsDisplay() } }
    var preservesCase = false { didSet { setNeedsDisplay() } }
    var face = GameMenuTypography.Face.small { didSet { setNeedsDisplay() } }
    var wraps = false { didSet { setNeedsDisplay() } }
    var numberOfLines = 1 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ rect: CGRect) {
        let displayedText = GamePresentationText.display(text)
        accessibilityLabel = displayedText
        let typography = MobileGameArt.typography
        if let displayHeight, let context = UIGraphicsGetCurrentContext(),
           GameLemmingsTypography.draw(displayedText, in: bounds, height: displayHeight,
            interface: typography?.interface, face: face,
            palette: palette == .blue ? .blue : palette == .warning ? .warning : .green,
            alignment: alignment == .left ? .left : alignment == .right ? .right : .center, context: context) {
            return
        } else if wraps, let context = UIGraphicsGetCurrentContext(), let typography {
            GameTextLayout.draw(displayedText, in: bounds, typography: typography, face: face,
                palette: palette == .blue ? .blue : .green,
                alignment: alignment == .left ? .left : alignment == .right ? .right : .center,
                preservesCase: preservesCase, context: context)
        } else if numberOfLines <= 1 {
            MobilePixelText.draw(displayedText, in: bounds, palette: palette,
                                 maximumScale: maximumScale, alignment: alignment, face: face)
        } else {
            if let context = UIGraphicsGetCurrentContext(), let typography,
               drawCompactParagraph(displayedText, typography: typography, context: context) { return }
            let lines = GamePixelTypography.lines(displayedText, width: bounds.width / max(1, maximumScale))
            let shown = lines.prefix(numberOfLines)
            let rowHeight = bounds.height / CGFloat(max(1, shown.count))
            for (index, line) in shown.enumerated() {
                MobilePixelText.draw(line, in: CGRect(x: bounds.minX, y: bounds.minY + CGFloat(index) * rowHeight,
                    width: bounds.width, height: rowHeight), palette: palette,
                    maximumScale: maximumScale, alignment: alignment, face: face)
            }
        }
    }

    /// Fits the complete caption to one bitmap size before drawing its lines.
    private func drawCompactParagraph(_ text: String, typography: GameMenuTypography, context: CGContext) -> Bool {
        let minimumHeight = 6
        guard let font = typography.font(face), font.cellHeight >= minimumHeight,
              bounds.width.isFinite, bounds.width > 0, bounds.height.isFinite, bounds.height >= CGFloat(minimumHeight) else { return false }
        let heightCap = max(CGFloat(minimumHeight), 12 * maximumScale)
        let maximumHeight = Int(min(CGFloat(font.cellHeight), bounds.height, heightCap))
        let nativePitch = GameTextLayout.linePitch(text, face: face, font: font)
        for height in stride(from: maximumHeight, through: minimumHeight, by: -1) {
            let scale = CGFloat(height) / CGFloat(font.cellHeight)
            let width = bounds.width / scale
            let pitch = nativePitch * scale
            let rowLimit = min(numberOfLines, Int(bounds.height / pitch))
            guard rowLimit > 0 else { continue }
            let wrapped = GameTextLayout.lines(text, width: width, face: face, font: font,
                                               preservesCase: preservesCase)
            if wrapped.count > rowLimit, height > minimumHeight { continue }

            var lines = Array(wrapped.prefix(rowLimit))
            if let last = lines.indices.last, wrapped.count > rowLimit {
                let remainder = wrapped.dropFirst(last).joined(separator: " ")
                lines[last] = GameTextLayout.truncated(remainder, width: width, face: face, font: font,
                                                       preservesCase: preservesCase)
            }
            let top = bounds.midY - CGFloat(lines.count) * pitch / 2
            let ink: GameLemmingsTypography.Ink = palette == .warning ? .warning : palette == .green ? .green : .blue
            let align: GameMenuTypography.Alignment = alignment == .left ? .left : alignment == .right ? .right : .center
            for (index, line) in lines.enumerated() {
                let row = CGRect(x: bounds.minX, y: top + CGFloat(index) * pitch, width: bounds.width, height: pitch)
                if !GameLemmingsTypography.draw(line, in: row, height: CGFloat(height), interface: typography.interface,
                                                face: face, palette: ink, alignment: align, preservesCase: preservesCase,
                                                context: context) {
                    MobilePixelText.draw(line, in: row, palette: palette, maximumScale: max(1, CGFloat(height) / 7),
                                         alignment: alignment, face: face)
                }
            }
            return true
        }
        return false
    }
}

@MainActor final class MobilePixelButton: UIControl {
    var title = "" { didSet { accessibilityLabel = GamePresentationText.display(title); setNeedsDisplay() } }
    var isPrimary = false { didSet { setNeedsDisplay() } }
    var isSelectedState = false { didSet { updateAccessibility(); setNeedsDisplay() } }
    var redNightVision = false { didSet { setNeedsDisplay() } }
    var icon: GameFrontEnd.Action.Icon? { didSet { setNeedsDisplay() } }
    var isToggle = false { didSet { updateAccessibility(); setNeedsDisplay() } }
    var onPress: (() -> Void)?
    private var hasFocusRing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(pressed), for: .touchUpInside)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { nil }

    @objc private func pressed() { onPress?() }

    override var canBecomeFocused: Bool { isEnabled && !isHidden && alpha > 0 }

    override var isEnabled: Bool { didSet { setNeedsDisplay() } }

    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        pressed()
        return true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        hasFocusRing = context.nextFocusedView === self
        setNeedsDisplay()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .select }), isEnabled { isHighlighted = true }
        else { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .select }), isEnabled {
            isHighlighted = false
            pressed()
        } else { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        isHighlighted = false
        super.pressesCancelled(presses, with: event)
    }

    private func updateAccessibility() {
        accessibilityTraits = isSelectedState ? [.button, .selected] : .button
        accessibilityValue = isToggle ? (isSelectedState ? "On" : "Off") : nil
    }

    override var isHighlighted: Bool {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer {
            if redNightVision {
                context.setBlendMode(.multiply)
                context.setFillColor(UIColor.red.cgColor)
                context.fill(bounds)
            }
            context.restoreGState()
        }
        context.setAlpha(isEnabled ? 1 : 0.45)
        let selected = isHighlighted || isSelectedState
        context.setShouldAntialias(false)
        let usesLix = MobileLixInterface.enabled && MobileLixInterface.button(in: bounds,
            selected: isSelectedState, pressed: isHighlighted, enabled: isEnabled)
        if !usesLix {
        context.setFillColor(UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1).cgColor)
        context.fill(bounds)
        let pixel = max(1, floor(min(bounds.width, bounds.height) / 24))
        let top = selected ? UIColor(white: 0.22, alpha: 1) : UIColor(white: 0.42, alpha: 1)
        let bottom = selected ? UIColor(white: 0.52, alpha: 1) : UIColor(white: 0.18, alpha: 1)
        context.setFillColor(top.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: pixel * 2))
        context.fill(CGRect(x: 0, y: 0, width: pixel * 2, height: bounds.height))
        context.setFillColor(bottom.cgColor)
        context.fill(CGRect(x: 0, y: bounds.height - pixel * 2, width: bounds.width, height: pixel * 2))
        context.fill(CGRect(x: bounds.width - pixel * 2, y: 0, width: pixel * 2, height: bounds.height))
        }
        let pixel = max(1, floor(min(bounds.width, bounds.height) / 24))
        if isPrimary || isSelectedState {
            context.setStrokeColor(MobilePixelText.Palette.green.colour.cgColor)
            context.setLineWidth(pixel)
            context.stroke(bounds.insetBy(dx: pixel * 3, dy: pixel * 3))
        }
        if icon == .favourite {
            GameStarArt.draw(in: bounds, earned: isSelectedState, context: context)
            return
        }
        var caption = bounds.insetBy(dx: 8, dy: 8)
        if isToggle {
            let size = min(24, bounds.height - 20)
            let checkbox = CGRect(x: 16, y: (bounds.height - size) / 2, width: size, height: size)
            if !usesLix || !MobileLixInterface.checkbox(checked: isSelectedState, in: checkbox, enabled: isEnabled) {
            context.setStrokeColor((isSelectedState ? MobilePixelText.Palette.green.colour
                : MobilePixelText.Palette.blue.colour).cgColor)
            context.setLineWidth(2)
            context.stroke(checkbox)
            if isSelectedState { MobilePixelText.draw("X", in: checkbox.insetBy(dx: 4, dy: 4), palette: .green) }
            }
            caption.origin.x = checkbox.maxX + 12
            caption.size.width = max(0, bounds.width - caption.minX - 12)
        }
        MobilePixelText.draw(title, in: caption,
                             palette: isPrimary || isSelectedState ? .green : .blue,
                             alignment: isToggle ? .left : .center)
        if hasFocusRing {
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(bounds.insetBy(dx: 4, dy: 4))
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
