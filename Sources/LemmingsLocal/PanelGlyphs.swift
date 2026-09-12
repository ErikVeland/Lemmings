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
  case undo
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
    case .undo:
      return [".....####...", "...########.", "..###....###", "..##......##", "#.##........", "####........", "###.........", "####........", "#####.......", "...........#", "...#########", ".....#####.."]
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
    case .pause, .play, .fastForward, .undo:
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
  static func forButton(_ button: PanelButton, isPaused: Bool, canUndoNuke: Bool = false) -> PanelGlyph? {
    switch button {
    case .pause: return isPaused ? .play : .pause
    case .nuke: return canUndoNuke ? .undo : .nuke
    case .fastForward: return .fastForward
    case .rateDown, .rateUp, .skill: return nil
    }
  }
}

/// Shared speed control geometry for flat, CRT and sequel panels.
@MainActor enum SpeedPanelControls {
    static let help = "Click speed to toggle. Hold to boost; release to return. Arrows apply 2×, 3×, 5× or 10× immediately."
    static func part(at point: CGPoint, in rect: CGRect) -> Int? {
        guard rect.contains(point) else { return nil }
        if point.x < rect.minX + rect.width * 0.22 { return -1 }
        if point.x >= rect.maxX - rect.width * 0.22 { return 1 }
        return 0
    }
    static func draw(in rect: CGRect, label: String, active: Bool, next: String = "2×") {
        let side = rect.width * 0.22
        let pixel = max(1, floor(rect.height / 24))
        let boxes = [CGRect(x: rect.minX, y: rect.minY, width: side, height: rect.height),
            CGRect(x: rect.minX + side, y: rect.minY, width: rect.width - 2 * side, height: rect.height),
            CGRect(x: rect.maxX - side, y: rect.minY, width: side, height: rect.height)]
        GameStoneButton.draw(rect, selected: active, pixel: pixel)
        for (index, box) in boxes.enumerated() {
            if index == 1 {
                let content = box.insetBy(dx: rect.height >= 60 ? 4 * pixel : pixel, dy: 6 * pixel)
                let glyphBox = CGRect(x: content.minX, y: content.minY, width: content.width, height: content.height * 0.45)
                if let image = PanelGlyph.fastForward.image(fitting: glyphBox.size), image.size.width <= glyphBox.width, image.size.height <= glyphBox.height {
                    image.draw(in: CGRect(x: glyphBox.midX - image.size.width / 2, y: glyphBox.midY - image.size.height / 2,
                        width: image.size.width, height: image.size.height), from: .zero, operation: .sourceOver,
                        fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
                    GamePixelText.draw(active ? label : next, in: CGRect(x: content.minX, y: content.midY,
                        width: content.width, height: content.height / 2), maxScale: .greatestFiniteMagnitude)
                } else {
                    GamePixelText.draw(active ? label : next, in: content, maxScale: .greatestFiniteMagnitude)
                }
            } else {
                let step = max(1, floor(min(box.width / 8, box.height / 12)))
                let rows = index == 0 ? ["..#", ".#.", "#..", ".#.", "..#"] : ["#..", ".#.", "..#", ".#.", "#.."]
                NSColor(calibratedRed: 0.76, green: 0.88, blue: 0.62, alpha: 1).setFill()
                for (y, row) in rows.enumerated() {
                    for (x, mark) in row.enumerated() where mark == "#" {
                        CGRect(x: floor(box.midX - 1.5 * step) + CGFloat(x) * step,
                            y: floor(box.midY - 2.5 * step) + CGFloat(y) * step, width: step, height: step).fill()
                    }
                }
            }
        }
    }
}

/// Shared stone sockets for controls added beside the original panel artwork.
@MainActor enum GameStoneButton {
  static func draw(_ frame: CGRect, selected: Bool, pixel: CGFloat) {
    let rim = frame.insetBy(dx: pixel, dy: pixel)
    func fill(_ rect: CGRect, _ color: NSColor) {
      color.setFill()
      rect.fill()
    }
    let light = NSColor(calibratedRed: 0.65, green: 0.66, blue: 0.59, alpha: 1)
    let stone = NSColor(calibratedRed: 0.35, green: 0.37, blue: 0.32, alpha: 1)
    let shadow = NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.10, alpha: 1)
    fill(rim, stone)
    // Top and left catch the light; the selected button sinks into its socket.
    let upper = selected ? shadow : light
    let lower = selected ? light : shadow
    for step in 0..<2 {
      let edge = rim.insetBy(dx: CGFloat(step) * pixel, dy: CGFloat(step) * pixel)
      fill(CGRect(x: edge.minX, y: edge.minY, width: edge.width, height: pixel), upper)
      fill(CGRect(x: edge.minX, y: edge.minY, width: pixel, height: edge.height), upper)
      fill(CGRect(x: edge.minX, y: edge.maxY - pixel, width: edge.width, height: pixel), lower)
      fill(CGRect(x: edge.maxX - pixel, y: edge.minY, width: pixel, height: edge.height), lower)
    }
    let well = rim.insetBy(dx: 3 * pixel, dy: 3 * pixel)
    fill(well.insetBy(dx: -pixel, dy: -pixel), shadow)
    fill(CGRect(x: well.minX, y: well.maxY, width: well.width, height: pixel), light)
    fill(CGRect(x: well.maxX, y: well.minY, width: pixel, height: well.height), light)
    fill(well, selected
      ? NSColor(calibratedRed: 0.17, green: 0.25, blue: 0.10, alpha: 1)
      : NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.06, alpha: 1))
    if selected {
      fill(CGRect(x: well.minX + pixel, y: well.maxY - 2 * pixel,
        width: well.width - 2 * pixel, height: pixel),
        NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.22, alpha: 1))
    }
  }
}
