#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

@MainActor final class SolutionSwitchView: NSView, GameSystemCursorRegion {
    var onPointerEntered: (() -> Void)?
    private var pointerTracking: NSTrackingArea?
    var mode = SolutionReplayMode.game { didSet { buttons.forEach { $0.needsDisplay = true } } }
    var ghostEnabled = false { didSet { ghostButton.setAccessibilityValue(ghostEnabled ? 1 : 0); ghostButton.needsDisplay = true } }
    var onToggleGhost: (() -> Void)?
    private let ghostButton = GhostSolutionButton(title: L10n.text("Ghost solution"), primary: false)
    private var switchFrame: CGRect { CGRect(x: 0, y: 0, width: bounds.width, height: 48) }
    var onSelect: ((SolutionReplayMode) -> Void)?
    private var buttons: [SolutionSegmentButton] = []
    static let typography = Bundle.main.resourceURL.flatMap { GameMenuTypography(directory: $0.appendingPathComponent("MacArtwork/lemmings")) }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        ghostButton.owner = self
        ghostButton.onPress = { [weak self] in self?.onToggleGhost?() }
        ghostButton.setAccessibilityRole(.checkBox)
        ghostButton.setAccessibilityLabel(L10n.text("Ghost solution"))
        ghostButton.setAccessibilityValue(0)
        ghostButton.isHidden = frame.height < 100
        addSubview(ghostButton)
        for value in SolutionReplayMode.allCases {
            let button = SolutionSegmentButton(title: value == .game ? L10n.text("Your game") : L10n.text("Solution"), primary: false)
            button.owner = self
            button.mode = value
            button.onPress = { [weak self] in self?.onSelect?(value) }
            button.setAccessibilityLabel(button.title)
            addSubview(button); buttons.append(button)
        }
    }
    required init?(coder: NSCoder) { nil }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let area = NSTrackingArea(rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect], owner: self)
        addTrackingArea(area); pointerTracking = area
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }
    override func cursorUpdate(with event: NSEvent) { showSystemPointer() }
    override func mouseEntered(with event: NSEvent) { showSystemPointer() }
    override func mouseMoved(with event: NSEvent) { showSystemPointer() }
    private func showSystemPointer() { onPointerEntered?(); NSCursor.arrow.set() }
    override func layout() {
        super.layout()
        for (button, frame) in zip(buttons, SolutionSwitchArt.frames(in: switchFrame)) { button.frame = frame }
        ghostButton.isHidden = bounds.height < 100
        ghostButton.frame = CGRect(x: 0, y: 56, width: bounds.width, height: GhostSolutionArt.height)
    }
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); bounds.fill() }
}

@MainActor private final class SolutionSegmentButton: GameActionButton {
    weak var owner: SolutionSwitchView?
    var mode: SolutionReplayMode = .game
    override func draw(_ dirtyRect: NSRect) {
        guard let owner, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: -frame.minX, y: -frame.minY)
        SolutionSwitchArt.draw(mode: owner.mode, focused: isHighlighted ? mode : nil,
            in: CGRect(x: 0, y: 0, width: owner.bounds.width, height: 48), typography: SolutionSwitchView.typography, context: context)
        context.restoreGState()
        setAccessibilityValue(owner.mode == mode ? L10n.text("Selected") : "")
        GameControlText.focus(self)
    }
}
@MainActor private final class GhostSolutionButton: GameActionButton {
    weak var owner: SolutionSwitchView?
    var mode: SolutionReplayMode = .game
    override func draw(_ dirtyRect: NSRect) {
        guard let owner, let context = NSGraphicsContext.current?.cgContext else { return }
        GhostSolutionArt.draw(enabled: owner.ghostEnabled, focused: isHighlighted, in: bounds,
            typography: SolutionSwitchView.typography, context: context)
        GameControlText.focus(self)
    }
}
#endif
