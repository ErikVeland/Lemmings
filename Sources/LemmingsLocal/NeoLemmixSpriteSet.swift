import AppKit
import ImageIO
import NxlvKit

enum NeoLemmixSpriteSetError: Error, LocalizedError {
  case missingTheme(String)
  case missingLemmingStyle(String)
  case missingScheme(String)
  case missingAnimation(String)
  case invalidAnimation(String)

  var errorDescription: String? {
    switch self {
    case let .missingTheme(style): return "The NeoLemmix theme '\(style)' could not be loaded."
    case let .missingLemmingStyle(style): return "The NeoLemmix lemming style '\(style)' could not be loaded."
    case let .missingScheme(style): return "The NeoLemmix lemming style '\(style)' has no scheme.nxmi."
    case let .missingAnimation(name): return "The NeoLemmix lemming style has no \(name) animation."
    case let .invalidAnimation(name): return "The NeoLemmix \(name) animation has invalid frame geometry."
    }
  }
}

/// Runtime NeoLemmix sprite artwork. The app retains no third-party pixels;
/// frames are loaded from the styles directory selected by the player.
final class NeoLemmixSpriteSet {
  struct Frame {
    let image: NSImage
    let rgba: [UInt8]
    let width: Int
    let height: Int
    let footX: Int
    let footY: Int
    let cacheKey: String
  }

  private struct Animation {
    let frames: Int
    let loopFrame: Int?
    let rightFoot: (x: Int, y: Int)
    let leftFoot: (x: Int, y: Int)
    let sheet: CGImage
    let frameWidth: Int
    let frameHeight: Int
  }

  private let animations: [String: Animation]
  private let baseRecoloring: [UInt32: UInt32]
  private let athleteRecoloring: [UInt32: UInt32]
  private let zombieRecoloring: [UInt32: UInt32]
  private let neutralRecoloring: [UInt32: UInt32]
  private let stonerTerrainImage: NSImage?
  private let stonerTerrainRGBA: [UInt8]
  private let stonerTerrainWidth: Int
  private let stonerTerrainHeight: Int
  private var frameCache: [String: Frame] = [:]

