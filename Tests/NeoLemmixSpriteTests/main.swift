import AppKit
import Foundation
import NxlvKit

struct Failure: Error, CustomStringConvertible { let description: String }
func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw Failure(description: message) }
}

let names = [
  "walker", "ascender", "faller", "climber", "hoister", "floater", "glider",
  "dehoister", "slider", "swimmer", "blocker", "builder", "platformer", "stacker",
  "basher", "fencer", "laserer", "miner", "digger", "jumper", "reacher", "shimmier",
  "disarmer", "shrugger", "ohnoer", "stoner", "bomber", "splatter", "exiter",
  "drowner", "burner",
]

func png(width: Int, height: Int, frames: Int) throws -> Data {
  var bytes = [UInt8](repeating: 0, count: width * height * 4)
  let half = width / 2
  for y in 0..<height {
    let frame = y / (height / frames)
    for x in 0..<width {
      let offset = (y * width + x) * 4
      let color: (UInt8, UInt8, UInt8)
      // NeoLemmix stores left-facing frames first and right-facing frames
      // second, despite listing RIGHT before LEFT in scheme.nxmi.
      if x >= half {
        if frame == 1 {
          color = (0xF0, 0xD0, 0xD0)
        } else if y.isMultiple(of: height / frames) {
          color = (0x30, 0x30, 0xA0)
        } else {
          color = (0x40, 0x40, 0xE0)
        }
      } else {
        color = (0x00, 0xB0, 0x00)
      }
      bytes[offset] = color.0
      bytes[offset + 1] = color.1
      bytes[offset + 2] = color.2
      bytes[offset + 3] = 0xFF
    }
  }
  guard let provider = CGDataProvider(data: Data(bytes) as CFData),
        let image = CGImage(
          width: width,
          height: height,
          bitsPerComponent: 8,
          bitsPerPixel: 32,
          bytesPerRow: width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
          provider: provider,
          decode: nil,
          shouldInterpolate: false,
          intent: .defaultIntent
        ),
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    throw Failure(description: "Could not make a PNG fixture")
  }
  return data
}

func color(_ image: NSImage, x: Int, y: Int) throws -> (Int, Int, Int) {
  guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    throw Failure(description: "Could not inspect sprite frame")
  }
  var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
  guard let context = CGContext(
    data: &bytes,
    width: cg.width,
    height: cg.height,
    bitsPerComponent: 8,
    bytesPerRow: cg.width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { throw Failure(description: "Could not inspect sprite pixels") }
  context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
  let offset = (y * cg.width + x) * 4
  return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
}

func syntheticStyles() throws -> URL {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("NeoLemmixSpriteTests-\(UUID().uuidString)")
  let theme = root.appendingPathComponent("fixture")
  let lemmings = root.appendingPathComponent("fixture_sprites/lemmings")
  try FileManager.default.createDirectory(at: theme, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: lemmings, withIntermediateDirectories: true)
  try """
  LEMMINGS fixture_sprites
  $COLORS
    LEMMING_CLOTHES xEF2020
    LEMMING_NEUTRAL_CLOTHES xCCCCCC
  $END
  """.write(to: theme.appendingPathComponent("theme.nxtm"), atomically: true, encoding: .utf8)

  var animations = "$ANIMATIONS\n"
  for name in names {
    let frames = name == "walker" ? 2 : (name == "jumper" || name == "slider" ? 3 : 1)
    animations += """
      $\(name.uppercased())
        FRAMES \(frames)
        \(name == "slider" ? "LOOP_TO_FRAME 1" : "")
        $RIGHT
          FOOT_X 1
          FOOT_Y \(name == "ohnoer" ? 2 : 3)
        $END
        $LEFT
          FOOT_X 2
          FOOT_Y \(name == "ohnoer" ? 2 : 3)
        $END
      $END
    """ + "\n"
    try png(width: 8, height: frames * 4, frames: frames)
      .write(to: lemmings.appendingPathComponent("\(name).png"))
  }
  animations += "$END\n"
  let scheme = """
  $SPRITESET_RECOLORING
    LEMMING_HAIR x00B000
    LEMMING_CLOTHES x4040E0
    LEMMING_SKIN xF0D0D0
    LEMMING_ZOMBIE_SKIN x808080
    LEMMING_ATHLETE_HAIR x4040DF
    LEMMING_NEUTRAL_CLOTHES x888888
  $END
  $STATE_RECOLORING
    $ATHLETE
      FROM x00B000
      TO x4040DF
    $END
    $ZOMBIE
      FROM xF0D0D0
      TO x808080
    $END
    $NEUTRAL
      FROM x4040E0
      TO x888888
    $END
  $END
  $SHADES
    $SHADE
      PRIMARY x4040E0
      ALT x3030A0
    $END
  $END
  \(animations)
  """
  try scheme.write(to: lemmings.appendingPathComponent("scheme.nxmi"), atomically: true, encoding: .utf8)
  return root
}

