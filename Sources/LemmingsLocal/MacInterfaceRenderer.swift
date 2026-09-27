import AppKit
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
      GamePixelText.draw(text, in: CGRect(x: point.x, y: point.y, width: CGFloat(text.count * 6), height: 7), maxScale: 1, palette: palette)
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
  enum Palette: String { case blue, green }

  let interface: ClassicMacUserInterface
  private var cache: [String: NSImage] = [:]
  private var lines: [String: (NSImage, CGRect, Int)] = [:]
  private var lineOrder: [String] = []
  private var lineBytes = 0


  init(interface: ClassicMacUserInterface) {
    self.interface = interface
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

  /// Draws a line with its top-left corner at the point. The view is flipped,
  /// so the text runs down and to the right from there.
  func draw(
    _ text: String, face: ClassicMacUserInterface.Face, at origin: CGPoint, scale: Int,
    alpha: CGFloat = 1, palette: Palette = .blue
  ) {
    guard let font = interface.font(face) else { return }
    if let (image, bounds, _) = lineImage(text, face: face, font: font, palette: palette) {
      image.draw(in: CGRect(x: origin.x + bounds.minX * CGFloat(scale),
        y: origin.y + bounds.minY * CGFloat(scale), width: bounds.width * CGFloat(scale),
        height: bounds.height * CGFloat(scale)), from: .zero, operation: .sourceOver,
        fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
      return
    }
    var pen = origin.x
    let step = CGFloat(font.cellWidth * scale)
    for character in text {
      defer { pen += step }
      guard let glyph = font.glyph(for: character),
        let image = image(for: glyph, key: "\(face.rawValue)-\(character)", palette: palette)
      else { continue }
      let rect = CGRect(
        x: pen + CGFloat(glyph.x * scale), y: origin.y + CGFloat(glyph.y * scale),
        width: CGFloat(glyph.width * scale), height: CGFloat(glyph.height * scale))
      image.draw(
        in: rect, from: .zero, operation: .sourceOver, fraction: alpha,
        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    }
  }

  /// Cache whole lines at source resolution to reduce per-frame glyph draws.
  /// The byte limit also bounds changing status text during long runs.
  private func lineImage(_ text: String, face: ClassicMacUserInterface.Face,
    font: ClassicMacUserInterface.Font, palette: Palette) -> (NSImage, CGRect, Int)? {
    guard !text.isEmpty, text.count <= 512 else { return nil }
    let key = palette.rawValue + ":" + face.rawValue + ":" + text
    if let line = lines[key] { return line }
    var bounds = CGRect(x: 0, y: 0, width: font.width(of: text), height: font.cellHeight)
    for (index, character) in text.enumerated() {
      guard let glyph = font.glyph(for: character) else { continue }
      bounds = bounds.union(CGRect(x: index * font.cellWidth + glyph.x, y: glyph.y,
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
    for (index, character) in text.enumerated() {
      guard let glyph = font.glyph(for: character),
        let image = image(for: glyph, key: "\(face.rawValue)-\(character)", palette: palette) else { continue }
      image.draw(in: CGRect(x: index * font.cellWidth + glyph.x, y: glyph.y,
        width: glyph.width, height: glyph.height), from: .zero, operation: .sourceOver,
        fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
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
    let origin = CGPoint(x: centerX - width(of: text, face: face, scale: scale) / 2, y: top)
    draw(text, face: face, at: origin, scale: scale, alpha: alpha, palette: palette)
  }

  /// The title logo, fitted to a box. Whole-number scales are preferred, and
  /// a fraction is used only when the box is smaller than the artwork.
  func drawLogo(
    centerX: CGFloat, top: CGFloat, maximumWidth: CGFloat, maximumHeight: CGFloat
  ) -> CGFloat {
    guard let logo = interface.logo, let image = image(for: logo, key: "logo"),
      logo.width > 0, logo.height > 0
    else { return 0 }
    let fit = min(maximumWidth / CGFloat(logo.width), maximumHeight / CGFloat(logo.height))
    // Below one, the logo has to shrink, and a whole number is not available.
    let factor = fit >= 1 ? CGFloat(max(1, Int(fit))) : fit
    let size = CGSize(width: CGFloat(logo.width) * factor, height: CGFloat(logo.height) * factor)
    image.draw(
      in: CGRect(x: centerX - size.width / 2, y: top, width: size.width, height: size.height),
      from: .zero, operation: .sourceOver, fraction: 1,
      respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
    return size.height
  }

  var logoAspect: CGFloat? {
    guard let logo = interface.logo, logo.width > 0 else { return nil }
    return CGFloat(logo.height) / CGFloat(logo.width)
  }

  static func menuText(_ value: String) -> String {
    let plain = value.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en"))
      .uppercased().replacingOccurrences(of: "—", with: "-").replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
      .replacingOccurrences(of: "·", with: "*").replacingOccurrences(of: "•", with: "*")
      .replacingOccurrences(of: "→", with: "->").replacingOccurrences(of: "←", with: "<-")
      .replacingOccurrences(of: "×", with: "X").replacingOccurrences(of: "↵", with: "ENTER")
      .replacingOccurrences(of: "‹", with: "<").replacingOccurrences(of: "›", with: ">")
    return String(plain.map { $0.isASCII || $0 == "💀" ? $0 : "?" })
  }

  /// Uses the original glyphs at a fixed size, with the same cell spacing on every page.
  func menuLine(_ value: String, in rect: CGRect, face: ClassicMacUserInterface.Face = .small,
                scale: Int = 1, alignment: NSTextAlignment = .center, alpha: CGFloat = 1, palette: Palette = .blue) {
    guard let font = font(face) else { return }
    let columns = max(0, Int(rect.width) / (font.cellWidth * scale))
    guard columns > 0 else { return }
    let plain = Self.menuText(value)
    let line = plain.count <= columns ? plain : String(plain.prefix(max(0, columns - 3))) + String(repeating: ".", count: min(3, columns))
    let width = width(of: line, face: face, scale: scale)
    let x = alignment == .left ? rect.minX : alignment == .right ? rect.maxX - width : rect.midX - width / 2
    draw(line, face: face, at: CGPoint(x: x.rounded(), y: rect.minY.rounded()), scale: scale, alpha: alpha, palette: palette)
  }

  /// Preserves explicit lines and splits long words without dropping characters.
  static func menuLines(_ value: String, columns: Int) -> [String] {
    guard !value.isEmpty else { return [] }
    let columns = max(1, columns)
    return menuText(value).components(separatedBy: "\n").flatMap { paragraph -> [String] in
      var lines: [String] = [], line = ""
      for token in paragraph.split(whereSeparator: { $0.isWhitespace }) {
        var word = String(token)
        if !line.isEmpty && line.count + word.count + 1 > columns {
          lines.append(line); line = ""
        }
        while word.count > columns {
          lines.append(String(word.prefix(columns)))
          word = String(word.dropFirst(columns))
        }
        line += (line.isEmpty ? "" : " ") + word
      }
      lines.append(line)
      return lines
    }
  }

  func menuParagraph(_ value: String, in rect: CGRect, alignment: NSTextAlignment = .center,
    face: ClassicMacUserInterface.Face = .small, palette: Palette = .blue, alpha: CGFloat = 1) {
    guard let font = font(face) else { return }
    let columns = max(1, Int(rect.width) / font.cellWidth), spacing = font.cellHeight + 6
    let rows = max(0, Int(rect.height) / spacing)
    let lines = Self.menuLines(value, columns: columns)
    for (index, value) in lines.prefix(rows).enumerated() {
      let text = index == rows - 1 && lines.count > rows ? String(value.prefix(max(0, columns - 3))) + "..." : value
      menuLine(text, in: CGRect(x: rect.minX, y: rect.minY + CGFloat(index * spacing), width: rect.width, height: CGFloat(spacing)), face: face, alignment: alignment, alpha: alpha, palette: palette)
    }
  }

  // MARK: - Images

  private func image(for frame: ClassicMacArtwork.Frame, key: String, palette: Palette = .blue) -> NSImage? {
    let key = palette.rawValue + ":" + key
    if let cached = cache[key] { return cached }
    var pixels = frame.rgba
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
        let stone = NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1)
        for x in stride(from: board.minX, to: board.maxX, by: 28 * scale) {
            Self.fill(CGRect(x: x, y: board.minY, width: min(26 * scale, board.maxX - x), height: 7 * scale), stone)
            Self.fill(CGRect(x: x, y: board.maxY - 7 * scale, width: min(26 * scale, board.maxX - x), height: 7 * scale), stone)
        }
        let moss = NSColor(calibratedRed: 0.27, green: 0.62, blue: 0.12, alpha: 1)
        Self.fill(CGRect(x: board.minX, y: board.minY - 3 * scale, width: board.width, height: 4 * scale), moss)
        for x in stride(from: board.minX, to: board.maxX - 8 * scale, by: 19 * scale) {
            Self.fill(CGRect(x: x, y: board.minY, width: 6 * scale, height: 5 * scale), moss)
        }
    }
    private static func fill(_ rect: CGRect, _ color: NSColor) {
        color.setFill(); rect.fill()
    }
}
