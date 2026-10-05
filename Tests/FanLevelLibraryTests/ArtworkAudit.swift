import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

private struct TerrainArtworkKey: Hashable {
  let family: String
  let style: Int
  let width: Int
  let height: Int
  let pixels: Data
  let palette: Data
}

private struct ObjectArtworkKey: Hashable {
  let width: Int
  let height: Int
  let liquid: Bool
  let rgba: Data
}

private struct SpecialArtworkKey: Hashable {
  let rgba: Data
}

private struct SceneArtworkKey: Hashable {
  let family: String
  let style: Int
  let groundDigest: Data
  let specialStyle: Int
  let specialDigest: Data?
}

private func hasMacObject(_ id: Int, style: Int,
  artwork: ClassicMacArtwork, match: ClassicMacPieceMatch) -> Bool {
  guard match.objects.contains(id), let sequences = artwork.objects[style],
    sequences.indices.contains(id) else { return false }
  let sequence = sequences[id]
  return sequence.count > 0 && (0..<sequence.count).allSatisfy {
    artwork.frame(1600 + style, sequence.base + $0) != nil
  }
}

private func writeArtworkPNG(_ rgba: [UInt8], width: Int, height: Int,
  to url: URL) throws {
  guard rgba.count == width * height * 4,
    let provider = CGDataProvider(data: Data(rgba) as CFData),
    let image = CGImage(width: width, height: height,
      bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw SequelDataError.invalid("The Classic artwork preview cannot be encoded.")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw SequelDataError.invalid("The Classic artwork preview cannot be written.")
  }
}

private func writeFramePreview(_ source: Data, sourceWidth: Int, sourceHeight: Int,
  frame: ClassicMacArtwork.Frame, stem: String, to directory: URL) throws {
  let width = sourceWidth * 2, height = sourceHeight * 2
  var before = [UInt8](repeating: 0, count: width * height * 4)
  for index in 0..<(sourceWidth * sourceHeight) {
    for dy in 0..<2 { for dx in 0..<2 {
      let p = (((index / sourceWidth) * 2 + dy) * width
        + (index % sourceWidth) * 2 + dx) * 4
      for channel in 0..<4 { before[p + channel] = source[index * 4 + channel] }
    } }
  }
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try writeArtworkPNG(before, width: width, height: height,
    to: directory.appendingPathComponent("\(stem)-source-2x.png"))
  try writeArtworkPNG([UInt8](frame.rgba), width: width, height: height,
    to: directory.appendingPathComponent("\(stem)-recreated.png"))
  let gap = 8, combinedWidth = width * 2 + gap
  var combined = [UInt8](repeating: 0, count: combinedWidth * height * 4)
  for y in 0..<height { for x in 0..<width {
    let source = (y * width + x) * 4
    let left = (y * combinedWidth + x) * 4
    let right = (y * combinedWidth + width + gap + x) * 4
    for channel in 0..<4 {
      combined[left + channel] = before[source + channel]
      combined[right + channel] = frame.rgba[source + channel]
    }
  } }
  try writeArtworkPNG(combined, width: combinedWidth, height: height,
    to: directory.appendingPathComponent("\(stem)-before-after.png"))
}

private func writeTerrainPreview(_ graphic: ClassicTerrainGraphic,
  palette: [ClassicRGBColor], frame: ClassicMacArtwork.Frame,
  to directory: URL) throws {
  var source = [UInt8](repeating: 0, count: graphic.width * graphic.height * 4)
  for (index, value) in graphic.indexedPixels.enumerated() where value & 0x80 == 0 {
    let colour = palette[Int(value & 15)]
    source[index * 4] = colour.red; source[index * 4 + 1] = colour.green
    source[index * 4 + 2] = colour.blue; source[index * 4 + 3] = 255
  }
  try writeFramePreview(Data(source), sourceWidth: graphic.width,
    sourceHeight: graphic.height, frame: frame, stem: "fan-terrain", to: directory)
}

private func artworkPaletteKey(_ colours: [ClassicRGBColor]) -> Data {
  Data(colours.flatMap { [$0.red, $0.green, $0.blue] })
}

private func verifyArtworkFrame(_ frame: ClassicMacArtwork.Frame, width: Int,
  height: Int, opaque: (Int) -> Bool) throws -> Int {
  guard frame.width == width * 2, frame.height == height * 2,
    frame.rgba.count == width * height * 16 else {
    throw SequelDataError.invalid("A reconstructed fan graphic changed size.")
  }
  var detailed = 0
  for index in 0..<(width * height) {
    let sourceOpaque = opaque(index)
    var first: UInt32?
    var split = false
    for dy in 0..<2 { for dx in 0..<2 {
      let p = (((index / width) * 2 + dy) * width * 2 + (index % width) * 2 + dx) * 4
      guard (frame.rgba[p + 3] != 0) == sourceOpaque else {
        throw SequelDataError.invalid("A reconstructed fan graphic changed its source mask.")
      }
      guard sourceOpaque else { continue }
      let colour = UInt32(frame.rgba[p]) << 24 | UInt32(frame.rgba[p + 1]) << 16
        | UInt32(frame.rgba[p + 2]) << 8 | UInt32(frame.rgba[p + 3])
      if let first, first != colour { split = true }
      if first == nil { first = colour }
    } }
    if split { detailed += 1 }
  }
  return detailed
}