func writeContactSheet(styles: URL, theme: String, output: URL, mac: Bool = false) throws {
  let sprites = try NeoLemmixSpriteSet(stylesRootURL: styles, themeStyle: theme)
  sprites.usesMacArtwork = mac
  let actions = NeoLemmixAction.allCases.filter { ![.teleporting, .removed].contains($0) }
  let scale = 2, cellWidth = 96, cellHeight = 72, columns = 8
  let rows = (actions.count + columns - 1) / columns
  let image = NSImage(size: NSSize(width: columns * cellWidth, height: rows * cellHeight))
  image.lockFocus()
  NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
  NSRect(origin: .zero, size: image.size).fill()
  NSGraphicsContext.current?.imageInterpolation = .none
  for (index, action) in actions.enumerated() {
    guard let frame = sprites.frame(action: action, direction: index.isMultiple(of: 2) ? .right : .left,
                                    animationFrame: index % 12, traits: []) else { continue }
    try require(frame.width > 0 && frame.height > 0
      && frame.rgba.count == frame.width * frame.height * 4,
      "Sprite frame did not expose deterministic RGBA capture pixels")
    let column = index % columns, row = rows - 1 - index / columns
    let rect = NSRect(
      x: column * cellWidth + (cellWidth - Int(frame.image.size.width) * scale) / 2,
      y: row * cellHeight + 20,
      width: Int(frame.image.size.width) * scale,
      height: Int(frame.image.size.height) * scale
    )
    frame.image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    let label = action.rawValue as NSString
    label.draw(at: NSPoint(x: column * cellWidth + 4, y: row * cellHeight + 5), withAttributes: [
      .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
      .foregroundColor: NSColor.white,
    ])
  }
  image.unlockFocus()
  guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
    throw Failure(description: "Could not encode contact sheet")
  }
  try data.write(to: output)
}

