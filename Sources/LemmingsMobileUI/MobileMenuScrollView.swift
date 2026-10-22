#if os(iOS) || os(tvOS)
import UIKit

/// A menu drag can take over after a button has started tracking the touch.
@MainActor class MobileMenuScrollView: UIScrollView {
    #if os(iOS)
    override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIButton || super.touchesShouldCancel(in: view)
    }
    #endif
}
#endif
