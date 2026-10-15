#if os(iOS) || os(tvOS)
import LemmingsGameArt
import LemmingsTVCore
import NxlvKit
import UIKit

@MainActor final class MobileSolutionSwitchView: UIView {
    var mode = SolutionReplayMode.game { didSet { updateSelection() } }
    var showsGhost = false { didSet {
        ghostButton.isHidden = !showsGhost
        if !showsGhost { focusedGhost = false }
        setNeedsLayout(); setNeedsDisplay()
    } }
    var ghostEnabled = false { didSet { updateSelection() } }
    var onToggleGhost: (() -> Void)?
    var focusedGhost = false { didSet { setNeedsDisplay() } }
    var focusedIndex: Int? {
        get { focusedGhost ? 2 : focusedMode.map { $0 == .game ? 0 : 1 } }
        set { focusedGhost = newValue == 2 && showsGhost; focusedMode = newValue == 0 ? .game : newValue == 1 ? .solution : nil }
    }
    private let ghostButton = MobileFocusButton(type: .custom)
    static var style: MobileSolutionSelectorArt.Style {
        #if os(tvOS)
        .television
        #else
        .touch
        #endif
    }
    var controlLayout: MobileSolutionSelectorArt.Layout {
        MobileSolutionSelectorArt.layout(width: bounds.width, showsGhost: showsGhost, style: Self.style)
    }
    func apply(_ presentation: MobileSolutionSelectorArt.Presentation) {
        transform = CGAffineTransform(scaleX: presentation.scale, y: presentation.scale)
        bounds = CGRect(x: 0, y: 0, width: presentation.controls.width / presentation.scale,
            height: presentation.controls.height / presentation.scale)
        center = CGPoint(x: presentation.controls.midX, y: presentation.controls.midY)
        setNeedsLayout()
    }
    var onSelect: ((SolutionReplayMode) -> Void)?
    var focusedMode: SolutionReplayMode? { didSet { setNeedsDisplay() } }
    private var buttons: [UIButton] = []
    private var activation = TVActivationGate()
    func observeNeutral() { activation.observeNeutral() }
    func resetActivation() { activation.reset() }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.magnificationFilter = .nearest
        for value in SolutionReplayMode.allCases {
            let button = MobileFocusButton(type: .custom)
            button.accessibilityLabel = value == .game ? L10n.text("Your game") : L10n.text("Solution")
            button.accessibilityIdentifier = "solutionSwitch." + value.rawValue
            button.addAction(UIAction { [weak self] _ in self?.activate(value) }, for: .gameActivation)
            addSubview(button); buttons.append(button)
        }
        ghostButton.accessibilityLabel = L10n.text("Ghost solution")
        ghostButton.accessibilityIdentifier = "solutionSwitch.ghost"
        ghostButton.addAction(UIAction { [weak self] _ in self?.activateGhost() }, for: .gameActivation)
        addSubview(ghostButton)
        ghostButton.isHidden = true
        isHidden = true
        updateSelection()
    }
    required init?(coder: NSCoder) { nil }
    func activate(_ value: SolutionReplayMode) {
        guard !isHidden else { return }
        #if os(tvOS)
        guard activation.consume() else { return }
        #endif
        onSelect?(value)
    }
    func activateGhost() {
        guard !isHidden, showsGhost else { return }
        #if os(tvOS)
        guard activation.consume() else { return }
        #endif
        onToggleGhost?()
    }
    private func updateSelection() {
        ghostButton.accessibilityValue = ghostEnabled ? L10n.text("On") : L10n.text("Off")
        ghostButton.accessibilityTraits = ghostEnabled ? [.button, .selected] : .button
        for (value, button) in zip(SolutionReplayMode.allCases, buttons) {
            button.accessibilityTraits = value == mode ? [.button, .selected] : .button
        }
        setNeedsDisplay()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let layout = controlLayout
        for (button, frame) in zip(buttons, layout.modes) { button.frame = frame }
        ghostButton.frame = layout.ghost ?? .zero
    }
    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        guard !isHidden else { return [] }
        return focusedGhost && showsGhost ? [ghostButton] : [buttons[(focusedMode ?? mode) == .game ? 0 : 1]]
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
        MobileSolutionSelectorArt.draw(mode: mode, ghostEnabled: ghostEnabled, focusedIndex: focusedIndex,
            layout: controlLayout, typography: MobileGameArt.typography, context: context)
    }
}
#endif