func verifyCorpus(levels: URL, styles: URL) throws {
  guard let enumerator = FileManager.default.enumerator(
    at: levels,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles, .skipsPackageDescendants]
  ) else { throw Failure(description: "Could not enumerate the level corpus") }
  let urls = enumerator.compactMap { item -> URL? in
    guard let url = item as? URL,
          url.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame,
          (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
    return url
  }
  var themes: Set<String> = []
  for url in urls {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
          let level = NxlvLevel(text: text) else {
      throw Failure(description: "Could not decode \(url.path)")
    }
    themes.insert(level.themeStyle.isEmpty ? "default" : level.themeStyle)
  }
  var frames = 0
  var pickupFrames = 0
  for theme in themes.sorted() {
    let sprites = try NeoLemmixSpriteSet(stylesRootURL: styles, themeStyle: theme)
    guard let stoner = sprites.stonerTerrain(),
          stoner.size == NSSize(width: 16, height: 11),
          let stonerPixels = sprites.stonerTerrainPixels(),
          stonerPixels.width == 16,
          stonerPixels.height == 11,
          stonerPixels.rgba.count == 16 * 11 * 4 else {
      throw Failure(description: "\(theme) did not resolve the canonical 16x11 Stoner terrain mask")
    }
    for action in NeoLemmixAction.allCases where ![.teleporting, .removed].contains(action) {
      for direction in [NeoLemmixDirection.left, .right] {
        for traits: Set<NeoLemmixTrait> in [[], [.climber], [.zombie], [.neutral]] {
          guard sprites.frame(
            action: action,
            direction: direction,
            animationFrame: 11,
            traits: traits
          ).map({ $0.width > 0 && $0.height > 0
            && $0.rgba.count == $0.width * $0.height * 4 }) == true else {
            throw Failure(description: "\(theme) has no \(direction.rawValue) \(action.rawValue) frame")
          }
          frames += 1
        }
      }
    }
    let gadgets = NxlvSkill.allCases.enumerated().map { index, skill in
      """
      $GADGET
        STYLE default
        PIECE pickup
        X \(index * 24 + 6)
        Y 6
        SKILL \(skill.keyword)
        SKILL_COUNT 1
      $END
      """
    }.joined(separator: "\n")
    guard let pickupLevel = NxlvLevel(text: """
      TITLE Generated pickup corpus
      THEME \(theme)
      WIDTH \(NxlvSkill.allCases.count * 24 + 12)
      HEIGHT 36
      LEMMINGS 0
      SAVE_REQUIREMENT 0
      \(gadgets)
      """) else {
      throw Failure(description: "\(theme) pickup fixture did not parse")
    }
    let resolution = NxlvStyleResolver(stylesRootURL: styles).resolve(level: pickupLevel)
    let result = NxlvRenderer(retainsVisualLayers: true).render(
      level: pickupLevel, resolution: resolution
    )
    guard !result.hasErrors, let rendered = result.renderedLevel,
          rendered.gadgets.count == NxlvSkill.allCases.count else {
      throw Failure(description: "\(theme) did not render every generated pickup")
    }
    for (index, gadget) in rendered.gadgets.enumerated() {
      guard gadget.animationRGBA.count == NxlvSkill.allCases.count * 2,
            gadget.initialAnimationFrame == index * 2 + 1,
            gadget.animationRGBA[gadget.initialAnimationFrame]
              .enumerated().contains(where: {
                $0.offset % 4 == 3 && $0.element != 0
              }) else {
        throw Failure(description: "\(theme) generated pickup \(index) has invalid CE frames")
      }
      pickupFrames += gadget.animationRGBA.count
    }
  }
  print("PASS NeoLemmix sprite corpus: \(urls.count) levels, \(themes.count) themes, \(frames) state/direction/action frames, \(pickupFrames) generated pickup frames")
}

