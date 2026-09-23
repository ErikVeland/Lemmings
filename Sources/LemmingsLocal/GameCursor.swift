import AppKit

/// A transparent cursor used only while a game view draws its own pointer.
@MainActor enum GameCursor {
  static let invisible: NSCursor = {
    let image = NSImage(size: NSSize(width: 1, height: 1), flipped: true) { _ in true }
    return NSCursor(image: image, hotSpot: .zero)
  }()
}
