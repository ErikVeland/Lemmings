import AppKit

/// The two panel buttons the Macintosh release never drew.
///
/// That release put Pause in the Game menu and End Level in the File menu, so
/// its artwork carries signs, a music toggle and the four rank names but no
/// button face for either command. The eight skill buttons beside them draw
/// real lemming sprites, which would leave a system font setting Helvetica
/// against pixel art. These bitmaps keep the whole row in one period.
///
/// Each row is one scanline, and every glyph is written at the size it was
/// drawn rather than described as curves, because the bar is scaled by whole
/// numbers and a resampled edge would not match the sprites beside it. All of
/// them are twelve wide, which is the width of the well the bar sinks into a
/// button, so the art fills that well exactly at every scale.
enum PanelGlyph: String {
  /// A mushroom cloud, which is what the sequel puts on the same button.
  ///
  /// Redrawn here rather than lifted: the sequel's own icon is a shaded
  /// 256-colour sprite in maroon and violet, and it neither survives the
  /// reduction to a button of this size nor sits with a bar this flat.
  case nuke
  case pause
  case fastForward
  /// Shown on the pause button while the level is held, so the button says
  /// what it will do rather than what it did.
  case play

  /// A dot leaves the button showing through. Every other mark is a colour
  /// the glyph names below.
  private var rows: [String] {
    switch self {
    case .nuke:
      return [
        "....++++....",
        "..o++++++o..",
        ".o++++++++o.",
        "oo++++++++oo",
        ".oo++++++oo.",
        "...oo++oo...",
        ".....++.....",
        ".....++.....",
        "....o++o....",
        "....++++....",
        "..oo++++oo..",
        "============",
      ]
    case .fastForward:
      return ["#.....#.....", "##....##....", "###...###...", "####..####..", "#####.#####.", "############", "#####.#####.", "####..####..", "###...###...", "##....##....", "#.....#.....", "............"]
    case .pause:
      return Array(repeating: "..###..###..", count: 12)
    case .play:
      return [
        "..#.........",
        "..##........",
        "..###.......",
        "..####......",
        "..#####.....",
        "..######....",
        "..#######...",
        "..######....",
        "..#####.....",
        "..####......",
        "..###.......",
        "..##........",
      ]
    }
  }

  /// What each mark is drawn in.
  ///
  /// The cloud burns from a pale flash out to a cooler edge and lifts off a
  /// lit ground. The transport marks take the pale green the bar already
  /// labels its buttons in, so they belong to the row they sit in.
  private var palette: [Character: (UInt8, UInt8, UInt8)] {
    switch self {
    case .nuke:
      return ["+": (255, 236, 170), "o": (232, 116, 24), "=": (226, 178, 40)]
    case .pause, .play, .fastForward:
      return ["#": (194, 224, 158)]
    }
  }

  /// The glyph's own size, before any scaling.
  var pixelSize: (width: Int, height: Int) {
    let rows = self.rows
    return (rows.first?.count ?? 0, rows.count)
  }

  /// The largest whole-number scale that fits a box.
  ///
  /// Whole numbers only. A fraction would put some source pixels across two
  /// destination ones and leave the strokes uneven, which is exactly what a
  /// bitmap is here to avoid.
  @MainActor func image(fitting box: CGSize) -> NSImage? {
    let size = pixelSize
    guard size.width > 0, size.height > 0 else { return nil }
    let steps = min(Int(box.width) / size.width, Int(box.height) / size.height)
    return image(scale: steps)
  }

  @MainActor private static var cache: [String: NSImage] = [:]

  /// Renders the glyph at a whole-number scale.
  ///
  /// Results are kept, because the bar redraws every frame and the scale only
  /// changes when the window does.
  @MainActor func image(scale: Int) -> NSImage? {
    let steps = max(1, scale)
    let key = "\(rawValue)-\(steps)"
    if let hit = Self.cache[key] { return hit }

    let rows = self.rows
    let palette = self.palette
    guard let first = rows.first, !first.isEmpty else { return nil }
    let width = first.count * steps
    let height = rows.count * steps
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    for (row, line) in rows.enumerated() {
      for (column, mark) in line.enumerated() {
        guard let colour = palette[mark] else { continue }
        for dy in 0..<steps {
          for dx in 0..<steps {
            let offset = ((row * steps + dy) * width + column * steps + dx) * 4
            pixels[offset] = colour.0
            pixels[offset + 1] = colour.1
            pixels[offset + 2] = colour.2
            pixels[offset + 3] = 255
          }
        }
      }
    }

    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
      // Interpolation off: the bar is scaled by whole numbers, and a smoothed
      // edge here would not match the sprites drawn beside it.
      let cgImage = CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }

    let image = NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    Self.cache[key] = image
    return image
  }

  /// The glyph a button wears, or nil when the button carries wording instead.
  static func forButton(_ button: PanelButton, isPaused: Bool) -> PanelGlyph? {
    switch button {
    case .pause: return isPaused ? .play : .pause
    case .nuke: return .nuke
    case .fastForward: return .fastForward
    case .rateDown, .rateUp, .skill: return nil
    }
  }
}

/// Shared speed control geometry for flat, CRT and sequel panels.
@MainActor enum SpeedPanelControls {
    static let help = "Click speed to toggle. Hold to boost; release to return. Arrows choose 2×, 3×, 5× or 10×."
    static func part(at point: CGPoint, in rect: CGRect) -> Int? {
        guard rect.contains(point) else { return nil }
        if point.x < rect.minX + rect.width * 0.22 { return -1 }
        if point.x >= rect.maxX - rect.width * 0.22 { return 1 }
        return 0
    }
    static func draw(in rect: CGRect, label: String, active: Bool, next: String = "2×") {
        let side = rect.width * 0.22
        let boxes = [CGRect(x: rect.minX, y: rect.minY, width: side, height: rect.height),
            CGRect(x: rect.minX + side, y: rect.minY, width: rect.width - 2 * side, height: rect.height),
            CGRect(x: rect.maxX - side, y: rect.minY, width: side, height: rect.height)]
        for (index, box) in boxes.enumerated() {
            (index == 1 && active ? NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.16, alpha: 1) : NSColor(calibratedWhite: 0.10, alpha: 1)).setFill()
            box.insetBy(dx: 0.5, dy: 0.5).fill()
            let text = (["‹", label, "›"][index]) as NSString
            let font = NSFont.monospacedSystemFont(ofSize: min(rect.height * 0.42, box.width / (index == 1 ? 2.1 : 0.8)), weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedRed: 0.65, green: 1, blue: 0.65, alpha: 1)]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2 - (index == 1 && !active ? rect.height * 0.12 : 0)), withAttributes: attributes)
            if index == 1 && !active {
                let detail = ("→" + next) as NSString
                let small: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.65, weight: .regular), .foregroundColor: NSColor.lightGray]
                let size = detail.size(withAttributes: small)
                detail.draw(at: CGPoint(x: box.midX - size.width / 2, y: box.midY + rect.height * 0.1), withAttributes: small)
            }
        }
    }
}