do {
  if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--corpus" {
    try verifyCorpus(
      levels: URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true),
      styles: URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
    )
    exit(0)
  }
  if CommandLine.arguments.count == 4 {
    try writeContactSheet(
      styles: URL(fileURLWithPath: CommandLine.arguments[1]),
      theme: CommandLine.arguments[2],
      output: URL(fileURLWithPath: CommandLine.arguments[3])
    )
    print("PASS NeoLemmix sprite contact sheet")
    exit(0)
  }
  if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--mac-contact-sheet" {
    try writeContactSheet(
      styles: URL(fileURLWithPath: CommandLine.arguments[2]),
      theme: CommandLine.arguments[3],
      output: URL(fileURLWithPath: CommandLine.arguments[4]), mac: true
    )
    print("PASS NeoLemmix Macintosh sprite contact sheet")
    exit(0)
  }

  let root = try syntheticStyles()
  defer { try? FileManager.default.removeItem(at: root) }
  let sprites = try NeoLemmixSpriteSet(stylesRootURL: root, themeStyle: "fixture")
  let right = try requireValue(
    sprites.frame(action: .walking, direction: .right, animationFrame: 0, traits: []),
    "Right Walker frame was missing"
  )
  try require(right.image.size == NSSize(width: 4, height: 4), "Walker frame dimensions were wrong")
  try require(right.footX == 1 && right.footY == 3, "Right Walker foot anchor was wrong")
  try require(try color(right.image, x: 0, y: 1) == (0xEF, 0x20, 0x20), "Theme recoloring was not applied")
  let themedShade = try color(right.image, x: 0, y: 0)
  try require(themedShade != (0x30, 0x30, 0xA0) && themedShade != (0xEF, 0x20, 0x20),
              "Theme shade shift was not preserved")
  let left = try requireValue(
    sprites.frame(action: .walking, direction: .left, animationFrame: 0, traits: [.climber]),
    "Left athlete Walker frame was missing"
  )
  try require(left.footX == 2 && left.footY == 3, "Left Walker foot anchor was wrong")
  try require(try color(left.image, x: 0, y: 0) == (0x40, 0x40, 0xDF), "Athlete recoloring was not applied")
  for trait: NeoLemmixTrait in [.slider, .climber, .swimmer, .floater, .glider, .disarmer] {
    let permanent = try requireValue(
      sprites.frame(action: .walking, direction: .left, animationFrame: 0, traits: [trait]),
      "Permanent-skill Walker frame was missing"
    )
    try require(
      try color(permanent.image, x: 0, y: 0) == (0x40, 0x40, 0xDF),
      "Permanent skill \(trait.rawValue) did not use CE athlete recoloring"
    )
  }
  let neutral = try requireValue(
    sprites.frame(action: .walking, direction: .right, animationFrame: 0, traits: [.neutral]),
    "Neutral Walker frame was missing"
  )
  try require(try color(neutral.image, x: 0, y: 1) == (0xCC, 0xCC, 0xCC), "Neutral theme recoloring was not applied")
  try require(try color(neutral.image, x: 0, y: 0) != (0xCC, 0xCC, 0xCC),
              "Neutral shade shift was not preserved")
  let jumper0 = try requireValue(
    sprites.frame(action: .jumping, direction: .right, animationFrame: 5, traits: []),
    "Jumper ascent frame was missing"
  )
  let jumper1 = try requireValue(
    sprites.frame(action: .jumping, direction: .right, animationFrame: 6, traits: []),
    "Jumper peak frame was missing"
  )
  let jumper2 = try requireValue(
    sprites.frame(action: .jumping, direction: .right, animationFrame: 7, traits: []),
    "Jumper descent frame was missing"
  )
  try require(try color(jumper0.image, x: 0, y: 1) == (0xEF, 0x20, 0x20), "Jumper progress 5 did not use frame 0")
  try require(try color(jumper1.image, x: 0, y: 1) == (0xF0, 0xD0, 0xD0), "Jumper progress 6 did not use frame 1")
  try require(try color(jumper2.image, x: 0, y: 1) == (0xEF, 0x20, 0x20), "Jumper progress 7 did not use frame 2")
  let stoning = try requireValue(
    sprites.frame(action: .stoning, direction: .right, animationFrame: 0, traits: []),
    "Stoning frame was missing"
  )
  let stoneFinish = try requireValue(
    sprites.frame(action: .stoneFinish, direction: .right, animationFrame: 0, traits: []),
    "Stone-finish frame was missing"
  )
  try require(stoning.footY == 2 && stoning.cacheKey.hasPrefix("ohnoer-"),
              "Stoning did not use CE's Oh-No animation and anchor")
  try require(stoneFinish.footY == 3 && stoneFinish.cacheKey.hasPrefix("stoner-"),
              "Stone finish did not use CE's one-frame Stoner burst")
  for action in NeoLemmixAction.allCases where ![.teleporting, .removed].contains(action) {
    try require(sprites.frame(action: action, direction: .right, animationFrame: 7, traits: []) != nil,
                "\(action.rawValue) did not resolve to native artwork")
  }
  // Recoloring keeps alpha, so a frame's opacity must match its sheet crop row for row.
  // A vertical flip here drew every lemming upside down in 1.7.0.
  let realStyles = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../Content/NeoLemmix/styles").standardizedFileURL
  if FileManager.default.fileExists(atPath: realStyles.appendingPathComponent("default/lemmings/walker.png").path) {
    let real = try NeoLemmixSpriteSet(stylesRootURL: realStyles, themeStyle: "orig_dirt")
    let walker = try requireValue(real.frame(action: .walking, direction: .right, animationFrame: 0, traits: []),
                                  "Real walker frame did not resolve")
    let sheet = try requireValue(NSImage(contentsOf: realStyles.appendingPathComponent("default/lemmings/walker.png"))?
      .cgImage(forProposedRect: nil, context: nil, hints: nil), "Real walker sheet did not load")
    func alphaRows(_ image: CGImage) -> [[UInt8]] {
      var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
      let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return (0..<image.height).map { y in (0..<image.width).map { bytes[(y * image.width + $0) * 4 + 3] } }
    }
    let frameImage = try requireValue(walker.image.cgImage(forProposedRect: nil, context: nil, hints: nil), "No frame pixels")
    let rightColumn = sheet.width / 2
    let source = try requireValue(sheet.cropping(to: CGRect(x: rightColumn, y: 0, width: walker.width, height: walker.height)),
                                  "Walker crop failed")
    try require(alphaRows(frameImage) == alphaRows(source), "Real walker frame is not upright")
    let rgbaAlpha = (0..<walker.height).map { y in (0..<walker.width).map { walker.rgba[(y * walker.width + $0) * 4 + 3] } }
    try require(rgbaAlpha == alphaRows(source), "Real walker RGBA rows are not upright")

    let swimmer = try requireValue(real.frame(action: .swimming, direction: .right,
      animationFrame: 0, traits: []), "Real swimmer frame did not resolve")
    real.usesMacArtwork = true
    let recreated = try requireValue(real.frame(action: .swimming, direction: .right,
      animationFrame: 0, traits: []), "Recreated swimmer frame did not resolve")
    try require(recreated.pixelScale == 2 && recreated.width == swimmer.width * 2
      && recreated.height == swimmer.height * 2 && recreated.image.size == swimmer.image.size,
      "Recreated sprite did not retain its logical bounds at Macintosh scale")
    try require(recreated.footX == swimmer.footX * 2 && recreated.footY == swimmer.footY * 2,
      "Recreated sprite changed its foot anchor")
    var detailedCells = 0
    for y in 0..<swimmer.height { for x in 0..<swimmer.width {
      let alpha = swimmer.rgba[(y * swimmer.width + x) * 4 + 3]
      var colours: Set<[UInt8]> = []
      for dy in 0..<2 { for dx in 0..<2 {
        let pixel = ((y * 2 + dy) * recreated.width + x * 2 + dx) * 4
        try require(recreated.rgba[pixel + 3] == alpha,
          "Recreated sprite changed the source silhouette")
        if alpha == 255 { colours.insert(Array(recreated.rgba[pixel..<pixel + 3])) }
      } }
      if colours.count > 1 { detailedCells += 1 }
    } }
    try require(detailedCells > 0,
      "Recreated sprite contained only repeated source pixels")
    try require(recreated.rgba == real.frame(action: .swimming, direction: .right,
        animationFrame: 0, traits: [])?.rgba,
      "Recreated sprite did not have stable 2× details")
    let neutralRecreated = try requireValue(real.frame(action: .walking, direction: .right,
      animationFrame: 0, traits: [.neutral]), "Neutral 2× Walker did not resolve")
    try require(neutralRecreated.pixelScale == 2 && neutralRecreated.rgba.contains(0x88),
      "Neutral sprite lost its grey clothing")
    let zombieRecreated = try requireValue(real.frame(action: .walking, direction: .right,
      animationFrame: 0, traits: [.zombie]), "Zombie 2× Walker did not resolve")
    try require(zombieRecreated.pixelScale == 2 && zombieRecreated.rgba.contains(0x80),
      "Zombie sprite lost its grey skin")
    let themed = try NeoLemmixSpriteSet(stylesRootURL: realStyles, themeStyle: "l2_beach")
    themed.usesMacArtwork = true
    let beach = try requireValue(themed.frame(action: .swimming, direction: .right,
      animationFrame: 0, traits: []), "Beach sprite did not resolve")
    func containsColor(_ pixels: [UInt8], _ color: [UInt8]) -> Bool {
      stride(from: 0, to: pixels.count, by: 4).contains { offset in
        pixels[offset..<offset + 3].elementsEqual(color)
      }
    }
    try require(beach.pixelScale == 2 && containsColor(beach.rgba, [0xCA, 0x72, 0x00])
      && !containsColor(beach.rgba, [0xFF, 0xAA, 0x22]),
      "Themed sprite lost its authored skin colour")
  }
  print("PASS NeoLemmix sprite resolution, geometry, state recolouring, action coverage, and Macintosh-scale recreation")
} catch {
  fputs("FAIL: \(error)\n", stderr)
  exit(1)
}

func requireValue<T>(_ value: T?, _ message: String) throws -> T {
  guard let value else { throw Failure(description: message) }
  return value
}