/**
 * Reconstructs every distinct changed Classic fan asset without running gameplay ticks.
 */
func runArtworkAudit(root: URL) throws {
  let bundledPorts = root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources/Ports")
  let ports = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FAN_TEST_PORTS_DIR"]
    ?? bundledPorts.path)
  let packs = FanLevelLibrary.packs(in: [root.appendingPathComponent("Content/LevelPacks")])
  guard !packs.isEmpty else { throw SequelDataError.invalid("No bundled Classic fan packs for the artwork audit.") }
  let counts = try JSONDecoder().decode([String: Int].self,
    from: Data(contentsOf: root.appendingPathComponent("Content/LevelPacks/level-counts.json")))
  guard packs.count == counts.count else {
    throw SequelDataError.invalid("The artwork audit found a different number of fan packs than the catalogue.")
  }
  let stockFolders = ["holiday_native_1994", "lemmings_dos_1991-07-30",
    "oh_no_more_lemmings_dos-1991-11-14_2232", "xmas_dos_XmasLemmingsV1.9",
    "xmas_dos_XmasLemmingsV1.9a1"]
  var stocksByStyle: [Int: [String: ClassicGroundSet]] = [:]
  for style in 0..<5 {
    var stocks: [String: ClassicGroundSet] = [:]
    for folder in stockFolders {
      stocks[folder] = try? ClassicGroundSet.load(style: style,
        from: ports.appendingPathComponent(folder))
    }
    stocksByStyle[style] = stocks
  }
  let artworkRoot = root.appendingPathComponent(".build/mac-artwork/export")
  var artworks: [String: ClassicMacArtwork] = [:]
  for family in ["lemmings", "ohno", "xmas", "holiday"] {
    artworks[family] = try ClassicMacArtwork(directory: artworkRoot.appendingPathComponent(family))
  }
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  var terrainSeen = Set<TerrainArtworkKey>()
  var objectSeen = Set<ObjectArtworkKey>()
  var specialSeen = Set<SpecialArtworkKey>()
  var sceneSeen = Set<SceneArtworkKey>()
  var levelCount = 0, terrainCount = 0, objectCount = 0, specialCount = 0
  var sceneCount = 0, previewWritten = false
  var previewedObjectEffects = Set<Int>()
  var terrainDetail = 0, objectDetail = 0, specialDetail = 0
  for (packIndex, pack) in packs.enumerated() {
    for entry in FanLevelLibrary.entries(in: pack) {
      let (level, styleName) = try FanLevelLibrary.level(entry, in: pack)
      let ground = try FanLevelLibrary.groundSet(for: level, styleName: styleName,
        portsRoot: ports, pack: pack, entry: entry)
      let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry,
        pack: pack, portsRoot: ports)
      guard let match = FanLevelLibrary.artworkMatch(for: level, ground: ground,
        special: special, portsRoot: ports,
        stockGrounds: stocksByStyle[ground.style] ?? [:]) else {
        throw SequelDataError.invalid("No Macintosh reconstruction route for \(pack.lastPathComponent): \(entry.label).")
      }
      levelCount += 1
      guard let artwork = artworks[match.family] else {
        throw SequelDataError.invalid("A fan level selected an unavailable Macintosh artwork family.")
      }
      let groundDigest = Data(SHA256.hash(data: try encoder.encode(ground)))
      let specialDigest = try special.map { Data(SHA256.hash(data: try encoder.encode($0))) }
      let sceneKey = SceneArtworkKey(family: match.family, style: ground.style,
        groundDigest: groundDigest,
        specialStyle: level.specialStyle,
        specialDigest: specialDigest)
      var renderedForLevel: ClassicRenderedLevel?
      if sceneSeen.insert(sceneKey).inserted {
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
          specialGraphic: special,
          objectSemantics: .forFanLevel(level, groundSet: ground))
        renderedForLevel = rendered
        let scene: ClassicMacScene
        do {
          scene = try ClassicMacScene(level: level, rendered: rendered,
            artwork: artwork, groundSet: ground, match: match.pieces)
        } catch {
          throw SequelDataError.invalid("\(pack.lastPathComponent) / \(entry.label): \(error)")
        }
        guard scene.width == rendered.width * 2,
          scene.height == rendered.height * 2 else {
          throw SequelDataError.invalid("A fan artwork scene changed its source canvas size.")
        }
        sceneCount += 1
      }
      if level.specialStyle > 0,
        (!match.pieces.special || artwork.frame(1699 + level.specialStyle) == nil),
        let special {
        let key = SpecialArtworkKey(rgba: special.rgba)
        if specialSeen.insert(key).inserted {
          let frame = try ClassicMacScene.reconstructed(special.rgba,
            width: special.width, height: special.height, category: .architectural)
          specialDetail += try verifyArtworkFrame(frame, width: special.width,
            height: special.height, opaque: { special.rgba[$0 * 4 + 3] != 0 })
          specialCount += 1
        }
      }
      for placement in level.terrain where level.specialStyle == 0
        && (!match.pieces.terrain.contains(placement.id)
          || artwork.frame(1500 + ground.style, placement.id) == nil) {
        guard let graphic = ground.terrain[placement.id] else {
          throw SequelDataError.invalid("A fan level refers to missing terrain artwork.")
        }
        let key = TerrainArtworkKey(family: match.family, style: ground.style,
          width: graphic.width, height: graphic.height, pixels: graphic.indexedPixels,
          palette: artworkPaletteKey(ground.objectPalette))
        guard terrainSeen.insert(key).inserted else { continue }
        let frame = try ClassicMacScene.reconstructedTerrain(graphic,
          palette: ground.objectPalette, family: match.family, style: ground.style)
        let detailed = try verifyArtworkFrame(frame, width: graphic.width,
          height: graphic.height, opaque: { graphic.indexedPixels[$0] & 0x80 == 0 })
        terrainDetail += detailed
        terrainCount += 1
        if !previewWritten, detailed > 10 {
          let output = root.appendingPathComponent(".build/classic-mac-artwork-audit/previews")
          try writeTerrainPreview(graphic, palette: ground.objectPalette,
            frame: frame, to: output)
          let caption = "\(pack.lastPathComponent) | \(entry.label) | \(match.family) style \(ground.style) | terrain \(graphic.id) | \(detailed) detailed source cells\n"
          try Data(caption.utf8).write(to: output.appendingPathComponent("fan-terrain-before-after.txt"))
          previewWritten = true
        }
      }
      let changedObjects = Set(level.objects.map(\.id)).filter {
        !hasMacObject($0, style: ground.style, artwork: artwork, match: match.pieces)
      }
      guard !changedObjects.isEmpty else { continue }
      let rendered = try renderedForLevel ?? ClassicLevelRenderer.render(level,
        groundSet: ground, specialGraphic: special,
        objectSemantics: .forFanLevel(level, groundSet: ground))
      for object in rendered.objects where changedObjects.contains(object.placement.id) {
        for (frameIndex, rgba) in object.rgbaFrames.enumerated() {
          let key = ObjectArtworkKey(width: object.graphic.width,
            height: object.graphic.height,
            liquid: object.graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue,
            rgba: rgba)
          guard objectSeen.insert(key).inserted else { continue }
          let frame = try ClassicMacScene.reconstructedObject(rgba, graphic: object.graphic)
          let detailed = try verifyArtworkFrame(frame, width: object.graphic.width,
            height: object.graphic.height, opaque: { rgba[$0 * 4 + 3] != 0 })
          objectDetail += detailed
          objectCount += 1
          let effect = object.graphic.triggerEffect
          if [0, ClassicDOSObjectEffect.water.rawValue,
            ClassicDOSObjectEffect.fire.rawValue].contains(effect),
            !previewedObjectEffects.contains(effect), detailed > 0 {
            let output = root.appendingPathComponent(".build/classic-mac-artwork-audit/previews")
            let stem = "fan-object-effect-\(effect)"
            try writeFramePreview(rgba, sourceWidth: object.graphic.width,
              sourceHeight: object.graphic.height, frame: frame,
              stem: stem, to: output)
            let caption = "\(pack.lastPathComponent) | \(entry.label) | object \(object.placement.id) frame \(frameIndex) | effect \(effect) | \(detailed) detailed source cells\n"
            try Data(caption.utf8).write(to: output.appendingPathComponent("\(stem)-before-after.txt"))
            previewedObjectEffects.insert(effect)
          }
        }
      }
    }
    if (packIndex + 1) % 50 == 0 {
      FileHandle.standardError.write(Data(
        "Macintosh fan artwork audit: \(packIndex + 1)/\(packs.count) packs\n".utf8))
    }
  }
  guard terrainCount > 0, objectCount > 0, terrainDetail > 0,
    objectDetail > 0, sceneCount > 0, previewWritten else {
    throw SequelDataError.invalid("The fan artwork audit did not find detailed terrain and object reconstructions.")
  }
  guard levelCount == counts.values.reduce(0, +) else {
    throw SequelDataError.invalid("The artwork audit missed a bundled fan level.")
  }
  print("PASS Macintosh fan artwork audit: \(levelCount) levels, \(sceneCount) distinct scenes, \(terrainCount) terrain pieces, \(objectCount) object frames, \(specialCount) special pictures")
  print("PASS 2× mask and detail: \(terrainDetail) terrain cells, \(objectDetail) object cells, \(specialDetail) special-picture cells")
}
