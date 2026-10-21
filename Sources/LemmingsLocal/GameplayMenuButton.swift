#if os(macOS)
import AppKit

/// Gaps in the control row consume clicks before they reach the playfield.
@MainActor final class GameplayMenuHitArea: NSView {
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
}

/// One clock and opacity keep the gameplay controls and reward badges together.
@MainActor final class GameplayMenuAppearance {
    private let buttons = NSHashTable<GameplayMenuButton>.weakObjects()
    private var shownAt: TimeInterval?
    private var wasAutoHiding = false
    private var revealAt: TimeInterval?
    private var revealFrom: CGFloat = 1
    private var reduceMotion = false
    private(set) var opacity: CGFloat = 1

    func attach(_ button: GameplayMenuButton) { buttons.add(button) }
    func detach(_ button: GameplayMenuButton) { buttons.remove(button) }

    func reset() {
        shownAt = nil; wasAutoHiding = false; revealAt = nil
        setOpacity(1)
    }

    func reveal(at now: TimeInterval) {
        shownAt = now
        if opacity < 1 && revealAt == nil { revealAt = now; revealFrom = opacity }
        updateReveal(at: now)
    }

    func update(at now: TimeInterval, autoHide: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        if shownAt == nil || (autoHide && !wasAutoHiding) { shownAt = now }
        wasAutoHiding = autoHide
        guard autoHide else { revealAt = nil; setOpacity(1); return }
        let held = buttons.allObjects.contains {
            !$0.isHidden && $0.superview != nil && ($0.isHovered || ($0.isEnabled && $0.window?.firstResponder === $0))
        }
        if held { reveal(at: now) }
        let elapsed = now - (shownAt ?? now) - 3
        if elapsed < 0 { updateReveal(at: now); return }
        revealAt = nil
        let progress = min(1, max(0, elapsed / 0.6))
        setOpacity(reduceMotion ? 0 : CGFloat(1 - progress * progress * (3 - 2 * progress)))
    }

    private func updateReveal(at now: TimeInterval) {
        guard let start = revealAt else { return }
        let progress = min(1, max(0, (now - start) / 0.18))
        setOpacity(reduceMotion ? 1 : revealFrom + (1 - revealFrom) * CGFloat(progress * progress * (3 - 2 * progress)))
        if progress >= 1 || reduceMotion { revealAt = nil }
    }

    private func setOpacity(_ value: CGFloat) {
        guard opacity != value else { return }
        opacity = value
        for button in buttons.allObjects {
            button.needsDisplay = true
            button.superview?.setNeedsDisplay(button.frame)
        }
    }
}

/// Gameplay controls keep their input targets while their stone artwork fades out.
@MainActor final class GameplayMenuButton: GameButton {
    var glyph: PanelGlyph?
    var helpText = "" {
        didSet { if oldValue != helpText { setAccessibilityHelp(helpText) } }
    }
    var usesToggleState = false
    var fadeAppearance = GameplayMenuAppearance() {
        didSet { oldValue.detach(self); fadeAppearance.attach(self) }
    }
    private(set) var isHovered = false
    var artworkOpacity: CGFloat { fadeAppearance.opacity }
    private var tracking: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        fadeAppearance.attach(self)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }

    func resetAppearance() {
        isHovered = false
        fadeAppearance.reset()
    }

    func hideControl() { isHovered = false; isHidden = true }

    func revealArtwork(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        fadeAppearance.reveal(at: now)
    }

    func updateAppearance(at now: TimeInterval, autoHide: Bool, reduceMotion: Bool) {
        fadeAppearance.update(at: now, autoHide: autoHide, reduceMotion: reduceMotion)
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
        tracking = area
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
        revealArtwork(at: event.timestamp)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
        revealArtwork(at: event.timestamp)
    }

    override func becomeFirstResponder() -> Bool {
        revealArtwork()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        revealArtwork()
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard artworkOpacity > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setAlpha(artworkOpacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        if let glyph {
            GameStoneButton.draw(bounds, selected: (usesToggleState && state == .on) || isHighlighted || isHovered, pixel: 1,
                backdrop: PanelGlyph.rock.image(fitting: bounds.size))
            let well = GameStoneButton.well(bounds, pixel: 1).insetBy(dx: 2, dy: 2)
            if let image = glyph.image(fitting: well.size) {
                image.draw(in: CGRect(x: floor(well.midX - image.size.width / 2),
                    y: floor(well.midY - image.size.height / 2), width: image.size.width, height: image.size.height),
                    from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.45,
                    respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
            }
            GameControlText.focus(self)
        } else { super.draw(dirtyRect) }
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
#endif
