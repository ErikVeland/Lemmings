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
            pendingReflowAnchor = nil
            if oldValue.title != page.title { focusedID = nil; televisionPageIndex = 0 }
            globalNavigation?.showsBack = page.backAction != nil
            globalNavigation?.backTitle = page.backAction?.title ?? L10n.text("Back")
            rebuild()
        }
    }
    var playerName: String? { didSet { if oldValue != playerName { rebuild() } } }
    var playerRole = MobileTurnArt.Role.current { didSet { if oldValue != playerRole { rebuild() } } }
    var sessionName: String? { didSet { if oldValue != sessionName { rebuild() } } }
    private var televisionPageIndex = 0
    private var measuredViewport = CGSize.zero
    private var pendingReflowAnchor: (id: String, offset: CGFloat)?
    private var televisionViewport = CGSize.zero
    private var televisionScaleCache: (page: GameFrontEnd.Page, width: CGFloat, height: CGFloat, preferred: CGFloat, scale: CGFloat)?
    private var displayedPage: GameFrontEnd.Page {
        var result = page.home && boxesHome ? page
            : MobileTurnArt.page(page, playerName: playerName, role: playerRole, sessionName: sessionName)
        if !result.listTools.isEmpty, globalNavigation?.isHidden == false, globalNavigation?.showsBack == true {
            result.footer.removeAll { $0.isBackNavigation }
        }
        #if os(tvOS)
        if result.home { result = TVMenuPresentation.homePage(result) }
        if result.televisionGrid, televisionViewport.width > 0 {
            let scale = interfaceScale(width: televisionViewport.width, viewportHeight: televisionViewport.height)
            result = TVMenuPresentation.settingsPage(result, index: televisionPageIndex,
                width: televisionViewport.width / scale, height: televisionViewport.height / scale)
        }
        #endif
        return result
    }
    var splitResult = false
    var fitsSupportPage = false {
        didSet { if fitsSupportPage != oldValue { rebuild() } }
    }
    var boxesHome = false {
        didSet { if boxesHome != oldValue { setNeedsLayout(); setNeedsDisplay() } }
    }
    var bookHomePanes: [CGRect] = [] {
        didSet {
            guard bookHomePanes != oldValue else { return }
            (superview as? MobileMenuScrollView)?.cancelInteraction()
            pageLayout = nil
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    private func layoutPage(_ page: GameFrontEnd.Page, width: CGFloat, minimumHeight: CGFloat, scale: CGFloat) -> GameFrontEnd.Layout {
        #if os(tvOS)
        if page.home { return TVMenuPresentation.homeLayout(page, width: width, height: minimumHeight) }
        if page.pause != nil {
            return MobilePauseArt.layout(page, width: width, minimumHeight: minimumHeight, television: true)
        }
        #endif
        let panes = bookHomePanes.map { $0.applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)) }
        return GameFrontEnd.layout(page, width: width, minimumHeight: minimumHeight,
                                   boxedHome: boxesHome, bookHomePanes: panes, fillsResultPane: splitResult)
    }
    var preview: CGImage? { didSet { setNeedsDisplay() } }
    var resultStars: Int? { didSet { setNeedsDisplay() } }
    var revealedStars = 3 { didSet { setNeedsDisplay() } }
    var stampedStar: Int? { didSet { setNeedsDisplay() } }
    var previewSource: CGRect? { didSet { setNeedsDisplay() } }
    var onAction: ((String) -> Void)?
    var onHoldAction: ((String) -> Void)?
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
    weak var globalNavigation: MobileNavigationView?
    weak var listTools: MobileListToolsView?
    var focusableActions: [GameFrontEnd.Action] {
        ((globalNavigation?.actions ?? []) + (listTools?.isHidden == false ? listTools?.actions ?? [] : [])
            + (pageLayout?.targets.map(\.action) ?? (displayedPage.rows + displayedPage.orderedFooter))).filter(\.enabled)
    }
    var focusedID: String? {
        didSet { globalNavigation?.focusedID = focusedID; listTools?.focusedID = focusedID }
    }
    private var pageLayout: GameFrontEnd.Layout?
    var requiresNeutralActivation = false
    private var tvActivation = TVActivationGate()
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
        if globalNavigation?.actions.contains(where: { $0.id == focusedID }) == true, let globalNavigation { return [globalNavigation] }
        if listTools?.isHidden == false, listTools?.actions.contains(where: { $0.id == focusedID }) == true, let listTools { return [listTools] }
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
        if fitsSupportPage {
            #if os(tvOS)
            let preferred = MobileSettingsArt.interfaceScale(setting, width: width, television: true)
            #else
            let preferred = MobileSettingsArt.interfaceScale(setting, width: width)
            #endif
            let source = MobileTurnArt.page(page, playerName: playerName, role: playerRole, sessionName: sessionName)
            return GameSupport.fittedScale(preferred, page: source, width: width, height: height)
        }
        #if os(tvOS)
        if page.home {
            return televisionScale(MobileSettingsArt.interfaceScale(setting, width: width, television: true),
                page: TVMenuPresentation.homePage(page), width: width, height: height)
        }
        if page.televisionGrid {
            let preferred = MobileSettingsArt.interfaceScale(setting, width: width, television: true)
            let source = MobileTurnArt.page(page, playerName: playerName, role: playerRole, sessionName: sessionName)
            return televisionScale(preferred, page: source, width: width, height: height)
        }
        return page.pause != nil ? MobilePauseArt.interfaceScale(setting, width: width, height: height, television: true)
            : MobileSettingsArt.interfaceScale(setting, width: width, television: true)
        #else
        if splitResult, page.result {
            return MobileResultAchievementsArt.resultScale(MobileSettingsArt.interfaceScale(setting, width: width),
                page: displayedPage, width: width, height: height)
        }
        return page.pause != nil ? MobilePauseArt.interfaceScale(setting, width: width, height: height)
            : MobileSettingsArt.interfaceScale(setting, width: width)
        #endif
    }
    #if os(tvOS)
    private func televisionScale(_ preferred: CGFloat, page: GameFrontEnd.Page, width: CGFloat, height: CGFloat) -> CGFloat {
        if let cached = televisionScaleCache, cached.page == page, cached.width == width,
           cached.height == height, cached.preferred == preferred { return cached.scale }
        let scale = page.home ? TVMenuPresentation.homeScale(preferred, page: page, width: width, height: height)
            : TVMenuPresentation.settingsScale(preferred, page: page, width: width, height: height)
        televisionScaleCache = (page, width, height, preferred, scale)
        return scale
    }
    #endif
    func size(width: CGFloat, minimumHeight: CGFloat) -> CGSize {
        let measured = CGSize(width: width, height: minimumHeight)
        if measuredViewport != measured {
            if measuredViewport.width > 0, measuredViewport.width != width,
               !page.home, page.pause == nil, !page.rows.isEmpty,
               let scroll = superview as? UIScrollView {
                let visible = CGRect(origin: scroll.contentOffset, size: measuredViewport)
                if let anchor = targets.first(where: { $0.frame.width > 0 && $0.frame.intersects(visible) }) {
                    pendingReflowAnchor = (anchor.accessibilityIdentifier ?? "", anchor.frame.minY - visible.minY)
                }
            }
            measuredViewport = measured
            pageLayout = nil
            setNeedsLayout()
            setNeedsDisplay()
        }
        #if os(tvOS)
        let viewport = CGSize(width: width, height: minimumHeight)
        if televisionViewport != viewport {
            televisionViewport = viewport
            if page.televisionGrid { rebuild() }
        }
        #endif
        let scale = interfaceScale(width: width, viewportHeight: minimumHeight)
        let size = layoutPage(displayedPage, width: width / scale, minimumHeight: minimumHeight / scale, scale: scale).size
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let page = displayedPage
        let scale = interfaceScale(width: bounds.width)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let minimumHeight = (superview as? UIScrollView)?.bounds.height
            ?? (measuredViewport.height > 0 ? measuredViewport.height : bounds.height)
        var layout = layoutPage(page, width: bounds.width / scale, minimumHeight: minimumHeight / scale, scale: scale)
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
        if let anchor = pendingReflowAnchor, let scroll = superview as? UIScrollView {
            pendingReflowAnchor = nil
            if let target = targets.first(where: { $0.accessibilityIdentifier == anchor.id }) {
                let maximum = max(0, scroll.contentSize.height - scroll.bounds.height)
                scroll.setContentOffset(CGPoint(x: 0, y: min(maximum, max(0, target.frame.minY - anchor.offset))), animated: false)
            }
        }
        var elements: [Any] = []
        for (text, frame) in [(page.title, layout.heading), (page.subtitle, layout.subtitle)] + Array(zip(page.details, layout.details)) where !text.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = text
            if let items = page.achievementItems,
               let index = page.details.indices.first(where: { page.details[$0] == text }), index % 2 == 0,
               let star = items[index / 2].star {
                element.accessibilityValue = star == 2 ? L10n.text("Unknown") : star == 1 ? L10n.text("Earned") : L10n.text("Not earned")
            }
            element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = frame.applying(transform)
            elements.append(element)
        }
        if page.home, !page.homeInitials.isEmpty {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = page.homeNextPlayerName.map {
                L10n.text("Active players: \(page.homeInitials). Next: \($0)")
            } ?? L10n.text("Active players: \(page.homeInitials)")
            element.accessibilityTraits = .staticText
            element.accessibilityFrameInContainerSpace = layout.initials.applying(transform)
            elements.append(element)
        }
        if let heading = layout.libraryHeading {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = L10n.text("Levels")
            element.accessibilityTraits = .header
            element.accessibilityFrameInContainerSpace = heading.applying(transform)
            elements.append(element)
        }
        if page.home, bookHomePanes.count == 2 {
            let rightEdge = bookHomePanes[1].minX
            let positioned = elements.compactMap { element -> (element: Any, frame: CGRect)? in
                guard let item = element as? UIAccessibilityElement else { return nil }
                return (item, item.accessibilityFrameInContainerSpace)
            } + targets.map { (element: $0 as Any, frame: $0.frame) }
            accessibilityElements = positioned.sorted {
                let a = $0.frame.midX >= rightEdge ? 1 : 0
                let b = $1.frame.midX >= rightEdge ? 1 : 0
                return a == b ? $0.frame.minY < $1.frame.minY : a < b
            }.map(\.element)
        } else { accessibilityElements = elements + targets }
        setNeedsDisplay()
    }
    private func rebuild() {
        pageLayout = nil
        tvActivation.reset()
        onPageChanged?()
        let page = displayedPage
        if page.televisionGrid { televisionPageIndex = page.televisionPageIndex }
        let actions = page.rows + page.orderedFooter
        let available = actions + page.listTools + (globalNavigation?.actions ?? [])
        if !available.contains(where: { $0.id == focusedID && $0.enabled }) {
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
            button.accessibilityValue = action.toggleValue.map { $0 ? L10n.text("On") : L10n.text("Off") }
            button.accessibilityTraits = action.selected ? [.button, .selected] : .button
            button.isEnabled = action.enabled
            #if os(tvOS)
            if let focusButton = button as? MobileFocusButton {
                focusButton.onSelectBegan = { [weak self] in self?.tvActivation.observeSelectBegan() }
                focusButton.onHold = action.id.hasPrefix("player.") ? { [weak self] in
                    guard let self, !self.requiresNeutralActivation || self.tvActivation.consume() else { return }
                    self.onHoldAction?(action.id)
                } : nil
                if focusButton.onHold != nil {
                    button.accessibilityHint = L10n.text("Hold to edit player")
                    button.accessibilityCustomActions = [UIAccessibilityCustomAction(name: L10n.text("Edit player")) { [weak self] _ in
                        self?.onHoldAction?(action.id); return true
                    }]
                } else { button.accessibilityCustomActions = nil }
            }
            #endif
            if existing[identifier] != nil { return button }
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                #if os(tvOS)
                guard !self.requiresNeutralActivation || self.tvActivation.consume() else { return }
                #endif
                self.dispatch(action.id)
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
        let enabled = focusableActions
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
    func focusAction(_ id: String) {
        guard focusableActions.contains(where: { $0.id == id }) else { return }
        focusedID = id; highlighted = id
        #if os(tvOS)
        setNeedsFocusUpdate()
        #endif
        setNeedsDisplay()
    }
    func activateFocused() {
        if let focusedID, globalNavigation?.actions.contains(where: { $0.id == focusedID }) == true {
            globalNavigation?.activate(focusedID)
            return
        }
        if let focusedID, listTools?.isHidden == false, listTools?.actions.contains(where: { $0.id == focusedID }) == true {
            listTools?.activate(focusedID)
            return
        }
        let page = displayedPage
        let actions = page.rows + page.orderedFooter
        guard let action = actions.first(where: { $0.id == focusedID && $0.enabled })
                ?? actions.first(where: { $0.primary && $0.enabled }) else { return }
        dispatch(action.id)
    }
    private func dispatch(_ id: String) {
        #if os(tvOS)
        if id == TVMenuPresentation.previousID || id == TVMenuPresentation.nextID {
            televisionPageIndex = max(0, televisionPageIndex + (id == TVMenuPresentation.nextID ? 1 : -1))
            focusedID = id
            rebuild()
            setNeedsFocusUpdate()
            return
        }
        #endif
        onAction?(id)
    }
    func scrollInput(delta: CGFloat) {
        guard let scroll = superview as? UIScrollView else { return }
        let minimum = -scroll.adjustedContentInset.top
        let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: min(maximum, max(minimum, scroll.contentOffset.y + delta))), animated: false)
    }
    func goBack() {
        if let action = page.backAction {
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
        let layout = pageLayout ?? layoutPage(page, width: bounds.width / scale, minimumHeight: ((superview as? UIScrollView)?.bounds.height
            ?? (measuredViewport.height > 0 ? measuredViewport.height : bounds.height)) / scale, scale: scale)
        guard let typography = MobileGameArt.typography else {
            MobilePixelText.draw(page.title, in: layout.heading, palette: .green)
            MobilePixelText.draw(page.subtitle, in: layout.subtitle)
            if let heading = layout.libraryHeading { MobilePixelText.draw(L10n.text("Levels"), in: heading, palette: .green) }
            for target in layout.targets where !target.frame.isEmpty {
                GameStoneArt.draw(in: context, frame: target.frame, selected: target.action.primary, pixel: 1)
                MobilePixelText.draw(target.action.title, in: target.frame.insetBy(dx: 24, dy: 2))
                if target.action.selected {
                    context.setFillColor(CGColor(srgbRed: 0.45, green: 1, blue: 0.10, alpha: 1))
                    context.fill(CGRect(x: target.frame.minX + 16, y: target.frame.maxY - 5,
                                        width: max(0, target.frame.width - 32), height: 2))
                }
            }
            return
        }
        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview,
                         previewSource: previewSource, highlighted: highlighted, portraits: Self.portraits, fillsCanvas: !(page.home && boxesHome), in: context)
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
            GameDisplayArt.draw(in: context, frame: frame, pixel: 2)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(frame.insetBy(dx: 8, dy: 8))
            GameTextLayout.draw(detail, in: frame.insetBy(dx: 24, dy: 24), typography: typography, alignment: .left, context: context)
        }
    }
}
#endif
