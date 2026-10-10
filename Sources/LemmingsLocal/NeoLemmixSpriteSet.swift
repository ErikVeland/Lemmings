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
    var pixelScale: Int = 1
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
  private let sourceColors: [String: UInt32]
  private let sourceShades: [UInt32: UInt32]
  private let athleteRecoloring: [UInt32: UInt32]
  private let zombieRecoloring: [UInt32: UInt32]
  private let neutralRecoloring: [UInt32: UInt32]
  private let stonerTerrainImage: NSImage?
  private let stonerTerrainRGBA: [UInt8]
  private let stonerTerrainWidth: Int
  private let stonerTerrainHeight: Int
  private var frameCache: [String: Frame] = [:]
  @MainActor private var skillImages: [NeoLemmixSkill: NSImage] = [:]
  private let skillBrickColor: UInt32
  private let macArtwork: ClassicMacArtwork?
  private let classicAssets: ClassicMainDATAssets?
  var usesMacArtwork = false {
    didSet { if usesMacArtwork != oldValue { frameCache.removeAll(); clearSkillImages = true } }
  }
  private var clearSkillImages = false

  init(stylesRootURL: URL, themeStyle: String, macArtwork: ClassicMacArtwork? = nil, classicAssets: ClassicMainDATAssets? = nil) throws {
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
    skillBrickColor = Self.namedColors(in: themeDocument.section("colors"))["pickup_bricks"] ?? 0xFF_FF_FF
    let lemmingStyle = themeDocument.trimmedLine("lemmings") ?? "default"
    // Custom themes and recoloured trait states retain their authored sprites.
    self.macArtwork = lemmingStyle == "default" && (requestedTheme.hasPrefix("orig_") || requestedTheme.hasPrefix("ohno_")) ? macArtwork : nil
    self.classicAssets = classicAssets
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
    self.sourceColors = sourceColors
    let themeColors = Self.namedColors(in: themeDocument.section("colors"))
    var themeRecoloring: [UInt32: UInt32] = [:]
    for (name, source) in sourceColors {
      if let target = themeColors[name] { themeRecoloring[source] = target }
    }
    let shades = Self.shades(in: scheme.section("shades"))
    sourceShades = shades
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
    if usesMacArtwork, traits.isEmpty, let mac = macFrame(action: action, direction: direction, index: index,
        count: animation.frames, key: cacheKey) {
      if frameCache.count < 4096 { frameCache[cacheKey] = mac }
      return mac
    }
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
    if usesMacArtwork,
       let recreated = recreatedFrame(rgba: rgba, width: animation.frameWidth,
         height: animation.frameHeight, foot: foot, direction: direction,
         traits: traits, key: cacheKey) {
      if frameCache.count < 4096 { frameCache[cacheKey] = recreated }
      return recreated
    }
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

  private func macFrame(action: NeoLemmixAction, direction: NeoLemmixDirection, index: Int, count: Int, key: String) -> Frame? {
    let pose: ClassicLemmingPose
    var tick = index
    switch action {
    case .walking: pose = .walking
    case .falling: pose = .falling
    case .climbing: pose = .climbing
    case .hoisting: pose = .postClimb
    case .floating:
      pose = index < 4 ? .umbrellaOpening : .floating
      tick = index % 4
    case .blocking: pose = .blocking
    case .building: pose = .building
    case .bashing: pose = .bashing
    case .mining: pose = .mining
    case .digging: pose = .digging
    case .shrugging: pose = .shrugging
    case .ohNo: pose = .ohNo
    case .splatting: pose = .splatting
    case .exiting: pose = .exiting
    case .drowning: pose = .drowning
    case .vaporizing: pose = .frying
    default: return nil
    }
    let facing: ClassicSpriteDirection = direction == .left ? .left : .right
    guard let classicAssets,
      let animation = classicAssets.animation(for: pose, direction: facing) ?? classicAssets.animation(for: pose, direction: .none),
      animation.frames.count == (action == .floating ? 4 : count),
      let frame = macArtwork?.lemming(pose: pose, left: direction == .left, tick: tick),
      let provider = CGDataProvider(data: frame.rgba as CFData),
      let cg = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
    return Frame(image: NSImage(cgImage: cg, size: NSSize(width: CGFloat(frame.width) / 2, height: CGFloat(frame.height) / 2)),
      rgba: [UInt8](frame.rgba), width: frame.width, height: frame.height,
      footX: -(animation.offsetX * 2 + frame.x), footY: -(animation.offsetY * 2 + frame.y), cacheKey: "mac-" + key, pixelScale: 2)
  }

  /**
   * Recreates an unmatched NeoLemmix pose at Macintosh pixel scale.
   */
  private func recreatedFrame(rgba: [UInt8], width: Int, height: Int,
    foot: (x: Int, y: Int), direction: NeoLemmixDirection,
    traits: Set<NeoLemmixTrait>, key: String) -> Frame? {
    let doubled: [UInt8]
    if let source = try? SequelMacFrame(width: width, height: height, rgba: rgba),
       let refined = try? SequelMacArtwork.reconstruct(source, category: .sprite) {
      doubled = refined.rgba
    } else {
      doubled = Self.doubledPixels(rgba, width: width, height: height)
    }
    var artwork = doubled
    refineCharacter(rgba, width: width, height: height, direction: direction,
      traits: traits, output: &artwork)
    guard let provider = CGDataProvider(data: Data(artwork) as CFData),
          let image = CGImage(width: width * 2, height: height * 2,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent) else { return nil }
    return Frame(image: NSImage(cgImage: image, size: NSSize(width: width, height: height)),
      rgba: artwork, width: width * 2, height: height * 2,
      footX: foot.x * 2, footY: foot.y * 2, cacheKey: "recreated-" + key,
      pixelScale: 2)
  }

  private static func doubledPixels(_ rgba: [UInt8], width: Int, height: Int) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: width * height * 16)
    for y in 0..<height { for x in 0..<width {
      let source = (y * width + x) * 4
      for dy in 0..<2 { for dx in 0..<2 {
        let target = ((y * 2 + dy) * width * 2 + x * 2 + dx) * 4
        result[target..<target + 4] = rgba[source..<source + 4]
      } }
    } }
    return result
  }

  private func themedColor(_ source: UInt32, traits: Set<NeoLemmixTrait>) -> UInt32 {
    var color = baseRecoloring[source] ?? source
    if !traits.isDisjoint(with: [.slider, .climber, .swimmer, .floater, .glider, .disarmer]) {
      color = athleteRecoloring[color] ?? color
    }
    if traits.contains(.zombie) { color = zombieRecoloring[color] ?? color }
    if traits.contains(.neutral) { color = neutralRecoloring[color] ?? color }
    return color
  }

  private func roleColors(_ names: [String], traits: Set<NeoLemmixTrait>) -> Set<UInt32> {
    var colors: Set<UInt32> = []
    for name in names {
      guard let primary = sourceColors[name] else { continue }
      colors.insert(themedColor(primary, traits: traits))
      for (alternate, base) in sourceShades where base == primary {
        colors.insert(themedColor(alternate, traits: traits))
      }
    }
    return colors
  }

  /**
   * Adds small face, hair and cuff marks without changing the source silhouette.
   */
  private func refineCharacter(_ rgba: [UInt8], width: Int, height: Int,
    direction: NeoLemmixDirection, traits: Set<NeoLemmixTrait>,
    output: inout [UInt8]) {
    func color(at index: Int) -> UInt32? {
      let offset = index * 4
      guard rgba[offset + 3] == 255 else { return nil }
      return Self.color(rgba[offset], rgba[offset + 1], rgba[offset + 2])
    }
    func put(_ color: UInt32, x: Int, y: Int) {
      let index = (y * width * 2 + x) * 4
      guard output[index + 3] == 255 else { return }
      output[index] = UInt8((color >> 16) & 255)
      output[index + 1] = UInt8((color >> 8) & 255)
      output[index + 2] = UInt8(color & 255)
    }
    // The measured rule can propose Classic face colours on pale clothing.
    // Clear these proposals before placing this pose's face and eye.
    for index in 0..<(width * height) where color(at: index) != nil {
      let original = color(at: index)!
      for dy in 0..<2 { for dx in 0..<2 {
        let x = (index % width) * 2 + dx, y = (index / width) * 2 + dy
        let offset = (y * width * 2 + x) * 4
        let current = Self.color(output[offset], output[offset + 1], output[offset + 2])
        if current == 0xFF_AA_22 || current == 0x66_00_11 { put(original, x: x, y: y) }
      } }
    }
    let hair = roleColors(["lemming_hair", "lemming_hat_tip",
      "lemming_athlete_hair", "lemming_athlete_hat_tip"], traits: traits)
    let skin = roleColors(["lemming_skin", "lemming_zombie_skin"], traits: traits)
    guard !hair.isEmpty, !skin.isEmpty else { return }
    let hairPixels = (0..<(width * height)).filter { color(at: $0).map(hair.contains) ?? false }
    for index in hairPixels where index / width == 0
      || color(at: max(0, index - width)).map(hair.contains) != true {
      let shade = Self.lift(color(at: index)!, numerator: 1, denominator: 7)
      put(shade, x: (index % width) * 2, y: (index / width) * 2)
    }
    for index in 0..<(width * height) where color(at: index).map(skin.contains) ?? false {
      let shade = Self.lift(color(at: index)!, numerator: 1, denominator: 5)
      put(shade, x: (index % width) * 2, y: (index / width) * 2)
    }
    guard (2...96).contains(hairPixels.count) else { return }
    let left = hairPixels.map { $0 % width }.min()!
    let right = hairPixels.map { $0 % width }.max()!
    let top = hairPixels.map { $0 / width }.min()!
    let bottom = hairPixels.map { $0 / width }.max()!
    guard right - left <= 15, bottom - top <= 9 else { return }
    let candidates = (0..<(width * height)).filter { index in
      let x = index % width, y = index / width
      return x >= left - 2 && x <= right + 2 && y >= top && y <= bottom + 2
        && (color(at: index).map(skin.contains) ?? false)
    }
    let hairPositions = Set(hairPixels)
    let middle = (left + right) / 2
    let face = candidates.filter { index in
      let x = index % width, y = index / width
      guard direction == .right ? x >= middle : x <= middle else { return false }
      return (-1...1).contains(where: { dy in
        (-1...1).contains(where: { dx in
          let px = x + dx, py = y + dy
          return px >= 0 && px < width && py >= 0 && py < height
            && hairPositions.contains(py * width + px)
        })
      }) || (y > top && candidates.contains(index - width))
    }
    guard (1...24).contains(face.count) else { return }
    let faceTop = face.map { $0 / width }.min()!
    let zombie = traits.contains(.zombie)
    let sourceSkin = face.compactMap(color).first!
    let pale = !zombie && Self.isPaleSkin(sourceSkin)
    let faceColor: UInt32 = pale ? 0xFF_AA_22 : sourceSkin
    let eyeColor: UInt32 = pale ? 0x66_00_11 : Self.shade(sourceSkin, numerator: 1, denominator: 4)
    for index in face {
      let x = index % width, y = index / width
      // Leave a pale forehead under the hair and shade the cheek below it.
      for dy in 0..<2 where y > faceTop || dy == 1 {
        for dx in 0..<2 { put(faceColor, x: x * 2 + dx, y: y * 2 + dy) }
      }
    }
    let firstRow = face.filter { $0 / width == faceTop }
    if let eye = direction == .right ? firstRow.max() : firstRow.min() {
      let x = (eye % width) * 2 + (direction == .right ? 1 : 0)
      put(eyeColor, x: x, y: (eye / width) * 2 + 1)
    }
  }

  private static func isPaleSkin(_ color: UInt32) -> Bool {
    let red = Int((color >> 16) & 255), green = Int((color >> 8) & 255)
    let blue = Int(color & 255)
    return red >= 220 && green >= 175 && blue >= 175 && red >= green
  }

  private static func shade(_ color: UInt32, numerator: Int, denominator: Int) -> UInt32 {
    Self.color(Int((color >> 16) & 255) * numerator / denominator,
      Int((color >> 8) & 255) * numerator / denominator,
      Int(color & 255) * numerator / denominator)
  }

  private static func lift(_ color: UInt32, numerator: Int, denominator: Int) -> UInt32 {
    Self.color(Int((color >> 16) & 255) + (255 - Int((color >> 16) & 255)) * numerator / denominator,
      Int((color >> 8) & 255) + (255 - Int((color >> 8) & 255)) * numerator / denominator,
      Int(color & 255) + (255 - Int(color & 255)) * numerator / denominator)
  }

  /// CE draws this shared 16×11 mask into the terrain when a Stoner finishes.
  func stonerTerrain() -> NSImage? { stonerTerrainImage }

  /// Use the level's sprite frames for both the skill bar and cursor companion.
  @MainActor func skillIcon(named name: String) -> NSImage? {
    if clearSkillImages { skillImages.removeAll(); clearSkillImages = false }
    guard let skill = NeoLemmixSkill(rawValue: name.lowercased()) else { return nil }
    if let image = skillImages[skill] { return image }
    let poses: [(NeoLemmixAction, Int, NeoLemmixDirection, Int, Int)]
    switch skill {
    case .walker: poses = [(.walking, 1, .right, 11, 18)]
    case .jumper: poses = [(.jumping, 0, .right, 11, 16)]
    case .shimmier: poses = [(.shimmying, 1, .right, 11, 15)]
    case .slider: poses = [(.sliding, 0, .left, 9, 17)]
    case .climber: poses = [(.climbing, 3, .right, 14, 18)]
    case .swimmer: poses = [(.swimming, 2, .right, 12, 13)]
    case .floater: poses = [(.floating, 4, .right, 10, 25)]
    case .glider: poses = [(.gliding, 4, .right, 10, 25)]
    case .disarmer: poses = [(.disarming, 6, .right, 9, 16)]
    case .bomber: poses = [(.ohNo, 7, .right, 11, 16)]
    case .stoner: poses = [(.stoneFinish, 0, .right, 12, 18)]
    case .blocker: poses = [(.blocking, 0, .right, 11, 18)]
    case .platformer: poses = [(.platforming, 1, .right, 11, 15)]
    case .builder: poses = [(.building, 1, .right, 11, 16)]
    case .stacker: poses = [(.stacking, 0, .right, 11, 17)]
    case .laserer: poses = [(.lasering, 0, .right, 12, 17)]
    case .basher: poses = [(.bashing, 0, .right, 12, 17)]
    case .fencer: poses = [(.fencing, 1, .right, 11, 17)]
    case .miner: poses = [(.mining, 12, .right, 8, 17)]
    case .digger: poses = [(.digging, 4, .right, 12, 15)]
    case .cloner: poses = [(.walking, 1, .left, 10, 18), (.walking, 1, .right, 13, 18)]
    }
    let canvas = NSImage(size: NSSize(width: 24, height: 24))
    canvas.lockFocusFlipped(true)
    for (action, tick, direction, x, y) in poses {
      guard let frame = frame(action: action, direction: direction, animationFrame: tick, traits: []) else { continue }
      frame.image.draw(in: CGRect(x: CGFloat(x) - CGFloat(frame.footX) / CGFloat(frame.pixelScale), y: CGFloat(y) - CGFloat(frame.footY) / CGFloat(frame.pixelScale), width: frame.image.size.width, height: frame.image.size.height),
        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.none.rawValue])
    }
    let bricks: [(Int, Int)]
    switch skill {
    case .platformer: bricks = stride(from: 6, through: 14, by: 2).map { ($0, 15) }
    case .builder: bricks = [(8, 17), (10, 16), (12, 15), (14, 14)]
    case .stacker: bricks = (12...17).map { (13, $0) }
    default: bricks = []
    }
    NSColor(calibratedRed: CGFloat((skillBrickColor >> 16) & 255) / 255,
      green: CGFloat((skillBrickColor >> 8) & 255) / 255,
      blue: CGFloat(skillBrickColor & 255) / 255, alpha: 1).setFill()
    for (x, y) in bricks { CGRect(x: x, y: y, width: 2, height: 1).fill() }
    canvas.unlockFocus()
    guard let cg = canvas.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: cg)
    var left = cg.width, top = cg.height, right = -1, bottom = -1
    for y in 0..<cg.height { for x in 0..<cg.width {
      if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
        left = min(left, x); right = max(right, x)
        top = min(top, y); bottom = max(bottom, y)
      }
    } }
    guard right >= left, bottom >= top,
      let cropped = cg.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)) else { return nil }
    let image = NSImage(cgImage: cropped, size: NSSize(width: CGFloat(cropped.width) * 24 / CGFloat(cg.width),
      height: CGFloat(cropped.height) * 24 / CGFloat(cg.height)))
    skillImages[skill] = image
    return image
  }

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
    // Bitmap memory is top row first, as drawPixels and the scene compositor expect.
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
    // Bitmap memory is top row first, as drawPixels and the scene compositor expect.
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
