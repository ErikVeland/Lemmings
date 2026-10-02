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
   * Draws the modern reticle or the supplied Amiga cross and target square.
   */
  static func drawPlayfieldPointer(at point: CGPoint, scale: CGFloat, tint: NSColor,
                                   original: Bool = false, occupied: Bool = false) {
    guard !gameplaySuppressed else { return }
    let frame = playfieldPointerFrame(at: point, scale: scale)
    let pixel = max(1, floor(scale))
    if original {
      drawOriginalPointer(in: frame, occupied: occupied)
      return
    }
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

  private static func drawOriginalPointer(in frame: CGRect, occupied: Bool) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current?.shouldAntialias = false
    NSGraphicsContext.current?.imageInterpolation = .none
    let image = occupied ? originalReticule : originalCross
    image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1,
      respectFlipped: true, hints: nil)
  }

  private static func originalPointerImage(_ base64: String) -> NSImage {
    let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)!
    let bitmap = NSBitmapImageRep(data: data)!.retagging(with: .sRGB)!
    return NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: 14, height: 14))
  }

  // Exact supplied Amiga PNGs, also kept in Tests/DialogCursorTests/Fixtures.
  // The 28-pixel artwork represents 14 game pixels. Embed it for every build path.
  private static let originalCross = originalPointerImage("""
    iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAAXNSR0IArs4c6QAAAKRlWElmTU0AKgAAAAgABgESAAMAAAABAAEA
    AAEaAAUAAAABAAAAVgEbAAUAAAABAAAAXgEoAAMAAAABAAIAAAExAAIAAAATAAAAZodpAAQAAAABAAAAegAAAAAAABJbAAAAMgAA
    ElsAAAAyUGl4ZWxtYXRvciBQcm8gMy44AAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAHKADAAQAAAABAAAAHAAAAADPG0UdAAAA
    CXBIWXMAAA50AAAOdAFrJLPWAAADamlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpu
    czptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNi4wLjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3Jn
    LzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAg
    ICB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIKICAgICAgICAgICAgeG1sbnM6eG1wPSJodHRwOi8v
    bnMuYWRvYmUuY29tL3hhcC8xLjAvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4w
    LyI+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4yODwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiAgICAgICAgIDxleGlm
    OlBpeGVsWERpbWVuc2lvbj4yODwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+UGl4ZWxt
    YXRvciBQcm8gMy44PC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx4bXA6TWV0YWRhdGFEYXRlPjIwMjYtMTAtMDJUMTQ6MTU6
    MTYrMTA6MDA8L3htcDpNZXRhZGF0YURhdGU+CiAgICAgICAgIDx0aWZmOlhSZXNvbHV0aW9uPjk0MDAwMC8xMDAwMDwvdGlmZjpY
    UmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6UmVzb2x1dGlvblVuaXQ+MjwvdGlmZjpSZXNvbHV0aW9uVW5pdD4KICAgICAgICAg
    PHRpZmY6WVJlc29sdXRpb24+OTQwMDAwLzEwMDAwPC90aWZmOllSZXNvbHV0aW9uPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlv
    bj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K
    o64CegAAAe9JREFUSA3tVU2P0zAQff5InI8mS8suEv+EC3BA4sppxW/cA1sunBDcEL+EAwhtS7dNmrj2MJEat1K1K/ncnZPfzPhl
    8jweC0RaNdeUrGvo9wbNZIN1uRIxFDImecjtIOGnHjZbwd772O1nkB+l/6DH5KYgmQHqVQaX9VhdrKM4dKyolBkIW0AlQENt7PYz
    yI/Sf9BDfplQ4jyS1waWOnSzJooj+h4WzQUmtoRWCgWf5ZOdKFCvKpouahoDz9cZXf2ZBFwtKqr+VgFb0uSppt4aauhl8F/evqBy
    LgKu51MqP8mAZzc1mc+GpLQ9aOvG72HTpnCpChhkoOUuYOWGmEGiK+T2yM9T1upnIc/5jnnygK3SUDKFtj94seNbvDfDeMdFjFZ+
    s/h31Fo9N0vqG7iuhc955Ozt7p2EEodhXrwpIYXFdh9P3vaQWnCzdQTH1Y3Wuxa5DkpgyVVqdSAy4DUlsHnN/3nkb1t05lCZZSGc
    akZaOOMh+3Po6qgpMehTLa8obTv4nx2fdYn7j3dRHAfRg9qPL3q/gSgFN4SBlJvHk88yGqX/oND09yUR32f1VaDzKdbXv6I4ol/8
    JmmQOIM24cminl780zaN0n/YbpY5VX4G+x3YsbybD4sojugzNELB2ZbH6RZinMynP/Kg5z/8fbckSfSnAwAAAABJRU5ErkJggg==
    """)
  private static let originalReticule = originalPointerImage("""
    iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAMAAABF0y+mAAAADFBMVEUAAAAAqgD//wAA7gDgOX7wAAAABHRSTlMA////sy1AiAAA
    ADxJREFUeNpjYAYCRiBgAAImIADRID5InIGAJAMOQEgSaCB2AJShleRAACYm3DK0khwAMBDxSUHqIzvFAwCymwERWKw/XwAAAABJ
    RU5ErkJggg==
    """)

  static func targetTint(eligible: Bool, occupied: Bool) -> NSColor {
    if eligible { return NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.2, alpha: 1) }
    if occupied { return .systemYellow }
    return NSColor(calibratedWhite: 0.6, alpha: 0.9)
  }
}
