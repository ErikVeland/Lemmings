#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsTVCore
import NxlvKit
import UIKit

@MainActor final class MobileSolutionSwitchView: UIView {
    var mode = SolutionReplayMode.game { didSet { updateSelection() } }
    var showsGhost = false { didSet { ghostButton.isHidden = !showsGhost; setNeedsLayout(); setNeedsDisplay() } }
    var ghostEnabled = false { didSet { updateSelection() } }
    var onToggleGhost: (() -> Void)?
    var focusedGhost = false
    var focusedIndex: Int? {
        get { focusedGhost ? 2 : focusedMode.map { $0 == .game ? 0 : 1 } }
        set { focusedGhost = newValue == 2; focusedMode = newValue == 0 ? .game : newValue == 1 ? .solution : nil }
    }
    private let ghostButton = MobileFocusButton(type: .custom)
    private var switchFrame: CGRect { CGRect(x: 0, y: 0, width: bounds.width, height: 48) }
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
        ghostButton.accessibilityLabel = "Ghost solution"
        ghostButton.accessibilityIdentifier = "solutionSwitch.ghost"
        ghostButton.addAction(UIAction { [weak self] _ in self?.activateGhost() }, for: .gameActivation)
        addSubview(ghostButton)
        ghostButton.isHidden = true
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
    func activateGhost() {
        guard showsGhost else { return }
        #if os(tvOS)
        guard activation.consume() else { return }
        #endif
        onToggleGhost?()
    }
    private func updateSelection() {
        ghostButton.accessibilityValue = ghostEnabled ? "On" : "Off"
        ghostButton.accessibilityTraits = ghostEnabled ? [.button, .selected] : .button
        for (value, button) in zip(SolutionReplayMode.allCases, buttons) {
            button.accessibilityTraits = value == mode ? [.button, .selected] : .button
        }
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        for (button, frame) in zip(buttons, SolutionSwitchArt.frames(in: switchFrame)) { button.frame = frame }
        ghostButton.frame = CGRect(x: 0, y: 56, width: bounds.width, height: GhostSolutionArt.height)
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        focusedGhost && showsGhost ? [ghostButton] : [buttons[focusedMode == .game ? 0 : 1]]
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        focusedGhost = context.nextFocusedView === ghostButton
        if let index = buttons.firstIndex(where: { $0 === context.nextFocusedView }) {
            focusedMode = SolutionReplayMode.allCases[index]
        } else { focusedMode = nil }
        setNeedsDisplay()
    }
    #endif
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        SolutionSwitchArt.draw(mode: mode, focused: focusedMode, in: switchFrame,
            typography: MobileGameArt.typography, context: context)
        if showsGhost {
            GhostSolutionArt.draw(enabled: ghostEnabled, focused: focusedGhost, in: ghostButton.frame,
                typography: MobileGameArt.typography, context: context)
        }
    }
}
#endif
