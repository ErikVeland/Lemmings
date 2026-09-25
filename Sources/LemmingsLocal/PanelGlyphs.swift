import AppKit
import NxlvKit

/// Original Amiga control tiles, with separate glyphs for Resume and Undo.
/// Source pixels use the Amiga panel aspect ratio and a reference-matched colour palette.
enum PanelGlyph: String {
  case nuke
  case pause
  case undo
  case fastForward
  case settings
  /// Shown on the pause button while the level is held, so the button says
  /// what it will do rather than what it did.
  case play
  /// Plain Amiga panel rock, drawn behind the skill sprites.
  case rock

  /// A dot leaves the button showing through. Every other mark is a colour
  /// the glyph names below.
  private var rows: [String] {
    switch self {
    case .nuke:
      return [
        "aa9aabbabaaa99aaabbbbbab9aba",
        "aaababba99a999aa999aabbb99aa",
        "aa9ccfff4f4f444264264246a99b",
        "aafff4f4f464466426622262262a",
        "bfff4ff466466662226626262262",
        "f6ff64f466446622266222262426",
        "c4f6466f46644264422222426262",
        "bccddeeeffff466426244eedeecb",
        "a9accccddefff646624dcbbbaabb",
        "aa99baaaacdff44464ab9abab99b",
        "aaa9acfffff4f44666624699abab",
        "bcbcfff64f4f6446262266229aa9",
        "aabacd6f6664f4626266622b99b9",
        "a99aaccddedfff4624cddc99bbba",
        "a999aaabacfff444626a99b9abbc",
        "aa9999aacff4f44446269aabbccc",
        "ccaa999cfff444666622699cb9ca",
        "bbbaacffff4f444466662269a9b9",
        "aaafffff4f4464666622626266aa",
        "cffff4f4f4464664622622262266",
        "cdeeeedddeeeeedddeedeeddeccb",
        "eeddeeddeecdeeddeecddcdccbbb",
      ]
    case .undo:
      return [".....####...", "...########.", "..###....###", "..##......##", "#.##........", "####........", "###.........", "####........", "#####.......", "...........#", "...#########", ".....#####.."]
    case .fastForward:
      return ["#.....#.....", "##....##....", "###...###...", "####..####..", "#####.#####.", "############", "#####.#####.", "####..####..", "###...###...", "##....##....", "#.....#.....", "............"]
    case .settings:
      return [
        "......###......",
        "..##..###..##..",
        ".####.###.####.",
        ".#############.",
        "..####...####..",
        "...##.....##...",
        "####.......####",
        "#####.....#####",
        "####.......####",
        "...##.....##...",
        "..####...####..",
        ".#############.",
        ".####.###.####.",
        "..##..###..##..",
        "......###......",
      ]
    case .pause:
      return [
        "aaa99aa9aabbaa99999a90aaab90",
        "acbb99aa999abbaaaa9a9e99ba9c",
        "aaccaaaaa9990cbbbb000cb9b000",
        "a99accbcaaa9e9aa900000e90000",
        "ba99bcccaa99a000a9000ea99000",
        "cbaaabccbba900000a99ccbbb99b",
        "ccbaabbccbbb9000dbdee0000dcc",
        "bcbaaaabcccbb99ce000000000dc",
        "bcccaaaaaaccca900000000000eb",
        "aaccc999accbc9900000000000db",
        "aabbccc900aabc9e000000000dbc",
        "b9bb9cc9ec999abebe00000edbbc",
        "909999000caa9000b9c9a9999abb",
        "9ea9900000c900000bbccaaa99aa",
        "d000a9000cba9000ccccccaaa9ab",
        "00000999cddddbb9bbccbbccaabb",
        "9000dbdde0000ecbbccbbbbcccbb",
        "b99be000000000ecbbbaaaabbcbb",
        "bb9000000000000c9abbaa99aab9",
        "aa9000000000000c999bbba9aaab",
        "aa9b0000000000dbba99abbbbbb9",
        "aab99bd00000dbbaaa999aaaab9a",
      ]
    case .rock:
      return [
        "aac999bbccaabbaaa999bbccaeaa",
        "aab9aaaaaaa9abbaa9aaaaaaecba",
        "aaa99ccaca99aabaa9cccaaadeba",
        "a9b999cc9d9abbbb9999c9999daa",
        "ba999ccbbbabbab9bb9ca99aecbb",
        "cba99cc99ababbbabaa99aaaecbb",
        "ccb99999abbbbcbbbaa9accbbdcb",
        "bcb99aa99aa9aa9999aaa9bbadbb",
        "bcca9aa99aa9aa9999aaa9bba99b",
        "aaccc999abbbbcbbbaa9accbbbcb",
        "aabbccc99ababbbabaa99aaabbbc",
        "b9bb9ccbbbabbab9bb9ca99aabbc",
        "bb9999cc9d9abbbb9999c9999abb",
        "baa9cccaca99aabaa9cccaaa99aa",
        "baa9aaaaaaa9abbaa9aaaaaaa9ab",
        "aaa999bbccaabbaaa999bbccaabb",
        "bbbbbbacbcccbbbbbbbbabbcccbb",
        "baaaaabbbbbcbbbaaaaabaabbcbb",
        "bbbcccca99aab9ebbcccca99aab9",
        "aaabbbbca9aaabaaabbbbba9aaab",
        "aaaabacccbbbb9aaaab9abbbbbb9",
        "aabb9aaaacccbbbaaa999aaaab9a",
      ]
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

  private var palette: [Character: (UInt8, UInt8, UInt8)] {
    switch self {
    case .pause, .nuke, .rock:
      return Dictionary(uniqueKeysWithValues: Self.classicPalette.enumerated().map { index, colour in
        (Character(String(index, radix: 16)), (colour.red, colour.green, colour.blue))
      })
    case .play, .fastForward, .undo, .settings:
      return ["#": (194, 224, 158)]
    }
  }

  // Amiga panel1: 640×40, four planar bitplanes. Crop the two 32×24 cells
  // at (320,16) and (352,16) by two horizontal and one vertical border pixels.
  // Rock takes the same crop from the ten skill cells. Tools/ClassicPanelArt/check.py
  // shows how it is rebuilt where the lemmings and counter boxes cover it.
  // The panel uses half-width horizontal pixels. Colours match the reference
  // panel; this is not a claim that its original hardware palette was recovered.
  private static let classicPalette: [ClassicRGBColor] = [
    ClassicRGBColor(red: 0, green: 0, blue: 0),
    ClassicRGBColor(red: 255, green: 255, blue: 255),
    ClassicRGBColor(red: 255, green: 136, blue: 0),
    ClassicRGBColor(red: 0, green: 187, blue: 0),
    ClassicRGBColor(red: 255, green: 238, blue: 0),
    ClassicRGBColor(red: 255, green: 221, blue: 221),
    ClassicRGBColor(red: 221, green: 51, blue: 0),
    ClassicRGBColor(red: 102, green: 68, blue: 238),
    ClassicRGBColor(red: 238, green: 221, blue: 221),
    ClassicRGBColor(red: 68, green: 17, blue: 17),
    ClassicRGBColor(red: 102, green: 34, blue: 34),
    ClassicRGBColor(red: 119, green: 51, blue: 51),
    ClassicRGBColor(red: 136, green: 68, blue: 68),
    ClassicRGBColor(red: 153, green: 85, blue: 85),
    ClassicRGBColor(red: 187, green: 119, blue: 119),
    ClassicRGBColor(red: 255, green: 255, blue: 136),
  ]

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
    static func part(at point: CGPoint, in rect: CGRect) -> Int? {
        guard rect.contains(point) else { return nil }
        if point.x < rect.minX + rect.width * 0.22 { return -1 }
        if point.x >= rect.maxX - rect.width * 0.22 { return 1 }
        return 0
    }
    /// `bevelPixel` sets only the stone bevel. The contents keep their layout pixel, so a
    /// panel can match its neighbouring sockets without moving the label or arrows.
    /// `text` draws the speed label. A panel with a game font passes its own; the default is the pixel font.
    static func draw(in rect: CGRect, label: String, active: Bool, bevelPixel: CGFloat? = nil,
        backdrop: NSImage? = nil, text: ((String, CGRect) -> Void)? = nil) {
        let text = text ?? { GamePixelText.draw($0, in: $1, maxScale: .greatestFiniteMagnitude) }
        let side = rect.width * 0.22
        let pixel = max(1, floor(rect.height / 24))
        let boxes = [CGRect(x: rect.minX, y: rect.minY, width: side, height: rect.height),
            CGRect(x: rect.minX + side, y: rect.minY, width: rect.width - 2 * side, height: rect.height),
            CGRect(x: rect.maxX - side, y: rect.minY, width: side, height: rect.height)]
        GameStoneButton.draw(rect, selected: active, pixel: bevelPixel ?? pixel, backdrop: backdrop)
        for (index, box) in boxes.enumerated() {
            if index == 1 {
                // The label always names the speed the game is running at now.
                text(label, box.insetBy(dx: rect.height >= 60 ? 4 * pixel : pixel, dy: 6 * pixel))
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
  /// The recessed area inside the bevel, where a glyph belongs.
  static func well(_ frame: CGRect, pixel: CGFloat) -> CGRect {
    frame.insetBy(dx: 4 * pixel, dy: 4 * pixel)
  }

  /// Draws an original panel tile at the scale that fills the whole button, cropped to the
  /// well. The tile keeps its size, and its textured edge gives way to the stone bevel.
  /// A button wider than the tile repeats it side by side.
  static func drawTile(_ image: NSImage, in frame: CGRect, pixel: CGFloat) {
    let width = image.size.width
    guard width > 0 else { return }
    let copies = max(1, Int(ceil(well(frame, pixel: pixel).width / width)))
    let left = floor(frame.midX - CGFloat(copies) * width / 2)
    let top = floor(frame.midY - image.size.height / 2)
    NSGraphicsContext.saveGraphicsState()
    well(frame, pixel: pixel).clip()
    for copy in 0..<copies {
      image.draw(in: CGRect(x: left + CGFloat(copy) * width, y: top, width: width, height: image.size.height),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    NSGraphicsContext.restoreGraphicsState()
  }

  /// `backdrop` replaces the flat well colour, for example with panel rock.
  static func draw(_ frame: CGRect, selected: Bool, pixel: CGFloat, backdrop: NSImage? = nil) {
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
    let well = Self.well(frame, pixel: pixel)
    fill(well.insetBy(dx: -pixel, dy: -pixel), shadow)
    fill(CGRect(x: well.minX, y: well.maxY, width: well.width, height: pixel), light)
    fill(CGRect(x: well.maxX, y: well.minY, width: pixel, height: well.height), light)
    fill(well, selected
      ? NSColor(calibratedRed: 0.17, green: 0.25, blue: 0.10, alpha: 1)
      : NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.06, alpha: 1))
    if let backdrop { drawTile(backdrop, in: frame, pixel: pixel) }
    if selected {
      fill(CGRect(x: well.minX + pixel, y: well.maxY - 2 * pixel,
        width: well.width - 2 * pixel, height: pixel),
        NSColor(calibratedRed: 0.62, green: 0.85, blue: 0.22, alpha: 1))
    }
  }
}
