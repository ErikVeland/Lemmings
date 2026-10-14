#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

@MainActor final class SolutionSwitchView: NSView {
    var mode = SolutionReplayMode.game { didSet { buttons.forEach { $0.needsDisplay = true } } }
    var onSelect: ((SolutionReplayMode) -> Void)?
    private var buttons: [SolutionSegmentButton] = []
    static let typography = Bundle.main.resourceURL.flatMap { GameMenuTypography(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        for value in SolutionReplayMode.allCases {
            let button = SolutionSegmentButton(title: value == .game ? "Your game" : "Solution", primary: false)
            button.owner = self
            button.onPress = { [weak self] in self?.onSelect?(value) }
            button.setAccessibilityLabel(button.title)
            addSubview(button); buttons.append(button)
        }
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        for (button, frame) in zip(buttons, SolutionSwitchArt.frames(in: bounds)) { button.frame = frame }
    }
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); bounds.fill() }
}

@MainActor private final class SolutionSegmentButton: GameActionButton {
    weak var owner: SolutionSwitchView?
    override func draw(_ dirtyRect: NSRect) {
        guard let owner, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: -frame.minX, y: -frame.minY)
        SolutionSwitchArt.draw(mode: owner.mode, focused: isHighlighted ? (title == "Your game" ? .game : .solution) : nil,
            in: owner.bounds, typography: SolutionSwitchView.typography, context: context)
        context.restoreGState()
        setAccessibilityValue(owner.mode == (title == "Your game" ? .game : .solution) ? "Selected" : "")
        GameControlText.focus(self)
    }
}
#endif
