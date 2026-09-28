import AppKit
import CryptoKit
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

private struct Failure: Error, CustomStringConvertible {
  let description: String
}

private struct CaptureManifest: Encodable {
  struct Frame: Encodable {
    let tick: Int
    let file: String
    let rgbaSHA256: String
    let saved: Int
    let lost: Int
    let activeLemmings: Int
  }

  let format = "neolemmix-replay-capture-v1"
  let producer = "native"
  let replaySHA256: String
  let levelID: String
  let levelVersion: String
  let width: Int
  let height: Int
  let frames: [Frame]
}

private func text(at url: URL) throws -> String {
  let data = try Data(contentsOf: url, options: .mappedIfSafe)
  guard let text = String(data: data, encoding: .utf8)
          ?? String(data: data, encoding: .isoLatin1) else {
    throw Failure(description: "Could not decode \(url.path).")
  }
  return text
}

private func digest(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func sourceOver(
  _ source: [UInt8], width: Int, height: Int, x: Int, y: Int,
  canvasWidth: Int, canvasHeight: Int, canvas: inout [UInt8]
) {
  guard source.count == width * height * 4,
        canvas.count == canvasWidth * canvasHeight * 4 else { return }
  for sourceY in 0..<height {
    let destinationY = y + sourceY
    guard (0..<canvasHeight).contains(destinationY) else { continue }
    for sourceX in 0..<width {
      let destinationX = x + sourceX
      guard (0..<canvasWidth).contains(destinationX) else { continue }
      let sourceOffset = (sourceY * width + sourceX) * 4
      let alpha = Int(source[sourceOffset + 3])
      guard alpha > 0 else { continue }
      let destinationOffset = (destinationY * canvasWidth + destinationX) * 4
      if alpha == 255 {
        canvas[destinationOffset] = source[sourceOffset]
        canvas[destinationOffset + 1] = source[sourceOffset + 1]
        canvas[destinationOffset + 2] = source[sourceOffset + 2]
        canvas[destinationOffset + 3] = 255
        continue
      }
      let destinationAlpha = Int(canvas[destinationOffset + 3])
      let inverse = 255 - alpha
      let outputAlpha = alpha + (destinationAlpha * inverse + 127) / 255
      for channel in 0..<3 {
        let sourcePremultiplied = Int(source[sourceOffset + channel]) * alpha
        let destinationPremultiplied = Int(canvas[destinationOffset + channel])
          * destinationAlpha * inverse / 255
        canvas[destinationOffset + channel] = UInt8(min(
          255,
          (sourcePremultiplied + destinationPremultiplied + outputAlpha / 2)
            / max(1, outputAlpha)))
      }
      canvas[destinationOffset + 3] = UInt8(outputAlpha)
    }
  }
}

private func writePNG(_ rgba: [UInt8], width: Int, height: Int, to url: URL) throws {
  guard rgba.count == width * height * 4,
        let provider = CGDataProvider(data: Data(rgba) as CFData),
        let image = CGImage(
          width: width,
          height: height,
          bitsPerComponent: 8,
          bitsPerPixel: 32,
          bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
            .union(.byteOrder32Big),
          provider: provider,
          decode: nil,
          shouldInterpolate: false,
          intent: .defaultIntent),
        let destination = CGImageDestinationCreateWithURL(
          url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw Failure(description: "Could not create \(url.path).")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw Failure(description: "Could not write \(url.path).")
  }
}

private func frame(
  rendered: NxlvRenderedLevel,
  simulation: NeoLemmixSimulation,
  sprites: NeoLemmixSpriteSet
) -> [UInt8] {
  let stoner = sprites.stonerTerrainPixels()
  var rgba = NeoLemmixSceneFrame.rgba(
    rendered,
    terrain: simulation.terrain,
    stonerRGBA: stoner?.rgba ?? [],
    stonerWidth: stoner?.width ?? 16,
    stonerHeight: stoner?.height ?? 11,
    zones: simulation.configuration.zones,
    disabledZoneIDs: simulation.disabledZoneIDs,
    gadgetAnimationFrames: simulation.gadgetAnimationFrames,
    secondaryAnimationStates: simulation.secondaryAnimationStates,
    tickCount: simulation.tickCount,
    entranceOpenTick: simulation.configuration.entranceOpenTick,
    splitterDirections: simulation.splitterDirections)
  // CE sorts its complete list, including removed and teleporting lemmings,
  // then rejects invisible entries during DrawThisLemming. Invisible entries
  // still affect the unstable equal-priority quicksort permutation.
  for lemming in NeoLemmixRenderOrder.sorted(simulation.lemmings) {
    guard lemming.isActive && lemming.action != .teleporting else { continue }
    if lemming.action == .exploding && lemming.animationFrame >= 4 { continue }
    guard let sprite = sprites.frame(
      action: lemming.action,
      direction: lemming.direction,
      animationFrame: lemming.animationFrame,
      traits: lemming.traits) else { continue }
    if let value = ProcessInfo.processInfo.environment["NXLV_CAPTURE_TRACE_PIXEL"] {
      let parts = value.split(separator: ",").compactMap { Int($0) }
      if parts.count == 2 {
        let sourceX = parts[0] - (lemming.position.x - sprite.footX)
        let sourceY = parts[1] - (lemming.position.y - sprite.footY)
        if (0..<sprite.width).contains(sourceX), (0..<sprite.height).contains(sourceY) {
          let offset = (sourceY * sprite.width + sourceX) * 4
          print("Pixel \(value) lemming #\(lemming.id): source \(sourceX),\(sourceY) "
            + "rgba \(sprite.rgba[offset...offset + 3].map(String.init).joined(separator: ","))")
        }
      }
    }
    sourceOver(
      sprite.rgba,
      width: sprite.width,
      height: sprite.height,
      x: lemming.position.x - sprite.footX,
      y: lemming.position.y - sprite.footY,
      canvasWidth: rendered.width,
      canvasHeight: rendered.height,
      canvas: &rgba)
  }
  return rgba
}

private func standardTicks(
  replay: NxrpReplay,
  level: NxlvLevel,
  rendered: NxlvRenderedLevel
) throws -> [Int] {
  var probe = try NxrpReplayPlayback(
    sourceCompatibleReplay: replay,
    level: level,
    renderedLevel: rendered)
  var eventTicks: Set<Int> = []
  let cutoff = max(
    replay.commands.map(\.tick).max() ?? 0,
    replay.metadata.expectedCompletionFrame ?? 0) + 5 * 60 * NeoLemmixRules.ticksPerSecond
  while !probe.simulation.isComplete && probe.simulation.tickCount <= cutoff {
    let events = try probe.step()
    if !events.isEmpty { eventTicks.insert(probe.simulation.tickCount) }
  }
  let terminalTick = probe.simulation.tickCount
  var ticks: Set<Int> = [0, terminalTick]
  for tick in stride(from: 0, through: terminalTick, by: NeoLemmixRules.ticksPerSecond) {
    ticks.insert(tick)
  }
  for command in replay.commands {
    for offset in -1...34 { ticks.insert(command.tick + offset) }
  }
  for tick in eventTicks {
    for offset in -1...17 { ticks.insert(tick + offset) }
  }
  let opening = probe.simulation.configuration.entranceOpenTick
  for offset in -1...17 { ticks.insert(opening + offset) }
  if let completion = replay.metadata.expectedCompletionFrame {
    for offset in -1...1 { ticks.insert(completion + offset) }
  }
  return ticks.filter { (0...terminalTick).contains($0) }.sorted()
}

guard CommandLine.arguments.count >= 6 else {
  FileHandle.standardError.write(Data(
    "Usage: NeoLemmixReplayCapture <level.nxlv> <replay.nxrp> <styles> <output-directory> <standard | tick [tick ...]>\n".utf8))
  exit(2)
}

do {
  let levelURL = URL(fileURLWithPath: CommandLine.arguments[1])
  let replayURL = URL(fileURLWithPath: CommandLine.arguments[2])
  let stylesURL = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
  let outputURL = URL(fileURLWithPath: CommandLine.arguments[4], isDirectory: true)
  let tickArguments = Array(CommandLine.arguments.dropFirst(5))
  guard let level = NxlvLevel(text: try text(at: levelURL)) else {
    throw Failure(description: "Could not parse \(levelURL.path).")
  }
  let replayResult = NxrpReplayDecoder.decode(try text(at: replayURL))
  guard let replay = replayResult.replay,
        !replayResult.diagnostics.contains(where: { $0.severity == .error }) else {
    throw Failure(description: "Could not parse \(replayURL.path).")
  }
  try replay.verifyLevelIdentity(level)
  let resolution = NxlvStyleResolver(stylesRootURL: stylesURL).resolve(level: level)
  let renderResult = NxlvRenderer(retainsVisualLayers: true).render(
    level: level, resolution: resolution)
  guard resolution.isComplete, !renderResult.hasErrors,
        let rendered = renderResult.renderedLevel else {
    throw Failure(description: "Could not render \(levelURL.path).")
  }
  var playback = try NxrpReplayPlayback(
    sourceCompatibleReplay: replay,
    level: level,
    renderedLevel: rendered)
  let sprites = try NeoLemmixSpriteSet(
    stylesRootURL: stylesURL,
    themeStyle: level.themeStyle)
  let ticks: [Int]
  if tickArguments == ["standard"] {
    ticks = try standardTicks(replay: replay, level: level, rendered: rendered)
  } else {
    ticks = try tickArguments.map { value -> Int in
      guard let tick = Int(value), tick >= 0 else {
        throw Failure(description: "Invalid capture tick \(value).")
      }
      return tick
    }
    guard ticks == ticks.sorted(), Set(ticks).count == ticks.count else {
      throw Failure(description: "Capture ticks must be unique and ascending.")
    }
  }
  try FileManager.default.createDirectory(
    at: outputURL, withIntermediateDirectories: true)
  var captures: [CaptureManifest.Frame] = []
  for tick in ticks {
    while playback.simulation.tickCount < tick && !playback.simulation.isComplete {
      try playback.step()
    }
    guard playback.simulation.tickCount == tick else {
      throw Failure(description:
        "Replay completed at tick \(playback.simulation.tickCount) before capture tick \(tick).")
    }
    if ProcessInfo.processInfo.environment["NXLV_CAPTURE_TRACE_LEMMINGS"] == "1" {
      let order = NeoLemmixRenderOrder.sorted(playback.simulation.lemmings).map { lemming in
        "#\(lemming.id):\(lemming.action.rawValue)@\(lemming.position.x),\(lemming.position.y)"
          + "/f\(lemming.animationFrame)"
          + (lemming.isActive ? "" : "/removed")
      }
      print("Tick \(tick) render order: \(order.joined(separator: " "))")
      print("Tick \(tick) gadget frames: \(playback.simulation.gadgetAnimationFrames ?? [:])")
    }
    let rgba = frame(
      rendered: rendered,
      simulation: playback.simulation,
      sprites: sprites)
    let filename = String(format: "tick-%08d.png", tick)
    try writePNG(
      rgba,
      width: rendered.width,
      height: rendered.height,
      to: outputURL.appendingPathComponent(filename))
    captures.append(.init(
      tick: tick,
      file: filename,
      rgbaSHA256: digest(Data(rgba)),
      saved: playback.simulation.savedCount,
      lost: playback.simulation.lostCount,
      activeLemmings: playback.simulation.activeLemmings.count))
  }
  let manifest = CaptureManifest(
    replaySHA256: digest(try Data(contentsOf: replayURL, options: .mappedIfSafe)),
    levelID: String(format: "x%016llX", level.id ?? 0),
    levelVersion: String(format: "x%016llX", level.version ?? 0),
    width: rendered.width,
    height: rendered.height,
    frames: captures)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  try encoder.encode(manifest).write(
    to: outputURL.appendingPathComponent("manifest.json"), options: .atomic)
  print("Captured \(captures.count) native replay frames in \(outputURL.path).")
} catch {
  FileHandle.standardError.write(Data("NeoLemmix replay capture failed: \(error)\n".utf8))
  exit(1)
}
