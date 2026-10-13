import CoreGraphics
import Foundation

/// Original Amiga control tiles, with separate glyphs for Resume and Undo.
/// Source pixels use the Amiga panel aspect ratio and a reference-matched colour palette.
public enum PanelGlyphArt: String, Sendable {
  case nuke
  case pause
  case undo
  case fastForward
  case rewind, stepBackward, stepForward
  case settings, download, menu, mobileMenu, reveal, dismiss
  /// Shown on the pause button while the level is held, so the button says
  /// what it will do rather than what it did.
  case play
  /// Plain Amiga panel rock, drawn behind the skill sprites.
  case rock

  /// A dot leaves the button showing through. Every other mark is a colour
  /// the glyph names below.
  public var rows: [String] {
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
    case .menu:
      return ["############", "############", "............", "............", "############", "############", "............", "............", "############", "############"]
    case .mobileMenu:
      return [".############.", "##############", "..............", "..............", ".############.", "##############", "..............", "..............", ".############.", "##############"]
    case .reveal:
      return [".....##", "....##.", "...##..", "..##...", ".##....", "##.....", ".##....", "..##...", "...##..", "....##.", ".....##"]
    case .dismiss:
      return PanelGlyphArt.reveal.rows.map { String($0.reversed()) }
    case .fastForward:
      return ["#.....#.....", "##....##....", "###...###...", "####..####..", "#####.#####.", "############", "#####.#####.", "####..####..", "###...###...", "##....##....", "#.....#.....", "............"]
    case .rewind:
      return PanelGlyphArt.fastForward.rows.map { String($0.reversed()) }
    case .stepForward:
      return ["#.......##", "##......##", "###.....##", "####....##", "#####...##", "######..##", "#####...##", "####....##", "###.....##", "##......##", "#.......##"]
    case .stepBackward:
      return PanelGlyphArt.stepForward.rows.map { String($0.reversed()) }
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
    case .download:
      return [
        ".....###.....", ".....###.....", ".....###.....", ".....###.....",
        "..#..###..#..", "..#########..", "...#######...", "....#####....",
        ".....###.....", "......#......", ".............", "##.........##",
        "#############", "#############",
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

  public var palette: [Character: (UInt8, UInt8, UInt8)] {
    switch self {
    case .pause, .nuke, .rock:
      return Dictionary(uniqueKeysWithValues: Self.classicPalette.enumerated().map { index, colour in
        (Character(String(index, radix: 16)), (colour.red, colour.green, colour.blue))
      })
    case .play, .fastForward, .undo, .settings, .download, .menu, .mobileMenu, .reveal, .dismiss, .rewind, .stepBackward, .stepForward:
      return ["#": (194, 224, 158)]
    }
  }

  // Amiga panel1: 640×40, four planar bitplanes. Crop the two 32×24 cells
  // at (320,16) and (352,16) by two horizontal and one vertical border pixels.
  // Rock takes the same crop from the ten skill cells. Tools/ClassicPanelArt/check.py
  // shows how it is rebuilt where the lemmings and counter boxes cover it.
  // The panel uses half-width horizontal pixels. Colours match the reference
  // panel; this is not a claim that its original hardware palette was recovered.
  private static let classicPalette: [(red: UInt8, green: UInt8, blue: UInt8)] = [
    (red: 0, green: 0, blue: 0),
    (red: 255, green: 255, blue: 255),
    (red: 255, green: 136, blue: 0),
    (red: 0, green: 187, blue: 0),
    (red: 255, green: 238, blue: 0),
    (red: 255, green: 221, blue: 221),
    (red: 221, green: 51, blue: 0),
    (red: 102, green: 68, blue: 238),
    (red: 238, green: 221, blue: 221),
    (red: 68, green: 17, blue: 17),
    (red: 102, green: 34, blue: 34),
    (red: 119, green: 51, blue: 51),
    (red: 136, green: 68, blue: 68),
    (red: 153, green: 85, blue: 85),
    (red: 187, green: 119, blue: 119),
    (red: 255, green: 255, blue: 136),
  ]

  public var isOriginalTile: Bool { self == .pause || self == .nuke || self == .rock }

  /// The glyph's own size, before any scaling.
  public var pixelSize: (width: Int, height: Int) {
    let rows = self.rows
    return ((rows.first?.count ?? 0) / (isOriginalTile ? 2 : 1), rows.count)
  }

  /// The largest whole-number scale that fits a box, or 0 when none does.
  public func scale(fitting box: CGSize) -> Int {
    let size = pixelSize
    guard size.width > 0, size.height > 0 else { return 0 }
    return min(Int(box.width) / size.width, Int(box.height) / size.height)
  }

  /// Renders the glyph at a whole-number scale. The image is `rows × scale` pixels, so an
  /// original tile (stored at half horizontal resolution) is twice as wide as its logical size.
  public func cgImage(scale: Int) -> CGImage? {
    let steps = max(1, scale)
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
    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
    return CGImage(
      width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
}
