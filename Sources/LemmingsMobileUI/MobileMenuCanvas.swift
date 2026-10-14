#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import LemmingsTVCore
import UIKit

/// The artwork and UIKit targets share one layout, including disabled controls.
@MainActor final class MobileMenuCanvas: UIView {
    var page = GameFrontEnd.Page(title: L10n.text("Lemmings")) {
        didSet {
            if oldValue.title != page.title { focusedID = nil }
            rebuild()
        }
    }
    var playerName: String? { didSet { if oldValue != playerName { rebuild() } } }
    var playerRole = MobileTurnArt.Role.current { didSet { if oldValue != playerRole { rebuild() } } }
    var sessionName: String? { didSet { if oldValue != sessionName { rebuild() } } }
    private var displayedPage: GameFrontEnd.Page { MobileTurnArt.page(page, playerName: playerName, role: playerRole, sessionName: sessionName) }
    var preview: CGImage? { didSet { setNeedsDisplay() } }
    var resultStars: Int? { didSet { setNeedsDisplay() } }
    var revealedStars = 3 { didSet { setNeedsDisplay() } }
    var stampedStar: Int? { didSet { setNeedsDisplay() } }
    var previewSource: CGRect? { didSet { setNeedsDisplay() } }
    var onAction: ((String) -> Void)?
    var actionHelp: [String: String] = [:] {
        didSet {
            for button in targets {
                let id = button.accessibilityIdentifier?.replacingOccurrences(of: "menu.", with: "") ?? ""
                button.accessibilityHint = actionHelp[id]
            }
            if actionHelp[hoveredActionID ?? ""] == nil { hoveredActionID = nil }
            setNeedsDisplay()
        }
    }
    private(set) var hoveredActionID: String?
    var onPageChanged: (() -> Void)?
    private var targets: [UIButton] = []
    private var highlighted: String?
    var focusedID: String?
    private var pageLayout: GameFrontEnd.Layout?
    var requiresNeutralActivation = false
    private var tvActivation = TVActivationGate()
    func armTVActivation() { tvActivation.observeNeutral() }
    private static let portraits = Bundle.main.resourceURL.flatMap {
        GamePortraitArt(directory: $0.appendingPathComponent("MacArtwork/lemmings"))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        contentMode = .redraw
        #if os(iOS)
        addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hoverHelp(_:))))
        #endif
    }
    required init?(coder: NSCoder) { nil }

    #if os(iOS)
    @objc private func hoverHelp(_ gesture: UIHoverGestureRecognizer) {
        let point = gesture.location(in: self)
        hoveredActionID = [.began, .changed].contains(gesture.state) ? targets.first {
            $0.isEnabled && $0.frame.contains(point)
        }?.accessibilityIdentifier?.replacingOccurrences(of: "menu.", with: "") : nil
        setNeedsDisplay()
    }
    #endif

    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        let preferred = targets.first { $0.isEnabled && $0.accessibilityIdentifier == "menu." + (focusedID ?? "") }
        return preferred.map { [$0] } ?? Array(targets.filter(\.isEnabled).prefix(1))
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let button = context.nextFocusedView as? UIButton, targets.contains(button) else { return }
        focusedID = button.accessibilityIdentifier?.replacingOccurrences(of: "menu.", with: "")
        highlighted = focusedID
        (superview as? UIScrollView)?.scrollRectToVisible(button.frame.insetBy(dx: 0, dy: -8), animated: false)
        setNeedsDisplay()
    }
    #endif

    private func interfaceScale(width: CGFloat, viewportHeight: CGFloat? = nil) -> CGFloat {
        let setting = MobileSettings.current(from: .standard).classic.interfaceSize
        let height = viewportHeight ?? (superview as? UIScrollView)?.bounds.height ?? bounds.height
        #if os(tvOS)
        return page.pause != nil ? MobilePauseArt.interfaceScale(setting, width: width, height: height, television: true)
            : MobileSettingsArt.interfaceScale(setting, width: width, television: true)
        #else
        return page.pause != nil ? MobilePauseArt.interfaceScale(setting, width: width, height: height)
            : MobileSettingsArt.interfaceScale(setting, width: width)
        #endif
    }
    func size(width: CGFloat, minimumHeight: CGFloat) -> CGSize {
        let scale = interfaceScale(width: width, viewportHeight: minimumHeight)
        let size = GameFrontEnd.layout(displayedPage, width: width / scale, minimumHeight: minimumHeight / scale).size
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let page = displayedPage
        let scale = interfaceScale(width: bounds.width)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let minimumHeight = page.pause != nil ? (superview as? UIScrollView)?.bounds.height ?? bounds.height : bounds.height
        var layout = GameFrontEnd.layout(page, width: bounds.width / scale, minimumHeight: minimumHeight / scale)
        if page.pause != nil, let scroll = superview as? UIScrollView {
            layout = MobilePauseArt.pinningFooter(layout, viewport: CGRect(x: 0, y: scroll.contentOffset.y / scale,
                width: scroll.bounds.width / scale, height: scroll.bounds.height / scale))
        }
        pageLayout = layout
        let buttons = Dictionary(uniqueKeysWithValues: targets.compactMap { button in
            button.accessibilityIdentifier.map { ($0, button) }
        })
        targets = layout.targets.compactMap { target in
            guard let button = buttons["menu." + target.action.id] else { return nil }
            button.frame = target.frame.applying(transform)
            return button
        }
        var elements: [Any] = []
        for (text, frame) in [(page.title, layout.heading), (page.subtitle, layout.subtitle)] + Array(zip(page.details, layout.details)) where !text.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = text
            element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = frame.applying(transform)
            elements.append(element)
        }
        if page.home, !page.homeInitials.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = L10n.text("Active players: \(page.homeInitials)")
            element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = layout.initials.applying(transform)
            elements.append(element)
        }
        accessibilityElements = elements + targets
        setNeedsDisplay()
    }
    private func rebuild() {
        pageLayout = nil
        tvActivation.reset()
        onPageChanged?()
        let actions = page.rows + page.orderedFooter
        if !actions.contains(where: { $0.id == focusedID && $0.enabled }) {
            focusedID = actions.first(where: { $0.enabled && $0.title.uppercased() == L10n.text("CANCEL").uppercased() })?.id
                ?? actions.first(where: { $0.primary && $0.enabled })?.id
                ?? actions.first(where: \.enabled)?.id
        }
        highlighted = focusedID
        let existing = Dictionary(uniqueKeysWithValues: targets.compactMap { button in
            button.accessibilityIdentifier.map { ($0, button) }
        })
        let retained = Set(actions.map { "menu." + $0.id })
        targets.filter { !retained.contains($0.accessibilityIdentifier ?? "") }.forEach { $0.removeFromSuperview() }
        targets = (page.rows + page.orderedFooter).map { action in
            let identifier = "menu." + action.id
            let button = existing[identifier] ?? MobileFocusButton(type: .custom)
            button.accessibilityLabel = action.title
            button.accessibilityHint = actionHelp[action.id]
            button.accessibilityIdentifier = identifier
            button.accessibilityTraits = action.selected ? [.button, .selected] : .button
            button.isEnabled = action.enabled
            if existing[identifier] != nil { return button }
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                #if os(tvOS)
                guard !self.requiresNeutralActivation || self.tvActivation.consume() else { return }
                #endif
                self.onAction?(action.id)
            }, for: .gameActivation)
            button.addAction(UIAction { [weak self] _ in
                self?.highlighted = action.id; self?.setNeedsDisplay()
            }, for: .touchDown)
            button.addAction(UIAction { [weak self] _ in
                self?.highlighted = nil; self?.setNeedsDisplay()
            }, for: [.touchUpInside, .touchCancel, .touchUpOutside])
            addSubview(button)
            return button
        }
        setNeedsLayout()
        setNeedsDisplay()
        #if os(tvOS)
        setNeedsFocusUpdate()
        #endif
    }
    func moveFocus(_ offset: Int) {
        let enabled = (pageLayout?.targets.map(\.action) ?? (page.rows + page.orderedFooter)).filter(\.enabled)
        guard !enabled.isEmpty else { return }
        let current = enabled.firstIndex { $0.id == focusedID }
        let index = current.map { ($0 + offset + enabled.count) % enabled.count } ?? 0
        focusedID = enabled[index].id
        highlighted = focusedID
        if let scroll = superview as? UIScrollView,
           let target = targets.first(where: { $0.accessibilityIdentifier == "menu." + focusedID! }) {
            scroll.scrollRectToVisible(target.frame.insetBy(dx: 0, dy: -8), animated: false)
        }
        #if os(tvOS)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        #endif
        UIAccessibility.post(notification: .layoutChanged, argument: targets.first { $0.accessibilityIdentifier == "menu." + focusedID! })
        setNeedsDisplay()
    }
    func activateFocused() {
        let actions = page.rows + page.orderedFooter
        guard let action = actions.first(where: { $0.id == focusedID && $0.enabled })
                ?? actions.first(where: { $0.primary && $0.enabled }) else { return }
        onAction?(action.id)
    }
    func scrollInput(delta: CGFloat) {
        guard let scroll = superview as? UIScrollView else { return }
        let minimum = -scroll.adjustedContentInset.top
        let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: min(maximum, max(minimum, scroll.contentOffset.y + delta))), animated: false)
    }
    func goBack() {
        if let action = page.footer.last(where: { $0.enabled && $0.isBackNavigation }) {
            onAction?(action.id)
        }
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let page = displayedPage
        let scale = interfaceScale(width: bounds.width)
        context.saveGState()
        defer { context.restoreGState() }
        context.scaleBy(x: scale, y: scale)
        let layout = pageLayout ?? GameFrontEnd.layout(page, width: bounds.width / scale, minimumHeight: bounds.height / scale)
        guard let typography = MobileGameArt.typography else {
            MobilePixelText.draw(page.title, in: layout.heading, palette: .green)
            MobilePixelText.draw(page.subtitle, in: layout.subtitle)
            for target in layout.targets {
                GameStoneArt.draw(in: context, frame: target.frame, selected: target.action.primary, pixel: 1)
                MobilePixelText.draw(target.action.title, in: target.frame.insetBy(dx: 24, dy: 2))
            }
            return
        }
        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview,
                         previewSource: previewSource, highlighted: highlighted, portraits: Self.portraits, in: context)
        if let resultStars, !layout.preview.isEmpty {
            let preview = layout.preview
            let pixel: CGFloat = preview.width >= 400 ? 3 : 2
            let width = 3 * 11 * pixel + 2 * 8
            let origin = CGPoint(x: preview.midX - width / 2, y: preview.maxY - 9 * pixel - 10)
            context.setFillColor(CGColor(gray: 0, alpha: 0.8))
            context.fill(CGRect(x: origin.x - 6, y: origin.y - 6, width: width + 12, height: 9 * pixel + 12))
            for index in 0..<3 {
                let stamp = stampedStar == index + 1
                GameStarArt.draw(at: CGPoint(x: origin.x + CGFloat(index) * (11 * pixel + 8) - (stamp ? 2 : 0), y: origin.y - (stamp ? 2 : 0)),
                    earned: index < resultStars && index < revealedStars, size: pixel + (stamp ? 0.4 : 0), context: context)
            }
        }
        if let id = hoveredActionID, let detail = actionHelp[id],
           let target = layout.targets.first(where: { $0.action.id == id }) {
            let visible = (superview as? UIScrollView).map {
                CGRect(origin: $0.contentOffset, size: $0.bounds.size).applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            } ?? CGRect(origin: .zero, size: layout.size)
            let width = min(680, visible.width - 24)
            let height = GameTextLayout.height(detail, width: width - 48) + 48
            let above = target.frame.minY - height - 8
            let y = above >= visible.minY + 8 ? above : target.frame.maxY + 8
            let frame = CGRect(x: visible.midX - width / 2, y: y, width: width, height: height)
            GameStoneArt.draw(in: context, frame: frame, selected: false, pixel: 2)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(frame.insetBy(dx: 8, dy: 8))
            GameTextLayout.draw(detail, in: frame.insetBy(dx: 24, dy: 24), typography: typography, context: context)
        }
    }
}
#endif