  init(stylesRootURL: URL, themeStyle: String) throws {
    let resolver = NxlvStyleResolver(stylesRootURL: stylesRootURL)
    let requestedTheme = themeStyle.isEmpty ? "default" : themeStyle
    let theme = resolver.resolve(references: [
      NxlvStyleAssetReference(kind: .theme, style: requestedTheme),
    ])
    guard theme.isComplete, let themeURL = theme.assets.first?.metadataURL,
          let themeText = try? String(contentsOf: themeURL, encoding: .utf8) else {
      throw NeoLemmixSpriteSetError.missingTheme(requestedTheme)
    }
    let themeDocument = NxlvParser.parse(themeText)
    let lemmingStyle = themeDocument.trimmedLine("lemmings") ?? "default"
    let resolution = resolver.resolve(references: [
      NxlvStyleAssetReference(kind: .lemmings, style: lemmingStyle),
    ])
    guard resolution.isComplete, let asset = resolution.assets.first else {
      throw NeoLemmixSpriteSetError.missingLemmingStyle(lemmingStyle)
    }
    guard let schemeURL = asset.metadataURL,
          let schemeText = try? String(contentsOf: schemeURL, encoding: .utf8) else {
      throw NeoLemmixSpriteSetError.missingScheme(lemmingStyle)
    }
    let scheme = NxlvParser.parse(schemeText)
    let sourceColors = Self.namedColors(in: scheme.section("spriteset_recoloring"))
    let themeColors = Self.namedColors(in: themeDocument.section("colors"))
    var themeRecoloring: [UInt32: UInt32] = [:]
    for (name, source) in sourceColors {
      if let target = themeColors[name] { themeRecoloring[source] = target }
    }
    let shades = Self.shades(in: scheme.section("shades"))
    for (alternate, primary) in shades {
      if let target = themeRecoloring[primary] {
        themeRecoloring[alternate] = Self.applyColorShift(
          to: target,
          primary: primary,
          alternate: alternate
        )
      }
    }
    baseRecoloring = themeRecoloring
    let states = scheme.section("state_recoloring")
    athleteRecoloring = Self.stateColors(
      in: states, name: "athlete", palette: themeRecoloring, shades: shades
    )
    zombieRecoloring = Self.stateColors(
      in: states, name: "zombie", palette: themeRecoloring, shades: shades
    )
    neutralRecoloring = Self.stateColors(
      in: states, name: "neutral", palette: themeRecoloring, shades: shades
    )
    let stonerURL = stylesRootURL.deletingLastPathComponent()
      .appendingPathComponent("gfx/mask/stoner.png")
    if let source = CGImageSourceCreateWithURL(stonerURL as CFURL, nil),
       let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
       let rgba = Self.rgba(image) {
      stonerTerrainImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
      stonerTerrainRGBA = rgba
      stonerTerrainWidth = image.width
      stonerTerrainHeight = image.height
    } else {
      stonerTerrainImage = nil
      stonerTerrainRGBA = []
      stonerTerrainWidth = 0
      stonerTerrainHeight = 0
    }

    let graphics = Dictionary(uniqueKeysWithValues: asset.graphicURLs.map {
      ($0.deletingPathExtension().lastPathComponent.lowercased(), $0)
    })
    guard let animationSections = scheme.section("animations") else {
      throw NeoLemmixSpriteSetError.missingScheme(lemmingStyle)
    }
    var decoded: [String: Animation] = [:]
    for section in animationSections.subsections {
      let name = section.keyword.lowercased()
      guard let frameCount = section.numeric("frames"), frameCount > 0,
            let right = section.section("right"), let left = section.section("left"),
            let rightX = right.numeric("foot_x"), let rightY = right.numeric("foot_y"),
            let leftX = left.numeric("foot_x"), let leftY = left.numeric("foot_y"),
            let graphicURL = graphics[name],
            let source = CGImageSourceCreateWithURL(graphicURL as CFURL, nil),
            let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
            sheet.width.isMultiple(of: 2), sheet.height.isMultiple(of: frameCount) else {
        continue
      }
      let width = sheet.width / 2
      let height = sheet.height / frameCount
      guard width > 0, height > 0,
            (0...width).contains(rightX), (0...height).contains(rightY),
            (0...width).contains(leftX), (0...height).contains(leftY) else { continue }
      decoded[name] = Animation(
        frames: frameCount,
        loopFrame: section.numeric("loop_to_frame"),
        rightFoot: (rightX, rightY),
        leftFoot: (leftX, leftY),
        sheet: sheet,
        frameWidth: width,
        frameHeight: height
      )
    }
    animations = decoded
    for name in Set(NeoLemmixAction.allCases.compactMap(Self.animationName)) {
      guard decoded[name] != nil else { throw NeoLemmixSpriteSetError.missingAnimation(name) }
    }
  }

  func frame(
    action: NeoLemmixAction,
    direction: NeoLemmixDirection,
    animationFrame: Int,
    traits: Set<NeoLemmixTrait>
  ) -> Frame? {
    guard let name = Self.animationName(action), let animation = animations[name] else { return nil }
    let index = Self.frameIndex(
      action: action,
      animationFrame: animationFrame,
      count: animation.frames,
      loopFrame: animation.loopFrame
    )
    let traitKey = traits.map(\.rawValue).sorted().joined(separator: ",")
    let cacheKey = "\(name)-\(direction.rawValue)-\(index)-\(traitKey)"
    if let cached = frameCache[cacheKey] { return cached }
    // NeoLemmix sprite sheets store left-facing frames in the first column
    // and right-facing frames in the second. This ordering is the reverse of
    // the direction sections in scheme.nxmi.
    let column = direction == .left ? 0 : 1
    let crop = CGRect(
      x: column * animation.frameWidth,
      y: index * animation.frameHeight,
      width: animation.frameWidth,
      height: animation.frameHeight
    )
    guard let pixels = animation.sheet.cropping(to: crop),
          let recolored = recolor(pixels, traits: traits),
          let rgba = Self.rgba(recolored) else { return nil }
    let foot = direction == .left ? animation.leftFoot : animation.rightFoot
    let result = Frame(
      image: NSImage(cgImage: recolored, size: NSSize(width: animation.frameWidth, height: animation.frameHeight)),
      rgba: rgba,
      width: animation.frameWidth,
      height: animation.frameHeight,
      footX: foot.x,
      footY: foot.y,
      cacheKey: cacheKey
    )
    if frameCache.count < 4096 { frameCache[cacheKey] = result }
    return result
  }

  /// CE draws this shared 16×11 mask into the terrain when a Stoner finishes.
  func stonerTerrain() -> NSImage? { stonerTerrainImage }

