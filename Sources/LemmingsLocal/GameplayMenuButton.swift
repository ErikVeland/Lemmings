#if os(macOS)
import AppKit

/// Gameplay controls keep their input targets while their stone artwork fades out.
@MainActor final class GameplayMenuButton: GameButton {
    var glyph: PanelGlyph?
    private var shownAt: TimeInterval?
    private var wasAutoHiding = false
    private(set) var isHovered = false
    private(set) var artworkOpacity: CGFloat = 1
    private var tracking: NSTrackingArea?

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        performClick(nil)
        return true
    }

    func resetAppearance() {
        shownAt = nil
        wasAutoHiding = false
        isHovered = false
        setOpacity(1)
    }

    func revealArtwork(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        shownAt = now
        setOpacity(1)
    }

    func updateAppearance(at now: TimeInterval, autoHide: Bool, reduceMotion: Bool) {
        if shownAt == nil || (autoHide && !wasAutoHiding) { shownAt = now }
        wasAutoHiding = autoHide
        guard autoHide, !isHovered, !(isEnabled && window?.firstResponder === self) else { setOpacity(1); return }
        let elapsed = now - (shownAt ?? now) - 3
        let progress = min(1, max(0, elapsed / 0.6))
        let opacity = reduceMotion ? (elapsed >= 0 ? 0.0 : 1.0) : 1 - progress * progress * (3 - 2 * progress)
        setOpacity(CGFloat(opacity))
    }

    private func setOpacity(_ value: CGFloat) {
        guard artworkOpacity != value else { return }
        artworkOpacity = value
        needsDisplay = true
        superview?.setNeedsDisplay(frame)
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
        setOpacity(1)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        shownAt = ProcessInfo.processInfo.systemUptime
        setOpacity(1)
    }

    override func becomeFirstResponder() -> Bool {
        setOpacity(1)
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        shownAt = ProcessInfo.processInfo.systemUptime
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard artworkOpacity > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setAlpha(artworkOpacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        if let glyph {
            GameStoneButton.draw(bounds, selected: isHighlighted || isHovered, pixel: 1,
                backdrop: PanelGlyph.rock.image(fitting: bounds.size))
            let well = GameStoneButton.well(bounds, pixel: 1).insetBy(dx: 4, dy: 4)
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
