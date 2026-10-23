#if os(iOS) || os(tvOS)
import UIKit
import LemmingsGameArt
import NxlvKit

/// Global destinations stay visible while the menu beneath them scrolls.
@MainActor final class MobileNavigationView: UIView {
    var onHome: (() -> Void)?
    var onBack: (() -> Void)?
    var showsBack = false { didSet { if oldValue != showsBack { rebuild() } } }
    var backTitle = L10n.text("Back") { didSet { if oldValue != backTitle { rebuild() } } }
    var onSecondary: (() -> Void)?
    override var isUserInteractionEnabled: Bool {
        didSet { buttons.forEach { $0.isEnabled = isUserInteractionEnabled } }
    }
    var secondaryTitle: String? { didSet { if oldValue != secondaryTitle { rebuild() } } }
    private var buttons: [MobilePixelButton] = []
    var focusedID: String? {
        didSet { for button in buttons { button.isSelectedState = button.accessibilityIdentifier == focusedID } }
    }
    var actions: [GameFrontEnd.Action] {
        isHidden || !isUserInteractionEnabled ? [] : GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle)
    }
    func activate(_ id: String) {
        guard actions.contains(where: { $0.id == id }) else { return }
        if id == "navigation.back" { onBack?() }
        else if id == "navigation.home" { onHome?() } else { onSecondary?() }
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        buttons.filter { $0.accessibilityIdentifier == focusedID }
    }
    #endif
    var shelfHeight: CGFloat { navigationLayout.size.height }
    func height(for width: CGFloat) -> CGFloat {
        #if os(tvOS)
        GameNavigationArt.layout(width: width, actions: GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle), television: true).size.height
        #else
        GameNavigationArt.layout(width: width, actions: GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle)).size.height
        #endif
    }
    private var navigationLayout: GameFrontEnd.Layout {
        #if os(tvOS)
        GameNavigationArt.layout(width: bounds.width, actions: GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle), television: true)
        #else
        GameNavigationArt.layout(width: bounds.width, actions: GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle))
        #endif
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        rebuild()
    }
    required init?(coder: NSCoder) { nil }
    private func rebuild() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = GameNavigationArt.actions(back: showsBack, backTitle: backTitle, secondary: secondaryTitle).map { action in
            let button = MobilePixelButton()
            button.title = action.title
            button.accessibilityIdentifier = action.id
            button.isEnabled = isUserInteractionEnabled
            button.isSelectedState = action.id == focusedID
            button.onPress = { [weak self] in
                guard let self, self.isUserInteractionEnabled else { return }
                self.activate(action.id)
            }
            addSubview(button)
            return button
        }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        for (button, target) in zip(buttons, navigationLayout.targets) { button.frame = target.frame }
    }
}
#endif
