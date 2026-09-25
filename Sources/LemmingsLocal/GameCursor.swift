import AppKit

/// Cursor presentation shared by gameplay views and their controls.
@MainActor enum GameCursor {
  static var gameplaySuppressed = false
  static var gameplayCursor: NSCursor { gameplaySuppressed ? .arrow : invisible }

  static let invisible: NSCursor = {
    let image = NSImage(size: NSSize(width: 1, height: 1), flipped: true) { _ in true }
    return NSCursor(image: image, hotSpot: .zero)
  }()

  /**
   * Returns true only where the game draws its own pointer.
   */
  static func hidesSystemCursor(at point: CGPoint?, inside gameplayRect: CGRect?) -> Bool {
    guard !gameplaySuppressed, let point, let gameplayRect, !gameplayRect.isNull, !gameplayRect.isEmpty else {
      return false
    }
    return gameplayRect.contains(point)
  }

  /**
   * Keeps the system arrow on controls and hides it behind a drawn gameplay pointer.
   */
  static func update(at point: CGPoint?, hidingInside gameplayRect: CGRect?) {
    if hidesSystemCursor(at: point, inside: gameplayRect) {
      invisible.set()
    } else {
      NSCursor.arrow.set()
    }
  }

  /**
   * Returns the pixel-aligned frame used by the four-corner reticle.
   */
  static func playfieldPointerFrame(at point: CGPoint, scale: CGFloat) -> CGRect {
    let pixel = max(1, floor(scale))
    let side = 14 * pixel
    return CGRect(
      x: floor((point.x - side / 2) / pixel) * pixel,
      y: floor((point.y - side / 2) / pixel) * pixel,
      width: side,
      height: side)
  }

  /**
   * Draws the four-corner reticle used as the gameplay pointer.
   */
  static func drawPlayfieldPointer(at point: CGPoint, scale: CGFloat, tint: NSColor) {
    guard !gameplaySuppressed else { return }
    let frame = playfieldPointerFrame(at: point, scale: scale)
    let pixel = max(1, floor(scale))
    let arm = 5 * pixel
    tint.setFill()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.shouldAntialias = false
    let deviceScale = abs(NSGraphicsContext.current?.cgContext.convertToDeviceSpace(CGSize(width: 1, height: 0)).width ?? 1)
    let stroke = 1 / max(1, deviceScale)
    for x in [frame.minX, frame.maxX - stroke] {
      for y in [frame.minY, frame.maxY - stroke] {
        CGRect(x: x == frame.minX ? x : x - arm + stroke, y: y, width: arm, height: stroke).fill()
        CGRect(x: x, y: y == frame.minY ? y : y - arm + stroke, width: stroke, height: arm).fill()
      }
    }
    NSGraphicsContext.restoreGraphicsState()
  }

  static func targetTint(eligible: Bool, occupied: Bool) -> NSColor {
    if eligible { return NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.2, alpha: 1) }
    if occupied { return .systemYellow }
    return NSColor(calibratedWhite: 0.6, alpha: 0.9)
  }
}
