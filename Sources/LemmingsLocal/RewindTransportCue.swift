import AppKit

/// Draws the small, shared rewind transport cue used by each playfield.
@MainActor enum RewindTransportCue {
  static func draw(
    origin: CGPoint,
    currentTick: Int,
    originTick: Int,
    scale: CGFloat = 1
  ) {
    guard originTick > currentTick else { return }

    let delta = originTick - currentTick
    GameTypography.annotation("REWIND  -\(delta) TICKS", at: origin, palette: .blue)

    let railOrigin = CGPoint(x: origin.x, y: origin.y + 11 * scale)
    let railWidth = 112 * scale
    let railHeight = max(1, (scale * 1.5).rounded())
    let position = CGFloat(max(0, min(currentTick, originTick))) / CGFloat(originTick)
    let markerWidth = max(2, (scale * 2).rounded())

    NSColor.systemBlue.withAlphaComponent(0.22).setFill()
    CGRect(x: railOrigin.x, y: railOrigin.y, width: railWidth, height: railHeight).fill()

    NSColor.systemBlue.withAlphaComponent(0.72).setFill()
    CGRect(
      x: railOrigin.x + railWidth * position - markerWidth / 2,
      y: railOrigin.y - scale,
      width: markerWidth,
      height: railHeight + 2 * scale
    ).fill()
  }
}
