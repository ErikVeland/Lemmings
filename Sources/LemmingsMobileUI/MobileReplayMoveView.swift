#if os(iOS) || os(tvOS)
import LemmingsGameArt
import NxlvKit
import UIKit

@MainActor final class MobileReplayMoveView: UIView {
    var onMove: ((Int) -> Void)?
    private var buttons: [UIButton] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        for (index, title) in [L10n.text("Previous move"), L10n.text("Next move")].enumerated() {
            let button = MobileFocusButton(type: .custom)
            button.accessibilityLabel = title
            button.accessibilityIdentifier = "solutionMove." + String(index)
            button.addAction(UIAction { [weak self] _ in self?.onMove?(index == 0 ? -1 : 1) }, for: .gameActivation)
            addSubview(button); buttons.append(button)
        }
        isHidden = true
    }
    required init?(coder: NSCoder) { nil }
    func update(previous: Bool, next: Bool) {
        guard buttons[0].isEnabled != previous || buttons[1].isEnabled != next else { return }
        buttons[0].isEnabled = previous; buttons[1].isEnabled = next
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        for (button, frame) in zip(buttons, SolutionSwitchArt.frames(in: bounds)) { button.frame = frame }
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        ReplayMoveArt.draw(previous: buttons[0].isEnabled, next: buttons[1].isEnabled, in: bounds,
            typography: MobileGameArt.typography, context: context)
    }
}
#endif
