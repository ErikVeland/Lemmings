#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

/// Text roles use the shipped glyphs. Size follows purpose, never word length.
@MainActor enum GameTypography {
  enum Role {
    case title, heading, body
    var face: ClassicMacUserInterface.Face { self == .title ? .large : .small }
    var palette: MacInterfaceRenderer.Palette { self == .body ? .blue : .green }
  }

  static func annotation(_ text: String, at point: CGPoint, palette: MacInterfaceRenderer.Palette = .green) {
    let text = MacInterfaceRenderer.menuText(text)
    if let renderer = GameMenuArtwork.renderer(), renderer.font(.small)?.covers(text) == true {
      renderer.draw(text, face: .small, at: CGPoint(x: point.x.rounded(), y: point.y.rounded()), scale: 1, palette: palette)
    } else {
      let bounds = GamePixelTypography.verticalBounds(of: text)
      let horizontal = GamePixelTypography.horizontalBounds(of: text)
      GamePixelText.draw(text, in: CGRect(x: point.x + CGFloat(horizontal.left), y: point.y + CGFloat(bounds.top),
        width: CGFloat(GamePixelTypography.width(of: text)), height: CGFloat(bounds.bottom - bounds.top)), maxScale: 1, palette: palette)
    }
  }
}

/// Draws menus with the Macintosh release's own artwork.
///
/// The Macintosh version drew its front end at twice the resolution of the
/// other platforms and shipped a complete character set with it. Menus drawn
/// through this look like the game rather than like an application, and they
/// stay sharp because every glyph is placed at a whole-number scale.
@MainActor final class MacInterfaceRenderer {
  enum Palette: String { case blue, green, monochrome }

  let interface: ClassicMacUserInterface
  private let menuLogo: NSImage?
  private var counterSocket: NSImage?
  private var counterImages: [Int: NSImage] = [:]
  private var cache: [String: NSImage] = [:]

