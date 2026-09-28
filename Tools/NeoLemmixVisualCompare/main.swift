import CoreGraphics
import Foundation
import ImageIO
import NxlvKit
import UniformTypeIdentifiers

private struct Failure: Error, CustomStringConvertible {
  let description: String
}

private struct Bitmap {
  let width: Int
  let height: Int
  let rgba: [UInt8]
}

private func decodePNG(_ url: URL) throws -> Bitmap {
  guard
    let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else {
    throw Failure(description: "Could not decode \(url.path).")
  }

  var rgba = Array(repeating: UInt8(0), count: image.width * image.height * 4)
  guard let context = CGContext(
    data: &rgba,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: image.width * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
      .union(.byteOrder32Big).rawValue
  ) else {
    throw Failure(description: "Could not create a bitmap context for \(url.path).")
  }
  context.interpolationQuality = .none
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  return Bitmap(width: image.width, height: image.height, rgba: rgba)
}

private func writePNG(_ bitmap: Bitmap, to url: URL) throws {
  guard
    let provider = CGDataProvider(data: Data(bitmap.rgba) as CFData),
    let image = CGImage(
      width: bitmap.width,
      height: bitmap.height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bitmap.width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(.byteOrder32Big),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    ),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    throw Failure(description: "Could not create \(url.path).")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw Failure(description: "Could not write \(url.path).")
  }
}

private func compare(_ native: Bitmap, _ reference: Bitmap) throws {
  guard native.width == reference.width, native.height == reference.height else {
    throw Failure(
      description: "Dimension mismatch: native \(native.width)x\(native.height), "
        + "reference \(reference.width)x\(reference.height).")
  }

  var mismatchedPixels = 0
  var alphaMismatchedPixels = 0
  var visibleColorMismatchedPixels = 0
  var visibleColorSamples: [String] = []
  var largestChannelDelta = 0
  var minX = native.width
  var minY = native.height
  var maxX = -1
  var maxY = -1

  for y in 0..<native.height {
    for x in 0..<native.width {
      let offset = (y * native.width + x) * 4
      var differs = false
      var colorDiffers = false
      for channel in 0..<4 {
        let delta = abs(Int(native.rgba[offset + channel]) - Int(reference.rgba[offset + channel]))
        largestChannelDelta = max(largestChannelDelta, delta)
        differs = differs || delta != 0
        if channel < 3 { colorDiffers = colorDiffers || delta != 0 }
      }
      guard differs else { continue }
      mismatchedPixels += 1
      if native.rgba[offset + 3] != reference.rgba[offset + 3] {
        alphaMismatchedPixels += 1
      }
      if native.rgba[offset + 3] != 0, reference.rgba[offset + 3] != 0, colorDiffers {
        visibleColorMismatchedPixels += 1
        if visibleColorSamples.count < 32 {
          let nativePixel = native.rgba[offset..<(offset + 4)].map(String.init).joined(separator: ",")
          let referencePixel = reference.rgba[offset..<(offset + 4)].map(String.init).joined(separator: ",")
          visibleColorSamples.append("(\(x),\(y)) native [\(nativePixel)] reference [\(referencePixel)]")
        }
      }
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x)
      maxY = max(maxY, y)
    }
  }

  if mismatchedPixels == 0 {
    print("MATCH \(native.width)x\(native.height): every RGBA pixel matches.")
  } else {
    let total = native.width * native.height
    let percent = Double(mismatchedPixels) * 100 / Double(total)
    print(
      String(
        format: "DIFF %dx%d: %d/%d pixels (%.3f%%), %d alpha, %d visible RGB, bounds (%d,%d)-(%d,%d), max channel delta %d.",
        native.width, native.height, mismatchedPixels, total, percent,
        alphaMismatchedPixels, visibleColorMismatchedPixels,
        minX, minY, maxX, maxY, largestChannelDelta
      ))
    for sample in visibleColorSamples { print("  \(sample)") }
  }
}

private func reportTerrainCoverage(_ rendered: NxlvRenderedLevel) {
  guard rendered.terrainRGBA.count == rendered.width * rendered.height * 4 else { return }
  var mismatches = 0
  var first: (x: Int, y: Int)?
  for index in rendered.solidMask.indices {
    let visible = rendered.terrainRGBA[index * 4 + 3] != 0
    let solid = rendered.solidMask[index] != 0
    guard visible != solid else { continue }
    mismatches += 1
    if first == nil { first = (index % rendered.width, index / rendered.width) }
  }
  if let first {
    print("MASK DIFF: \(mismatches) terrain pixels; first mismatch at (\(first.x),\(first.y)).")
  } else {
    print("MASK MATCH: every visible terrain pixel has the same solid state.")
  }
}

guard (4...5).contains(CommandLine.arguments.count) else {
  FileHandle.standardError.write(
    Data("Usage: NeoLemmixVisualCompare <level.nxlv> <styles> <reference.png> [native.png]\n".utf8))
  exit(2)
}

do {
  let levelURL = URL(fileURLWithPath: CommandLine.arguments[1])
  let stylesURL = URL(fileURLWithPath: CommandLine.arguments[2])
  let referenceURL = URL(fileURLWithPath: CommandLine.arguments[3])
  let text = try String(contentsOf: levelURL, encoding: .utf8)
  guard let level = NxlvLevel(text: text) else {
    throw Failure(description: "Could not parse \(levelURL.path).")
  }

  let resolution = NxlvStyleResolver(stylesRootURL: stylesURL).resolve(level: level)
  let result = NxlvRenderer(retainsVisualLayers: true).render(level: level, resolution: resolution)
  if let diagnostic = (resolution.diagnostics + result.styleDiagnostics).first(where: {
    $0.severity == .error
  }) {
    throw Failure(description: diagnostic.message)
  }
  if let diagnostic = result.diagnostics.first(where: { $0.severity == .error }) {
    throw Failure(description: diagnostic.message)
  }
  guard let rendered = result.renderedLevel else {
    throw Failure(description: "The native renderer produced no level image.")
  }

  let native = Bitmap(width: rendered.width, height: rendered.height, rgba: rendered.rgba)
  reportTerrainCoverage(rendered)
  if CommandLine.arguments.count == 5 {
    try writePNG(native, to: URL(fileURLWithPath: CommandLine.arguments[4]))
  }
  try compare(native, decodePNG(referenceURL))
} catch {
  FileHandle.standardError.write(Data("NeoLemmix visual comparison failed: \(error)\n".utf8))
  exit(1)
}
