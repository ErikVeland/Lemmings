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
   * Draws the small cornered reticle used as the gameplay pointer.
   */
  static func drawPlayfieldPointer(at point: CGPoint, scale: CGFloat, tint: NSColor) {
    let pixel = max(1, floor(scale))
    let side = 14 * pixel
    let arm = side / 3
    let box = CGRect(
      x: floor((point.x - side / 2) / pixel) * pixel,
      y: floor((point.y - side / 2) / pixel) * pixel,
      width: side,
      height: side)
    let reticle = NSBezierPath()
    for (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
      let corner = CGPoint(x: box.minX + box.width * dx, y: box.minY + box.height * dy)
      let sx: CGFloat = dx == 0 ? 1 : -1
      let sy: CGFloat = dy == 0 ? 1 : -1
      reticle.move(to: CGPoint(x: corner.x + arm * sx, y: corner.y))
      reticle.line(to: corner)
      reticle.line(to: CGPoint(x: corner.x, y: corner.y + arm * sy))
    }
    reticle.lineWidth = max(1, floor(pixel / 2))
    tint.withAlphaComponent(0.85).setStroke()
    reticle.stroke()
  }
}