  /// The panel font lives after the printable menu alphabet, at frames 96–106.
  func drawCounter(_ text: String, in box: CGRect, panelScale: CGFloat) -> Bool {
    guard interface.counterGlyphs.count == 11,
      interface.counterGlyphs.prefix(10).allSatisfy({ $0 != nil }),
      CGFloat(text.count * 6) <= box.width else { return false }
    if counterSocket == nil, let source = interface.counterPanel?.makeNSImage(),
      let bitmap = source.cgImage(forProposedRect: nil, context: nil, hints: nil), bitmap.width == 640,
      let crop = bitmap.cropping(to: CGRect(x: 38, y: 2, width: 24, height: 18)) {
      counterSocket = NSImage(cgImage: crop, size: CGSize(width: 24, height: 18))
    }
    let scale = max(1, floor(min(panelScale / 2, box.width / CGFloat(max(1, text.count * 6 + 4)), box.height / 9)))
    let width = min(box.width, max(24 * scale, CGFloat(text.count * 6 + 4) * scale))
    let socket = CGRect(x: floor(box.midX - width / 2), y: floor(box.minY), width: width, height: box.height)
    // Retain the authored socket colours when the adaptive panel needs a wider count.
    if let counterSocket {
      counterSocket.draw(in: socket, from: .zero, operation: .sourceOver, fraction: 1,
        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    } else {
      NSColor(calibratedRed: 1, green: 221.0 / 255, blue: 221.0 / 255, alpha: 1).setFill()
      socket.fill()
    }
    if text == "∞" {
      GamePixelText.draw(text, in: socket.insetBy(dx: scale, dy: 0), maxScale: scale, color: .black)
      return true
    }
    let left = floor(box.midX - CGFloat(text.count * 6) * scale / 2)
    for (offset, character) in text.enumerated() {
      guard let digit = character.wholeNumberValue, (0..<10).contains(digit),
        let glyph = interface.counterGlyphs[digit] else { return false }
      let image = counterImages[digit] ?? glyph.makeNSImage()
      guard let image else { return false }
      counterImages[digit] = image
      image.draw(in: CGRect(x: left + CGFloat(offset * 6) * scale,
        y: floor(box.midY - 4.5 * scale), width: 6 * scale, height: 9 * scale),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    return true
  }
  private var lines: [String: (NSImage, CGRect, Int)] = [:]
  private var lineOrder: [String] = []
  private var lineBytes = 0


  init(interface: ClassicMacUserInterface) {
    self.interface = interface
    menuLogo = interface.logo.flatMap { GameMenuLogo.image(for: $0) }.map {
      NSImage(cgImage: $0, size: GameMenuLogo.logicalSize(of: $0))
    }
  }

  func font(_ face: ClassicMacUserInterface.Face) -> ClassicMacUserInterface.Font? {
    interface.font(face)
  }

  /// The scale that fits the face to a wanted height on screen.
  ///
  /// Whole numbers only. A fractional scale blurs the pixels, which is the one
  /// thing the original never did.
  func scale(for face: ClassicMacUserInterface.Face, targetHeight: CGFloat) -> Int {
    guard let font = interface.font(face), font.cellHeight > 0 else { return 1 }
    return max(1, Int((targetHeight / CGFloat(font.cellHeight)).rounded()))
  }

  func width(of text: String, face: ClassicMacUserInterface.Face, scale: Int) -> CGFloat {
    guard let font = interface.font(face) else { return 0 }
    return CGFloat(font.width(of: text, scale: scale))
  }

  func height(face: ClassicMacUserInterface.Face, scale: Int) -> CGFloat {
    guard let font = interface.font(face) else { return 0 }
    return CGFloat(font.height(scale: scale))
  }

  func height(of text: String, face: ClassicMacUserInterface.Face, scale: Int) -> CGFloat {
    CGFloat(font(face)?.height(of: Self.menuText(text), scale: scale) ?? 0)
  }

  /// Draws a line with its top-left corner at the point. The view is flipped,
  /// so the text runs down and to the right from there.
  func draw(
    _ text: String, face: ClassicMacUserInterface.Face, at origin: CGPoint, scale: Int,
    alpha: CGFloat = 1, palette: Palette = .blue
  ) {
    guard let font = interface.font(face) else { return }
    if scale != 2 && scale != 4, let (image, bounds, _) = lineImage(text, face: face, font: font, palette: palette) {
      image.draw(in: CGRect(x: origin.x + bounds.minX * CGFloat(scale),
        y: origin.y + bounds.minY * CGFloat(scale), width: bounds.width * CGFloat(scale),
        height: bounds.height * CGFloat(scale)), from: .zero, operation: .sourceOver,
        fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
      return
    }
    for item in font.layout(text) {
      guard let source = item.glyph else { continue }
      let countdown = scale == 4 && font.cellWidth == 16 && font.cellHeight == 20
        ? GameLemmingsCountdownFace.frame(source, sequence: item.sequence) : nil
      let display = scale == 2
      let glyph = countdown ?? (display ? GameLemmingsDisplayFace.frame(source, sequence: item.sequence,
        cellWidth: font.cellWidth, cellHeight: font.cellHeight) : GameLemmingsDisplayFace.Glyph(source))
      let pixels = display || countdown != nil ? 1 : scale
      guard let image = image(for: glyph, key: "\(face.rawValue)-\(display)-\(countdown != nil)-\(item.sequence)", palette: palette) else { continue }
      let rect = CGRect(
        x: origin.x + CGFloat(item.x * scale + glyph.x * pixels), y: origin.y + CGFloat(glyph.y * pixels),
        width: CGFloat(glyph.width * pixels), height: CGFloat(glyph.height * pixels))
      image.draw(
        in: rect, from: .zero, operation: .sourceOver, fraction: alpha,
        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
  }

  /// Cache whole lines at source resolution to reduce per-frame glyph draws.
  /// The byte limit also bounds changing status text during long runs.
  private func lineImage(_ text: String, face: ClassicMacUserInterface.Face,
    font: ClassicMacUserInterface.Font, palette: Palette) -> (NSImage, CGRect, Int)? {
    guard !text.isEmpty, text.count <= 512 else { return nil }
    let key = palette.rawValue + ":" + face.rawValue + ":" + text
    if let line = lines[key] { return line }
    let horizontal = font.horizontalBounds(of: text), vertical = font.verticalBounds(of: text)
    var bounds = CGRect(x: horizontal.left, y: vertical.top, width: horizontal.right - horizontal.left,
      height: vertical.bottom - vertical.top)
    let layout = font.layout(text)
    for item in layout {
      guard let glyph = item.glyph else { continue }
      bounds = bounds.union(CGRect(x: item.x + glyph.x, y: glyph.y,
        width: glyph.width, height: glyph.height))
    }
    let width = Int(bounds.width), height = Int(bounds.height), cost = width * height * 4
    guard cost > 0, cost <= 2 * 1024 * 1024,
      let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.translateBy(x: -bounds.minX, y: CGFloat(height) + bounds.minY)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    for item in layout {
      guard let glyph = item.glyph,
        let image = image(for: GameLemmingsDisplayFace.Glyph(glyph), key: "\(face.rawValue)-false-\(item.sequence)", palette: palette) else { continue }
      image.draw(in: CGRect(x: item.x + glyph.x, y: glyph.y,
        width: glyph.width, height: glyph.height), from: .zero, operation: .sourceOver,
        fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage() else { return nil }
    while lineBytes + cost > 2 * 1024 * 1024, !lineOrder.isEmpty {
      let oldest = lineOrder.removeFirst()
      if let removed = lines.removeValue(forKey: oldest) { lineBytes -= removed.2 }
    }
    let line = (NSImage(cgImage: image, size: bounds.size), bounds, cost)
    lines[key] = line; lineOrder.append(key); lineBytes += cost
    return line
  }

  /// Draws a line centered in a width, which is how every menu row is set.
  func drawCentered(
    _ text: String, face: ClassicMacUserInterface.Face, centerX: CGFloat, top: CGFloat,
    scale: Int, alpha: CGFloat = 1, palette: Palette = .blue
  ) {
    let bearing = CGFloat((font(face)?.horizontalBounds(of: text).left ?? 0) * scale)
    let origin = CGPoint(x: centerX - width(of: text, face: face, scale: scale) / 2 - bearing, y: top)
    draw(text, face: face, at: origin, scale: scale, alpha: alpha, palette: palette)
  }

  /// The title logo, fitted to a box. Whole-number scales are preferred, and
  /// a fraction is used only when the box is smaller than the artwork.
  func drawLogo(
    centerX: CGFloat, top: CGFloat, maximumWidth: CGFloat, maximumHeight: CGFloat
  ) -> CGFloat {
    guard let image = menuLogo, image.size.width > 0, image.size.height > 0
    else { return 0 }
    let frame = GameMenuLogo.frame(canvasSize: image.size,
      originalWidth: CGFloat(interface.logo?.width ?? Int(image.size.width)),
      in: CGRect(x: centerX - maximumWidth / 2, y: top, width: maximumWidth, height: maximumHeight),
      topAligned: true)
    image.draw(
      in: frame,
      from: .zero, operation: .sourceOver, fraction: 1,
      respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none.rawValue])
    return frame.height
  }

  var logoAspect: CGFloat? {
    guard let image = menuLogo, image.size.width > 0 else { return nil }
    return image.size.height / image.size.width
  }

  static func menuText(_ value: String) -> String { GameMenuTypography.menuText(value) }

  /// Uses the original glyphs at a fixed size, with the same cell spacing on every page.
  func menuLine(_ value: String, in rect: CGRect, face: ClassicMacUserInterface.Face = .small,
                scale: Int = 1, alignment: NSTextAlignment = .center, alpha: CGFloat = 1, palette: Palette = .blue,
                numberPalette: Palette? = nil, preservesCase: Bool = false) {
    guard let font = font(face) else { return }
    let line = GameTextLayout.truncated(value, width: rect.width, face: face, scale: scale, font: font,
      preservesCase: preservesCase)
    guard !line.isEmpty else { return }
    let width = width(of: line, face: face, scale: scale)
    let x = alignment == .left ? rect.minX : alignment == .right ? rect.maxX - width : rect.midX - width / 2
    let top = CGFloat(font.verticalBounds(of: line).top * scale)
    let left = CGFloat(font.horizontalBounds(of: line).left * scale)
    let origin = CGPoint(x: (x - left).rounded(), y: (rect.minY - top).rounded())
    draw(line, face: face, at: origin, scale: scale, alpha: alpha, palette: palette)
    if let numberPalette {
      for item in font.layout(line) where item.sequence.allSatisfy({ $0.isNumber || $0 == "," }) {
        draw(item.sequence, face: face,
          at: CGPoint(x: origin.x + CGFloat(item.x * scale), y: origin.y),
          scale: scale, alpha: alpha, palette: numberPalette)
      }
    }
  }

  /// Preserves explicit lines and splits long words without dropping characters.
  static func menuLines(_ value: String, columns: Int) -> [String] {
    GameTextLayout.lines(value, width: CGFloat(max(1, columns) * 12))
  }

  func menuParagraph(_ value: String, in rect: CGRect, alignment: NSTextAlignment = .center,
    face: ClassicMacUserInterface.Face = .small, palette: Palette = .blue, alpha: CGFloat = 1,
    preservesCase: Bool = false) {
    guard let font = font(face) else { return }
    let spacing = max(font.cellHeight + 6, font.height(of: Self.menuText(value)) + 2)
    let rows = max(0, Int(rect.height) / spacing)
    let lines = GameTextLayout.lines(value, width: rect.width, face: face, font: font, preservesCase: preservesCase)
    for (index, value) in lines.prefix(rows).enumerated() {
      let text = index == rows - 1 && lines.count > rows
        ? GameTextLayout.truncated(value + "...", width: rect.width, face: face, font: font, preservesCase: preservesCase) : value
      menuLine(text, in: CGRect(x: rect.minX, y: rect.minY + CGFloat(index * spacing), width: rect.width, height: CGFloat(spacing)), face: face, alignment: alignment, alpha: alpha, palette: palette, preservesCase: preservesCase)
    }
  }

  // MARK: - Images

  private func image(for frame: GameLemmingsDisplayFace.Glyph, key: String, palette: Palette = .blue) -> NSImage? {
    let key = palette.rawValue + ":" + key
    if let cached = cache[key] { return cached }
    var pixels = frame.rgba
    if palette == .monochrome {
      pixels.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
        for i in stride(from: 0, to: bytes.count, by: 4) {
          let value: UInt8 = max(bytes[i], bytes[i + 1], bytes[i + 2]) >= 128 ? 255 : 0
          bytes[i] = value; bytes[i + 1] = value; bytes[i + 2] = value
        }
      }
    }
    if palette == .green {
      // Rotate the blue ramp into grass green. Preserve the original bevel,
      // neutral highlights, dark outline and alpha without filtering pixels.
      pixels.withUnsafeMutableBytes { raw in
        let bytes = raw.bindMemory(to: UInt8.self)
        for i in stride(from: 0, to: bytes.count, by: 4) {
          let red = bytes[i], green = bytes[i + 1], blue = bytes[i + 2]
          bytes[i] = green; bytes[i + 1] = blue; bytes[i + 2] = red
        }
      }
    }
    guard let provider = CGDataProvider(data: pixels as CFData),
      let cg = CGImage(
        width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    let image = NSImage(cgImage: cg, size: NSSize(width: frame.width, height: frame.height))
    cache[key] = image
    return image
  }
}

/// Shared framing for the briefing, results and record pages.
@MainActor enum GameMenuFrame {
    /// The same stone edging and moss cap used by the level briefing.
    static func draw(_ board: CGRect, scale: CGFloat = 1) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        GameMenuFrameArt.draw(in: context, board: board, scale: scale)
    }
}
#endif