  func stonerTerrainPixels() -> (rgba: [UInt8], width: Int, height: Int)? {
    guard stonerTerrainWidth > 0, stonerTerrainHeight > 0,
          stonerTerrainRGBA.count == stonerTerrainWidth * stonerTerrainHeight * 4 else { return nil }
    return (stonerTerrainRGBA, stonerTerrainWidth, stonerTerrainHeight)
  }

  private static func rgba(_ image: CGImage) -> [UInt8]? {
    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
      data: &bytes,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    for offset in stride(from: 0, to: bytes.count, by: 4) {
      let alpha = Int(bytes[offset + 3])
      guard alpha > 0 && alpha < 255 else { continue }
      for channel in 0..<3 {
        bytes[offset + channel] = UInt8(min(255, (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha))
      }
    }
    return bytes
  }

  private func recolor(_ image: CGImage, traits: Set<NeoLemmixTrait>) -> CGImage? {
    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
      data: &bytes,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] != 0 {
      let source = Self.color(bytes[offset], bytes[offset + 1], bytes[offset + 2])
      var color = baseRecoloring[source] ?? source
      if !traits.isDisjoint(with: [
        .slider, .climber, .swimmer, .floater, .glider, .disarmer,
      ]) {
        color = athleteRecoloring[color] ?? color
      }
      if traits.contains(.zombie) { color = zombieRecoloring[color] ?? color }
      if traits.contains(.neutral) { color = neutralRecoloring[color] ?? color }
      bytes[offset] = UInt8((color >> 16) & 0xFF)
      bytes[offset + 1] = UInt8((color >> 8) & 0xFF)
      bytes[offset + 2] = UInt8(color & 0xFF)
    }
    return context.makeImage()
  }

  private static func frameIndex(
    action: NeoLemmixAction,
    animationFrame: Int,
    count: Int,
    loopFrame: Int?
  ) -> Int {
    let frame = max(0, animationFrame)
    if action == .jumping, count == 3 {
      if frame <= 5 { return 0 }
      if frame == 6 { return 1 }
      return 2
    }
    if let loopFrame, frame >= count {
      return min(count - 1, loopFrame + (frame - loopFrame) % max(1, count - loopFrame))
    }
    return frame % count
  }

  private static func animationName(_ action: NeoLemmixAction) -> String? {
    switch action {
    case .walking: "walker"
    case .ascending: "ascender"
    case .falling: "faller"
    case .climbing: "climber"
    case .hoisting: "hoister"
    case .floating: "floater"
    case .gliding: "glider"
    case .dehoisting: "dehoister"
    case .sliding: "slider"
    case .swimming: "swimmer"
    case .blocking: "blocker"
    case .building: "builder"
    case .platforming: "platformer"
    case .stacking: "stacker"
    case .bashing: "basher"
    case .fencing: "fencer"
    case .lasering: "laserer"
    case .mining: "miner"
    case .digging: "digger"
    case .jumping: "jumper"
    case .reaching: "reacher"
    case .shimmying: "shimmier"
    case .disarming: "disarmer"
    case .shrugging: "shrugger"
    case .ohNo: "ohnoer"
    case .stoning: "ohnoer"
    case .stoneFinish: "stoner"
    case .exploding: "bomber"
    case .splatting: "splatter"
    case .exiting: "exiter"
    case .drowning: "drowner"
    case .vaporizing: "burner"
    case .teleporting, .removed: nil
    }
  }

  private static func namedColors(in section: NxlvSection?) -> [String: UInt32] {
    guard let section else { return [:] }
    return Dictionary(uniqueKeysWithValues: section.lineRecords.compactMap { line in
      parseColor(line.value).map { (line.keyword.lowercased(), $0) }
    })
  }

  private static func stateColors(
    in section: NxlvSection?,
    name: String,
    palette: [UInt32: UInt32],
    shades: [UInt32: UInt32]
  ) -> [UInt32: UInt32] {
    guard let sections = section?.allSections(name) else { return [:] }
    var result: [UInt32: UInt32] = [:]
    for item in sections {
      guard let from = item.trimmedLine("from").flatMap(parseColor),
            let to = item.trimmedLine("to").flatMap(parseColor) else { continue }
      let themedFrom = palette[from] ?? from
      let themedTo = palette[to] ?? to
      result[themedFrom] = themedTo
      for (alternate, primary) in shades where primary == from {
        result[
          applyColorShift(to: themedFrom, primary: primary, alternate: alternate)
        ] = applyColorShift(to: themedTo, primary: primary, alternate: alternate)
      }
    }
    return result
  }

