#if os(tvOS)
import LemmingsGameArt
import LemmingsAppCore
import NxlvKit
import UIKit

@MainActor enum TVArtwork {
    private static var key = ""
    private static var cachedTypography: GameMenuTypography?
    private static var cachedPortraits: GamePortraitArt?
    static var revision: String { MobileLixArtwork.revision }
    static var directory: URL? { GameResources.resourceURL?.appendingPathComponent("MacArtwork/lemmings") }
    private static func refresh() {
        guard key != revision else { return }
        key = revision
        cachedTypography = GameArtworkResources.menuInterface.map { GameMenuTypography(interface: $0) }
        cachedPortraits = directory.flatMap { GamePortraitArt(directory: $0) }
    }
    static var typography: GameMenuTypography? { refresh(); return cachedTypography }
    static var portraits: GamePortraitArt? { refresh(); return cachedPortraits }
}

/// Focusable native targets sit over the same rectangles used by the bitmap renderer.
@MainActor final class TVMenuView: UIView {
    var page = GameFrontEnd.Page(title: L10n.text("Ultimate Lemmings")) { didSet { rebuild() } }
    var preview: CGImage? { didSet { setNeedsDisplay() } }
    var textScale: CGFloat = 1 { didSet { setNeedsDisplay() } }
    var onAction: ((String) -> Void)?
    var preferredActionID: String?
    private var buttons: [UIButton] = []
    private var focusedID: String?
    private var initialFocus: String?
    private var activationArmed = false
    private var generation = 0

    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .black; isOpaque = true; contentMode = .redraw
    }
    required init?(coder: NSCoder) { nil }

    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        if let button = buttons.first(where: { $0.accessibilityIdentifier == "tv.menu." + (initialFocus ?? "") && $0.isEnabled }) { return [button] }
        return buttons.filter(\.isEnabled).prefix(1).map { $0 }
    }

    private var scale: CGFloat { max(1, floor(min(bounds.width / TVMenuArt.size.width, bounds.height / TVMenuArt.size.height))) }
    private var origin: CGPoint { CGPoint(x: floor((bounds.width - TVMenuArt.size.width * scale) / 2), y: floor((bounds.height - TVMenuArt.size.height * scale) / 2)) }

    func armActivation() { activationArmed = true }

    private func rebuild() {
        generation += 1
        activationArmed = false
        buttons.forEach { $0.removeFromSuperview() }
        initialFocus = (page.rows + page.orderedFooter).first(where: { $0.primary && $0.enabled })?.id
            ?? preferredActionID
            ?? (page.rows + page.orderedFooter).first(where: \.enabled)?.id
        focusedID = initialFocus
        let ticket = generation
        buttons = TVMenuArt.layout(page).targets.map { target in
            let button = UIButton(type: .custom)
            switch target.action.id {
            case "previous", "previousSkills": button.accessibilityLabel = L10n.text("Previous page")
            case "more", "moreSkills", "playerMore", "rosterMore": button.accessibilityLabel = L10n.text("Next page")
            default: button.accessibilityLabel = target.action.title.replacingOccurrences(of: "*", with: "unlimited")
            }
            button.accessibilityIdentifier = "tv.menu." + target.action.id
            button.isEnabled = target.action.enabled
            button.accessibilityTraits = target.action.selected ? [.button, .selected] : .button
            if !target.action.enabled { button.accessibilityTraits.insert(.notEnabled) }
            button.addAction(UIAction { [weak self] _ in
                guard let self, self.generation == ticket, self.activationArmed else { return }
                self.activationArmed = false
                self.onAction?(target.action.id)
            }, for: .primaryActionTriggered)
            addSubview(button); return button
        }
        setNeedsLayout(); setNeedsDisplay(); setNeedsFocusUpdate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let transform = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
        let layout = TVMenuArt.layout(page)
        for (button, target) in zip(buttons, layout.targets) { button.frame = target.frame.applying(transform) }
        var elements: [Any] = []
        for (text, box) in [(page.title, layout.heading), (page.subtitle, layout.subtitle)] + Array(zip(page.details, layout.details)) where !text.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = GamePresentationText.display(text); element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = box.applying(transform); elements.append(element)
        }
        accessibilityElements = elements + buttons
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let button = context.nextFocusedView as? UIButton, buttons.contains(button) else { return }
        focusedID = button.accessibilityIdentifier?.replacingOccurrences(of: "tv.menu.", with: "")
        initialFocus = focusedID
        // Native focus ownership with a pixel outline avoids stretching or filtering artwork.
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState(); defer { context.restoreGState() }
        context.translateBy(x: origin.x, y: origin.y); context.scaleBy(x: scale, y: scale)
        TVMenuArt.draw(page, focused: focusedID, preview: preview, typography: TVArtwork.typography,
            portraits: TVArtwork.portraits, textScale: textScale, in: context)
    }
}
#endif
