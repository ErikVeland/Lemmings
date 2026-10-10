import AppKit
import NxlvKit

/// A small permanent-skill marker, baked into each cached Classic sprite.
@MainActor enum ClassicSkillBackpack {
  enum Kind: String {
    case climber, floater, both

    var colours: [[UInt8]] {
      switch self {
      case .climber: [[205, 149, 83], [151, 92, 47], [100, 58, 32]]
      case .floater: [[255, 192, 75], [240, 133, 36], [178, 72, 20]]
      case .both: [[206, 138, 240], [155, 78, 198], [96, 42, 135]]
      }
    }
  }

  static func kind(for lemming: SessionLemming) -> Kind? {
    guard lemming.neoAction == nil else { return nil }
    switch lemming.pose {
    case .drowning, .splatting, .frying, .explosion, .exiting: return nil
    default: break
    }
    if lemming.hasClimber && lemming.hasFloater { return .both }
    if lemming.hasClimber { return .climber }
    if lemming.hasFloater { return .floater }
    return nil
  }

  /// Mac sprites use two artwork pixels per simulation pixel.
  static func image(rgba: Data, width: Int, height: Int, pixelScale: Int,
                    pose: ClassicLemmingPose, left: Bool, kind: Kind?) -> NSImage? {
    let padding = kind == nil ? 0 : 2 * pixelScale
    let outputWidth = width + 2 * padding
    var pixels = [UInt8](repeating: 0, count: outputWidth * height * 4)
    var hairTop = height
    var body: [(x: Int, y: Int)] = []
    for y in 0..<height {
      for x in 0..<width {
        let source = (y * width + x) * 4
        let dest = (y * outputWidth + x + padding) * 4
        for component in 0..<4 { pixels[dest + component] = rgba[source + component] }
        guard rgba[source + 3] > 0 else { continue }
        let r = Int(rgba[source]), g = Int(rgba[source + 1]), b = Int(rgba[source + 2])
        if g > 100 && g > r * 2 && g > b * 2 { hairTop = min(hairTop, y) }
        // Seasonal lemmings wear red coats instead of the usual blue suit.
        if (b > 128 && b > r * 2 && b > g * 2)
          || (r > 128 && r > g * 2 && r > b * 2) { body.append((x, y)) }
      }
    }
    // Ignore the umbrella shaft and tools. The torso starts below the hair.
    let uprightTorso = body.filter { $0.y >= hairTop + 3 * pixelScale }
    // Some seasonal digging frames tuck the head below the coat.
    let torso = uprightTorso.isEmpty ? body : uprightTorso
    if let kind, let top = torso.map(\.y).min() {
      // Umbrella poses turn the lemming's body against its travel direction.
      let left = (pose == .floating || pose == .umbrellaOpening) ? !left : left
      let shoulders = torso.filter { $0.y < top + 2 * pixelScale }
      let back = left ? shoulders.map(\.x).max()! : shoulders.map(\.x).min()!
      let startX = padding + (left ? back + 1 : back - 2 * pixelScale)
      let colours = kind.colours
      for dy in 0..<(3 * pixelScale) where top + dy < height {
        for dx in 0..<(2 * pixelScale) {
          let x = startX + dx
          guard (0..<outputWidth).contains(x) else { continue }
          let i = ((top + dy) * outputWidth + x) * 4
          let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
          // Hair, face and hands remain in front of the pack.
          if pixels[i + 3] > 0 && ((g > 100 && g > r * 2 && g > b * 2)
            || (r > 180 && g > 150 && b > 130)
            || (r > 220 && g > 120 && b < 70)) { continue }
          let outer = left ? dx >= pixelScale : dx < pixelScale
          let colour = colours[dy < pixelScale ? 0 : outer ? 2 : 1]
          for component in 0..<3 { pixels[i + component] = colour[component] }
          pixels[i + 3] = 255
        }
      }
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData),
      let image = CGImage(width: outputWidth, height: height, bitsPerComponent: 8,
        bitsPerPixel: 32, bytesPerRow: outputWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else { return nil }
    return NSImage(cgImage: image, size: CGSize(width: outputWidth, height: height))
  }
}
