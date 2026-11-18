#if os(macOS)
import AppKit
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
#if canImport(NxlvKit)
import NxlvKit
#endif

/// Bitmap control groups show the control cursor across their buttons and gaps.
@MainActor protocol GameSystemCursorRegion: AnyObject {}

/// Cursor presentation shared by gameplay views and their controls.
@MainActor enum GameCursor {
  static var gameplaySuppressed = false
  static var gameplayCursor: NSCursor { gameplaySuppressed ? .arrow : invisible }

  static let invisible: NSCursor = {
    let image = NSImage(size: NSSize(width: 1, height: 1), flipped: true) { _ in true }
    return NSCursor(image: image, hotSpot: .zero)
  }()

  static func isOverSystemControl(at point: CGPoint, in view: NSView) -> Bool {
    guard let root = view.window?.contentView else { return false }
    var target = root.hitTest(view.convert(point, to: root.superview))
    while let current = target {
      if current is NSControl || current is any GameSystemCursorRegion { return true }
      if current === root { break }
      target = current.superview
    }
    return false
  }

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
   * Hides the system cursor behind a drawn gameplay pointer and shows the Amiga cross elsewhere.
   * Without a control scale, as on menus, the area outside gameplay keeps the system arrow.
   */
  static func update(at point: CGPoint?, hidingInside gameplayRect: CGRect?, controlScale: CGFloat? = nil) {
    if hidesSystemCursor(at: point, inside: gameplayRect) {
      invisible.set()
    } else if let controlScale {
      controlCursor(scale: controlScale).set()
    } else {
      NSCursor.arrow.set()
    }
  }

  /**
   * Returns the Amiga cross shown around gameplay in every pointer style.
   * Views without their own pixel scale reuse the last game scale.
   */
  static func controlCursor(scale: CGFloat? = nil) -> NSCursor {
    guard !gameplaySuppressed else { return .arrow }
    if let scale { controlScale = min(4, max(1, floor(scale))) }
    let revision = GameResources.revision
    if controlRevision != revision { controlRevision = revision; controlCursors.removeAll() }
    if let cursor = controlCursors[controlScale] { return cursor }
    let pointer = importedPointerImages?.first ?? clearedPointerImages?.first ?? embeddedCross
    guard let pointer else { return .arrow }
    let side = pointer.size.width * controlScale
    let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
      NSGraphicsContext.current?.imageInterpolation = .none
      pointer.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
        respectFlipped: true, hints: nil)
      return true
    }
    let cursor = NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    controlCursors[controlScale] = cursor
    return cursor
  }
  private static var controlRevision = ""
  private static var controlScale: CGFloat = 2
  private static var controlCursors: [CGFloat: NSCursor] = [:]

  /**
   * Adds `cursor` over `rect` and `elsewhere` over the rest of the view, without overlapping rects.
   */
  static func addCursorRects(in view: NSView, cursor: NSCursor, over rect: CGRect, elsewhere: NSCursor) {
    let bounds = view.bounds
    let rect = rect.intersection(bounds)
    guard !rect.isNull, !rect.isEmpty else { view.addCursorRect(bounds, cursor: elsewhere); return }
    view.addCursorRect(rect, cursor: cursor)
    let rest = [
      CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(0, rect.minY - bounds.minY)),
      CGRect(x: bounds.minX, y: rect.maxY, width: bounds.width, height: max(0, bounds.maxY - rect.maxY)),
      CGRect(x: bounds.minX, y: rect.minY, width: max(0, rect.minX - bounds.minX), height: rect.height),
      CGRect(x: rect.maxX, y: rect.minY, width: max(0, bounds.maxX - rect.maxX), height: rect.height),
    ]
    for area in rest where area.width > 0 && area.height > 0 {
      view.addCursorRect(area, cursor: elsewhere)
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
                                   original: Bool = false, occupied: Bool = false, eligible: Bool = false) {
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
    for mark in AssignmentPointerShape.marks(in: frame, arm: arm, stroke: stroke,
                                             occupied: occupied, eligible: eligible) { mark.fill() }
    NSGraphicsContext.restoreGraphicsState()
  }

  private static func drawOriginalPointer(in frame: CGRect, occupied: Bool) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current?.shouldAntialias = false
    NSGraphicsContext.current?.imageInterpolation = .none
    let images = importedPointerImages ?? clearedPointerImages ?? embeddedPointers
    guard let images, images.count == 2 else { return }
    let image = images[occupied ? 1 : 0]
    image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1,
      respectFlipped: true, hints: nil)
  }

  private static var importedRevision = ""
  private static var loadedImportedPointers: [NSImage]?
  private static var importedPointerImages: [NSImage]? {
    let revision = GameResources.revision
    if importedRevision != revision {
      importedRevision = revision
      let images = ["original-cross.png", "original-reticule.png"].compactMap { name -> NSImage? in
        guard let url = GameResources.file("Cursors/" + name),
              let data = try? Data(contentsOf: url), data.count <= 2_000_000,
              let bitmap = NSBitmapImageRep(data: data)?.retagging(with: .sRGB),
              bitmap.pixelsWide == 28, bitmap.pixelsHigh == 28, let image = bitmap.cgImage else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: 14, height: 14))
      }
      loadedImportedPointers = images.count == 2 ? images : nil
    }
    return loadedImportedPointers
  }
  private static let clearedPointerImages = makeClearedPointers()
  private static func makeClearedPointers() -> [NSImage]? {
    guard let url = Bundle.main.resourceURL?.appendingPathComponent("AlternativeAssets/Lix/assets/data/images/mouse.png"),
          let data = try? Data(contentsOf: url),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == 133, image.height == 100 else { return nil }
    var sheet = [UInt8](repeating: 0, count: 133 * 100 * 4)
    guard let context = CGContext(data: &sheet, width: 133, height: 100, bitsPerComponent: 8,
      bytesPerRow: 133 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: 133, height: 100))
    return (0..<2).compactMap { row in
      var rgba = [UInt8](repeating: 0, count: 32 * 32 * 4)
      for y in 0..<32 { for x in 0..<32 {
        let source = ((y + 1 + row * 33) * 133 + x + 1) * 4
        if sheet[source] == 255 && sheet[source + 1] == 0 && sheet[source + 2] == 255 { continue }
        let offset = (y * 32 + x) * 4
        rgba.replaceSubrange(offset..<(offset + 4), with: sheet[source..<(source + 4)])
      } }
      guard let provider = CGDataProvider(data: Data(rgba) as CFData),
            let image = CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32,
              bytesPerRow: 128, space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
              decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
      return NSImage(cgImage: image, size: NSSize(width: 16, height: 16))
    }
  }

  private static var embeddedCross: NSImage? { embeddedPointers?.first }
  private static var embeddedPointers: [NSImage]? {
    #if ULTIMATE_LEMMIX_STORE
    nil
    #else
    [originalCross, originalReticule]
    #endif
  }

  #if !ULTIMATE_LEMMIX_STORE
  private static func originalPointerImage(_ base64: String) -> NSImage {
    let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)!
    let bitmap = NSBitmapImageRep(data: data)!.retagging(with: .sRGB)!
    return NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: 14, height: 14))
  }

  // Exact supplied Amiga PNGs, also kept in Tests/DialogCursorTests/Fixtures.
  // The 28-pixel artwork represents 14 game pixels. Clean builds import these resources.
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

  #endif

  static func targetTint(eligible: Bool, occupied: Bool) -> NSColor {
    if eligible { return NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.2, alpha: 1) }
    if occupied { return .systemYellow }
    return NSColor(calibratedWhite: 0.6, alpha: 0.9)
  }
}
#endif
