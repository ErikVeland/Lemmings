#if os(iOS) || os(tvOS)
import UIKit

extension UIControl.Event {
    static var gameActivation: UIControl.Event {
        #if os(tvOS)
        .primaryActionTriggered
        #else
        .touchUpInside
        #endif
    }
}

#if os(tvOS)
/// Focus decorates the exact bitmap target without stretching the shipped artwork.
@MainActor final class MobileFocusButton: UIButton {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        layer.borderWidth = isFocused ? 2 : 0
        layer.borderColor = UIColor.white.cgColor
        transform = .identity
    }
}
#else
typealias MobileFocusButton = UIButton
#endif
#endif
