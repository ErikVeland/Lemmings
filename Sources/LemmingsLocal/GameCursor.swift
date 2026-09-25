import AppKit

/// Cursor presentation shared by gameplay views and their controls.
@MainActor enum GameCursor {
  static let invisible: NSCursor = {
    let image = NSImage(size: NSSize(width: 1, height: 1), flipped: true) { _ in true }
    return NSCursor(image: image, hotSpot: .zero)
  }()

  /**
   * Returns true only where the game draws its own pointer.
   */
  static func hidesSystemCursor(at point: CGPoint?, inside gameplayRect: CGRect?) -> Bool {
    guard let point, let gameplayRect, !gameplayRect.isNull, !gameplayRect.isEmpty else {
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
   * Returns the pixel-aligned frame used by the small crosshair.
   */
  static func playfieldPointerFrame(at point: CGPoint, scale: CGFloat) -> CGRect {
    let pixel = max(1, floor(scale))
    let side = 6 * pixel
    return CGRect(
      x: floor((point.x - side / 2) / pixel) * pixel,
      y: floor((point.y - side / 2) / pixel) * pixel,
      width: side,
      height: side)
  }

  /**
   * Draws the small crosshair used as the gameplay pointer.
   */
  static func drawPlayfieldPointer(at point: CGPoint, scale: CGFloat, tint: NSColor) {
    let pixel = max(1, floor(scale))
    let arm = 3 * pixel
    let crosshair = NSBezierPath()
    crosshair.move(to: CGPoint(x: point.x - arm, y: point.y))
    crosshair.line(to: CGPoint(x: point.x + arm, y: point.y))
    crosshair.move(to: CGPoint(x: point.x, y: point.y - arm))
    crosshair.line(to: CGPoint(x: point.x, y: point.y + arm))
    crosshair.lineWidth = pixel
    tint.withAlphaComponent(0.85).setStroke()
    crosshair.stroke()
  }
}
