#if os(iOS) || os(tvOS)
import UIKit
import LemmingsGameArt

/**
 * A fixed tab shelf shares the game's bitmap controls and selection state.
 */
@MainActor final class MobileSettingsTabsView: UIView {
    var onAction: ((String) -> Void)?
    var tabs: [GameFrontEnd.Action] = [] {
        didSet { if tabs != oldValue { rebuild() } }
    }
    var actions: [GameFrontEnd.Action] { isHidden || !isUserInteractionEnabled ? [] : tabs }
    var focusedID: String? { didSet { updateSelection(); setNeedsLayout() } }
    private let scroll = UIScrollView()
    private var buttons: [MobilePixelButton] = []

    override var isUserInteractionEnabled: Bool {
        didSet { buttons.forEach { $0.isEnabled = isUserInteractionEnabled } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isHidden = true
        scroll.showsHorizontalScrollIndicator = true
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        addSubview(scroll)
    }
    required init?(coder: NSCoder) { nil }

    func height(for width: CGFloat) -> CGFloat { layout(width: width).size.height }

    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        let id = focusedID ?? tabs.first(where: { $0.selected })?.id
        return buttons.filter { $0.accessibilityIdentifier == id }
    }
    #endif

    func activate(_ id: String) {
        guard actions.contains(where: { $0.id == id && $0.enabled }) else { return }
        onAction?(id)
    }

    private func layout(width: CGFloat) -> GameFrontEnd.Layout {
        #if os(tvOS)
        MobileSettingsTabsArt.layout(width: width, actions: tabs, television: true)
        #else
        MobileSettingsTabsArt.layout(width: width, actions: tabs)
        #endif
    }

    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = tabs.map { action in
            let button = MobilePixelButton()
            button.title = action.title
            button.accessibilityIdentifier = action.id
            button.isEnabled = isUserInteractionEnabled && action.enabled
            button.onPress = { [weak self] in self?.activate(action.id) }
            scroll.addSubview(button)
            return button
        }
        updateSelection()
        setNeedsLayout()
    }

    private func updateSelection() {
        for (button, action) in zip(buttons, tabs) {
            button.isSelectedState = action.selected
            button.accessibilityTraits = action.selected ? [.button, .selected] : .button
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = action.id == focusedID ? 2 : 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        let layout = layout(width: bounds.width)
        scroll.contentSize = layout.size
        for (button, target) in zip(buttons, layout.targets) { button.frame = target.frame }
        if let target = layout.targets.first(where: { $0.action.id == focusedID || focusedID == nil && $0.action.selected }) {
            scroll.scrollRectToVisible(target.frame.insetBy(dx: -6, dy: 0), animated: false)
        }
    }
}
#endif
