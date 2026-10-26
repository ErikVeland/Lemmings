#if os(iOS) || os(tvOS)
import UIKit
import LemmingsGameArt
import NxlvKit

@MainActor final class MobileListToolsView: UIView {
    var actions: [GameFrontEnd.Action] = [] { didSet { if oldValue != actions { rebuild() } } }
    var onAction: ((String) -> Void)?
    var searchQuery = "" {
        didSet { buttons.first { $0.accessibilityIdentifier == "listTools.search" }?.accessibilityValue = searchQuery.isEmpty ? nil : searchQuery }
    }
    var focusedID: String? { didSet { setNeedsDisplay() } }
    private var buttons: [UIButton] = []
    private var scale: CGFloat {
        #if os(tvOS)
        2
        #else
        1
        #endif
    }
    var toolsLayout: GameFrontEnd.Layout { GameListToolsArt.layout(width: bounds.width, actions: actions, scale: scale) }
    var shelfHeight: CGFloat { toolsLayout.size.height }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { nil }
    func activate(_ id: String) {
        guard !isHidden, actions.contains(where: { $0.id == id && $0.enabled }) else { return }
        onAction?(id)
    }
    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = actions.map { action in
            let button = UIButton(type: .custom)
            button.accessibilityIdentifier = "listTools." + action.id
            button.accessibilityLabel = action.id == "search" ? L10n.text("Search")
                : action.id == "searchClear" ? L10n.text("Clear") + ": " + L10n.text("Search") : action.title
            button.accessibilityValue = action.id == "search" && !searchQuery.isEmpty ? searchQuery : nil
            button.accessibilityTraits = action.id == "search" ? .searchField : .button
            button.isEnabled = action.enabled
            button.addAction(UIAction { [weak self] _ in self?.activate(action.id) }, for: .gameActivation)
            addSubview(button)
            return button
        }
        accessibilityElements = buttons
        setNeedsLayout()
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        for (button, target) in zip(buttons, toolsLayout.targets) { button.frame = target.frame }
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        GameListToolsArt.draw(toolsLayout, typography: MobileGameArt.typography, highlighted: focusedID, scale: scale, shape: MobileSystemRegions.controlShape(in: self), in: context)
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        buttons.filter { $0.accessibilityIdentifier == "listTools." + (focusedID ?? "") }
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if let button = context.nextFocusedView as? UIButton, buttons.contains(button) {
            focusedID = button.accessibilityIdentifier?.replacingOccurrences(of: "listTools.", with: "")
        }
    }
    #endif
}
#endif
