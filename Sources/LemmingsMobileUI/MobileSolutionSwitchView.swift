#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsTVCore
import NxlvKit
import UIKit

@MainActor final class MobileSolutionSwitchView: UIView {
    var mode = SolutionReplayMode.game { didSet { updateSelection() } }
    var onSelect: ((SolutionReplayMode) -> Void)?
    var focusedMode: SolutionReplayMode?
    private var buttons: [UIButton] = []
    private var activation = TVActivationGate()
    func observeNeutral() { activation.observeNeutral() }
    func resetActivation() { activation.reset() }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        for value in SolutionReplayMode.allCases {
            let button = MobileFocusButton(type: .custom)
            button.accessibilityLabel = value == .game ? "Your game" : "Solution"
            button.accessibilityIdentifier = "solutionSwitch." + value.rawValue
            button.addAction(UIAction { [weak self] _ in self?.activate(value) }, for: .gameActivation)
            addSubview(button); buttons.append(button)
        }
        isHidden = true
        updateSelection()
    }
    required init?(coder: NSCoder) { nil }
    func activate(_ value: SolutionReplayMode) {
        #if os(tvOS)
        guard activation.consume() else { return }
        #endif
        onSelect?(value)
    }
    private func updateSelection() {
        for (value, button) in zip(SolutionReplayMode.allCases, buttons) {
            button.accessibilityTraits = value == mode ? [.button, .selected] : .button
        }
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        for (button, frame) in zip(buttons, SolutionSwitchArt.frames(in: bounds)) { button.frame = frame }
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        [buttons[focusedMode == .game ? 0 : 1]]
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let index = buttons.firstIndex(where: { $0 === context.nextFocusedView }) {
            focusedMode = SolutionReplayMode.allCases[index]
        } else { focusedMode = nil }
        setNeedsDisplay()
    }
    #endif
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        SolutionSwitchArt.draw(mode: mode, focused: focusedMode, in: bounds,
            typography: MobileGameArt.typography, context: context)
    }
}
#endif
