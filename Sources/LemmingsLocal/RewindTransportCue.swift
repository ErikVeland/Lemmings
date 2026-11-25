#if os(macOS)
import AppKit
import LemmingsMobileCore

/// Draws the small, shared rewind transport cue used by each playfield.
/// The text names game seconds, not engine ticks, and keeps one width while the value changes.
@MainActor enum RewindTransportCue {
  @discardableResult static func draw(
    origin: CGPoint,
    currentTick: Int,
    originTick: Int,
    ticksPerSecond: Double,
    speed: Int = 1,
    scale: CGFloat = 1
  ) -> CGFloat {
    guard let cue = RewindCue(currentTick: currentTick, originTick: originTick,
                              ticksPerSecond: ticksPerSecond, speed: speed) else { return 0 }

    GameTypography.annotation(cue.text, at: origin, palette: .blue)

    let railOrigin = CGPoint(x: origin.x, y: origin.y + 23)
    let railWidth = 112 * scale
    let railHeight = max(1, (scale * 1.5).rounded())
    let markerWidth = max(2, (scale * 2).rounded())

    NSColor.systemBlue.withAlphaComponent(0.22).setFill()
    CGRect(x: railOrigin.x, y: railOrigin.y, width: railWidth, height: railHeight).fill()

    NSColor.systemBlue.withAlphaComponent(0.72).setFill()
    CGRect(
      x: railOrigin.x + railWidth * cue.position - markerWidth / 2,
      y: railOrigin.y - scale,
      width: markerWidth,
      height: railHeight + 2 * scale
    ).fill()
    return 23 + railHeight + scale
  }
}
#endif
