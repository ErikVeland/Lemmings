#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

/// Original Amiga control tiles, with separate glyphs for Resume and Undo.
/// Source pixels use the Amiga panel aspect ratio and a reference-matched colour palette.
enum PanelGlyph: String {
  case nuke
  case pause
  case undo
  case fastForward
  case rewind, stepBackward, stepForward
  case settings, download
  /// Shown on the pause button while the level is held, so the button says
  /// what it will do rather than what it did.
  case play
  /// Plain Amiga panel rock, drawn behind the skill sprites.
  case rock

  private var art: PanelGlyphArt { PanelGlyphArt(rawValue: rawValue)! }
  private var rows: [String] { art.rows }
  private var palette: [Character: (UInt8, UInt8, UInt8)] { art.palette }

  var isOriginalTile: Bool { self == .pause || self == .nuke || self == .rock }

  /// The glyph's own size, before any scaling.
  var pixelSize: (width: Int, height: Int) {
    let rows = self.rows
    return ((rows.first?.count ?? 0) / (isOriginalTile ? 2 : 1), rows.count)
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

  /**
   * Recreates the panel art at Macintosh scale without changing its logical size.
   */
  @MainActor func macImage(fitting box: CGSize) -> NSImage? {
    let size = pixelSize
    guard size.width > 0, size.height > 0 else { return nil }
    let steps = min(Int(box.width) / size.width, Int(box.height) / size.height)
    guard steps >= 1 else { return nil }
    let key = "mac-\(rawValue)-\(steps)-\(SequelMacArtwork.revision)"
    if let hit = Self.cache[key] { return hit }
    guard let first = rows.first else { return nil }
    let width = first.count, height = rows.count
    var source = [UInt8](repeating: 0, count: width * height * 4)
    for (y, row) in rows.enumerated() {
      for (x, symbol) in row.enumerated() {
        guard let colour = palette[symbol] else { continue }
        let offset = (y * width + x) * 4
        source[offset..<offset + 4] = [colour.0, colour.1, colour.2, 255]
      }
    }
    let highWidth = size.width * 2, highHeight = size.height * 2
    var high = [UInt8](repeating: 0, count: highWidth * highHeight * 4)
    if isOriginalTile {
      guard let frame = try? SequelMacFrame(width: width, height: height, rgba: source),
            let recreated = try? SequelMacArtwork.reconstruct(frame,
              category: .architectural) else { return image(scale: steps) }
      for y in 0..<highHeight { for x in 0..<highWidth {
        let from = (y * recreated.width + x * 2) * 4
        let to = (y * highWidth + x) * 4
        high[to..<to + 4] = recreated.rgba[from..<from + 4]
      } }
    } else {
      // Small control symbols have one flat source colour. Edge light and shade
      // supply detail within their existing opaque cells.
      for y in 0..<height { for x in 0..<width {
        let sourceIndex = (y * width + x) * 4
        guard source[sourceIndex + 3] == 255 else { continue }
        let top = y == 0 || source[((y - 1) * width + x) * 4 + 3] == 0
        let left = x == 0 || source[(y * width + x - 1) * 4 + 3] == 0
        let bottom = y == height - 1 || source[((y + 1) * width + x) * 4 + 3] == 0
        let right = x == width - 1 || source[(y * width + x + 1) * 4 + 3] == 0
        for dy in 0..<2 { for dx in 0..<2 {
          let output = ((y * 2 + dy) * highWidth + x * 2 + dx) * 4
          let lighten = (top && dy == 0) || (left && dx == 0)
          let darken = !lighten && ((bottom && dy == 1) || (right && dx == 1))
          for channel in 0..<3 {
            let colour = Int(source[sourceIndex + channel])
            high[output + channel] = UInt8(lighten
              ? min(255, colour + max(12, (255 - colour) / 5))
              : darken ? max(0, colour - max(12, colour / 4)) : colour)
          }
          high[output + 3] = 255
        } }
      } }
    }
    let bitmapWidth = highWidth * steps, bitmapHeight = highHeight * steps
    var pixels = [UInt8](repeating: 0, count: bitmapWidth * bitmapHeight * 4)
    for y in 0..<bitmapHeight { for x in 0..<bitmapWidth {
      let from = ((y / steps) * highWidth + x / steps) * 4
      let to = (y * bitmapWidth + x) * 4
      pixels[to..<to + 4] = high[from..<from + 4]
    } }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
          let bitmap = CGImage(width: bitmapWidth, height: bitmapHeight,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bitmapWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent) else { return nil }
    let result = NSImage(cgImage: bitmap,
      size: CGSize(width: size.width * steps, height: size.height * steps))
    Self.cache[key] = result
    return result
  }

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

    let image = NSImage(cgImage: cgImage, size: CGSize(width: width / (isOriginalTile ? 2 : 1), height: height))
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
    static let help = "Click speed to toggle. Hold to boost; release to return. Arrows apply 1×, 2×, 3×, 5× or 10× immediately."
    static func part(at point: CGPoint, in rect: CGRect) -> Int? { SpeedPanelArt.part(at: point, in: rect) }
    /// `bevelPixel` sets only the stone bevel. The contents keep their layout pixel, so a
    /// panel can match its neighbouring sockets without moving the label or arrows.
    /// `text` draws the speed label. A panel with a game font passes its own; the default is the pixel font.
    static func draw(in rect: CGRect, label: String, active: Bool, bevelPixel: CGFloat? = nil,
        backdrop: NSImage? = nil, text: ((String, CGRect) -> Void)? = nil) {
        let text = text ?? { GamePixelText.draw($0, in: $1, maxScale: .greatestFiniteMagnitude) }
        let boxes = SpeedPanelArt.boxes(in: rect)
        let pixel = SpeedPanelArt.pixel(forHeight: rect.height)
        GameStoneButton.draw(rect, selected: active, pixel: bevelPixel ?? pixel, backdrop: backdrop)
        for (index, box) in boxes.enumerated() {
            if index == 1 {
                // The label always names the speed the game is running at now.
                text(label, box.insetBy(dx: rect.height >= 60 ? 4 * pixel : pixel, dy: 6 * pixel))
            } else if let context = NSGraphicsContext.current?.cgContext {
                SpeedPanelArt.drawArrow(in: context, box: box, pointsRight: index == 2)
            }
        }
    }
}

/// Shared stone sockets for controls added beside the original panel artwork.
@MainActor enum GameStoneButton {
  /// The recessed area inside the bevel, where a glyph belongs.
  static func well(_ frame: CGRect, pixel: CGFloat) -> CGRect {
    GameStoneArt.well(frame, pixel: pixel)
  }

  /// Draws an original panel tile at the scale that fills the whole button, cropped to the
  /// well. The tile keeps its size, and its textured edge gives way to the stone bevel.
  /// A button wider than the tile repeats it side by side.
  static func drawTile(_ image: NSImage, in frame: CGRect, pixel: CGFloat) {
    guard let context = NSGraphicsContext.current?.cgContext,
      let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    GameStoneArt.drawTile(in: context, image: bitmap, logicalSize: image.size, frame: frame, pixel: pixel)
  }

  /// `backdrop` replaces the flat well colour, for example with panel rock.
  static func draw(_ frame: CGRect, selected: Bool, pixel: CGFloat, backdrop: NSImage? = nil) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    GameStoneArt.drawSocket(in: context, frame: frame, selected: selected, pixel: pixel)
    if let backdrop { drawTile(backdrop, in: frame, pixel: pixel) }
    GameStoneArt.drawAccent(in: context, frame: frame, selected: selected, pixel: pixel)
  }
}
#endif