  private static func shades(in section: NxlvSection?) -> [UInt32: UInt32] {
    guard let sections = section?.allSections("shade") else { return [:] }
    var result: [UInt32: UInt32] = [:]
    for item in sections {
      guard let primary = item.trimmedLine("primary").flatMap(parseColor) else { continue }
      for line in item.lineRecords where line.keyword.caseInsensitiveCompare("alt") == .orderedSame {
        if let alternate = parseColor(line.value) { result[alternate] = primary }
      }
    }
    return result
  }

  /// Matches NeoLemmix's ApplyColorShift: carry the primary-to-alternate HSV
  /// delta onto the theme color, then correct conversion rounding per channel.
  private static func applyColorShift(
    to base: UInt32,
    primary: UInt32,
    alternate: UInt32
  ) -> UInt32 {
    let primaryHSV = hsv(primary)
    let alternateHSV = hsv(alternate)
    let firstPass = shifted(
      primary,
      hue: alternateHSV.h - primaryHSV.h,
      saturation: alternateHSV.s - primaryHSV.s,
      value: alternateHSV.v - primaryHSV.v
    )
    let redAdjustment = component(alternate, shift: 16) - component(firstPass, shift: 16)
    let greenAdjustment = component(alternate, shift: 8) - component(firstPass, shift: 8)
    let blueAdjustment = component(alternate, shift: 0) - component(firstPass, shift: 0)
    let shiftedBase = shifted(
      base,
      hue: alternateHSV.h - primaryHSV.h,
      saturation: alternateHSV.s - primaryHSV.s,
      value: alternateHSV.v - primaryHSV.v
    )
    return color(
      clamp(component(shiftedBase, shift: 16) + redAdjustment),
      clamp(component(shiftedBase, shift: 8) + greenAdjustment),
      clamp(component(shiftedBase, shift: 0) + blueAdjustment)
    )
  }

  private static func hsv(_ color: UInt32) -> (h: Double, s: Double, v: Double) {
    let red = Double(component(color, shift: 16)) / 255
    let green = Double(component(color, shift: 8)) / 255
    let blue = Double(component(color, shift: 0)) / 255
    let maximum = max(red, green, blue)
    let minimum = min(red, green, blue)
    let delta = maximum - minimum
    var hue = 0.0
    if delta != 0 {
      if maximum == red {
        hue = (green - blue) / delta
        if hue < 0 { hue += 6 }
      } else if maximum == green {
        hue = (blue - red) / delta + 2
      } else {
        hue = (red - green) / delta + 4
      }
      hue /= 6
    }
    return (hue, maximum == 0 ? 0 : delta / maximum, maximum)
  }

  private static func shifted(
    _ sourceColor: UInt32,
    hue hueShift: Double,
    saturation saturationShift: Double,
    value valueShift: Double
  ) -> UInt32 {
    let source = hsv(sourceColor)
    var hue = source.h + hueShift
    hue.formTruncatingRemainder(dividingBy: 1)
    if hue < 0 { hue += 1 }
    let saturation = min(1, max(0, source.s + saturationShift))
    let value = min(1, max(0, source.v + valueShift))
    let chroma = value * saturation
    let sector = hue * 6
    let intermediate = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let rgb: (Double, Double, Double)
    switch sector {
    case 0..<1: rgb = (chroma, intermediate, 0)
    case 1..<2: rgb = (intermediate, chroma, 0)
    case 2..<3: rgb = (0, chroma, intermediate)
    case 3..<4: rgb = (0, intermediate, chroma)
    case 4..<5: rgb = (intermediate, 0, chroma)
    default: rgb = (chroma, 0, intermediate)
    }
    let match = value - chroma
    return color(
      Int(((rgb.0 + match) * 255).rounded()),
      Int(((rgb.1 + match) * 255).rounded()),
      Int(((rgb.2 + match) * 255).rounded())
    )
  }

  private static func component(_ color: UInt32, shift: UInt32) -> Int {
    Int((color >> shift) & 0xFF)
  }

  private static func clamp(_ value: Int) -> Int { min(255, max(0, value)) }

  private static func parseColor(_ value: String) -> UInt32? {
    var token = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if token.first == "x" || token.first == "X" { token.removeFirst() }
    guard token.count == 6 else { return nil }
    return UInt32(token, radix: 16)
  }

  private static func color(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> UInt32 {
    UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
  }

  private static func color(_ red: Int, _ green: Int, _ blue: Int) -> UInt32 {
    UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
  }
}
