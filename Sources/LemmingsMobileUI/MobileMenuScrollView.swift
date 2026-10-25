#if os(iOS) || os(tvOS)
import UIKit

/// A menu drag can take over after a button has started tracking the touch.
@MainActor class MobileMenuScrollView: UIScrollView {
    func setViewportFrame(_ frame: CGRect) {
        if self.frame != frame { cancelInteraction() }
        self.frame = frame
    }

    /// A moved viewport must not finish a drag or activate a control from its old position.
    func cancelInteraction() {
        func cancelControls(in view: UIView) {
            if let control = view as? UIControl {
                control.cancelTracking(with: nil)
                control.isHighlighted = false
            }
            view.subviews.forEach { cancelControls(in: $0) }
        }
        cancelControls(in: self)
        setContentOffset(contentOffset, animated: false)
        panGestureRecognizer.isEnabled = false
        panGestureRecognizer.isEnabled = true
    }

    #if os(iOS)
    override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIButton || super.touchesShouldCancel(in: view)
    }
    #endif
}
#endif
