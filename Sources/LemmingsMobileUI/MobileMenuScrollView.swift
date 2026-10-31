#if os(iOS) || os(tvOS)
import UIKit

/// A menu drag can take over after a button has started tracking the touch.
@MainActor class MobileMenuScrollView: UIScrollView {
    var unobscuredInsets = UIEdgeInsets.zero
    var onViewportChange: (() -> Void)?
    private var lastViewportOrigin = CGPoint.zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard lastViewportOrigin != bounds.origin else { return }
        lastViewportOrigin = bounds.origin
        onViewportChange?()
    }

    func reveal(_ rect: CGRect) {
        let visibleTop = contentOffset.y + unobscuredInsets.top
        let visibleBottom = contentOffset.y + bounds.height - unobscuredInsets.bottom
        var offset = contentOffset.y
        if rect.minY < visibleTop { offset -= visibleTop - rect.minY }
        else if rect.maxY > visibleBottom { offset += rect.maxY - visibleBottom }
        let minimum = -adjustedContentInset.top
        let maximum = max(minimum, contentSize.height - bounds.height + adjustedContentInset.bottom)
        setContentOffset(CGPoint(x: contentOffset.x, y: min(maximum, max(minimum, offset))), animated: false)
    }

    func setViewportFrame(_ frame: CGRect) {
        guard self.frame != frame else { return }
        cancelInteraction()
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
