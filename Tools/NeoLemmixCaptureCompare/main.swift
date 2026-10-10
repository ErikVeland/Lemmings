import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

private struct Failure: Error, CustomStringConvertible {
  let description: String
}

private struct Manifest: Decodable {
  struct Frame: Decodable {
    let tick: Int
    let file: String
    let rgbaSHA256: String?
  }

  let format: String
  let producer: String
  let replaySHA256: String
  let levelID: String
  let levelVersion: String
  let width: Int
  let height: Int
  let frames: [Frame]
}

private struct Bitmap {
  let width: Int
  let height: Int
  let rgba: [UInt8]
}

private func decodeManifest(_ directory: URL) throws -> Manifest {
  try JSONDecoder().decode(
    Manifest.self,
    from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
}

private func decodePNG(_ url: URL) throws -> Bitmap {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    throw Failure(description: "Could not decode \(url.path).")
  }
  var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
  guard let context = CGContext(
    data: &rgba,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: image.width * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
      .union(.byteOrder32Big).rawValue) else {
    throw Failure(description: "Could not create a bitmap context for \(url.path).")
  }
  context.interpolationQuality = .none
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  for offset in stride(from: 0, to: rgba.count, by: 4) {
    let alpha = Int(rgba[offset + 3])
    guard alpha > 0 && alpha < 255 else { continue }
    for channel in 0..<3 {
      rgba[offset + channel] = UInt8(min(
        255,
        (Int(rgba[offset + channel]) * 255 + alpha / 2) / alpha))
    }
  }
  return Bitmap(width: image.width, height: image.height, rgba: rgba)
}

private func digest(_ rgba: [UInt8]) -> String {
  SHA256.hash(data: Data(rgba)).map { String(format: "%02x", $0) }.joined()
}

private func compare(_ native: Bitmap, _ oracle: Bitmap, tick: Int) throws -> String? {
  guard native.width == oracle.width, native.height == oracle.height else {
    throw Failure(description:
      "Tick \(tick) dimension mismatch: native \(native.width)x\(native.height), "
        + "CE \(oracle.width)x\(oracle.height).")
  }
  var visibleRGB = 0
  var alpha = 0
  var samples: [String] = []
  for y in 0..<native.height {
    for x in 0..<native.width {
      let offset = (y * native.width + x) * 4
      if native.rgba[offset + 3] != oracle.rgba[offset + 3] { alpha += 1 }
      guard native.rgba[offset + 3] != 0, oracle.rgba[offset + 3] != 0,
            native.rgba[offset..<(offset + 3)] != oracle.rgba[offset..<(offset + 3)] else {
        continue
      }
      visibleRGB += 1
      if samples.count < 12 {
        samples.append("(\(x),\(y))")
      }
    }
  }
  guard visibleRGB == 0 else {
    return "Tick \(tick) has \(visibleRGB) mutually visible RGB differences "
      + "(sample \(samples.joined(separator: ", ")))."
  }
  print("MATCH tick \(tick): zero mutually visible RGB differences, \(alpha) alpha differences.")
  return nil
}

guard CommandLine.arguments.count == 3 else {
  FileHandle.standardError.write(Data(
    "Usage: NeoLemmixCaptureCompare <native-capture-directory> <ce-capture-directory>\n".utf8))
  exit(2)
}

do {
  let nativeDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  let oracleDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
  let native = try decodeManifest(nativeDirectory)
  let oracle = try decodeManifest(oracleDirectory)
  guard native.format == "neolemmix-replay-capture-v1",
        oracle.format == native.format else {
    throw Failure(description: "Unsupported capture manifest format.")
  }
  guard native.producer == "native" else {
    throw Failure(description: "The comparison input is not a native capture.")
  }
  guard oracle.producer.hasPrefix("ce:") else {
    throw Failure(description: "The oracle capture is not marked as CE-produced.")
  }
  guard native.replaySHA256 == oracle.replaySHA256,
        native.levelID == oracle.levelID,
        native.levelVersion == oracle.levelVersion,
        native.width == oracle.width,
        native.height == oracle.height else {
    throw Failure(description: "The capture manifests do not describe the same replay and level.")
  }
  let nativeByTick = Dictionary(grouping: native.frames, by: \.tick)
  let oracleByTick = Dictionary(grouping: oracle.frames, by: \.tick)
  guard nativeByTick.values.allSatisfy({ $0.count == 1 }),
        oracleByTick.values.allSatisfy({ $0.count == 1 }),
        Set(nativeByTick.keys) == Set(oracleByTick.keys),
        !nativeByTick.isEmpty else {
    throw Failure(description: "Capture ticks are missing, duplicated or different.")
  }
  var differences: [String] = []
  for tick in nativeByTick.keys.sorted() {
    let nativeFrame = nativeByTick[tick]![0]
    let oracleFrame = oracleByTick[tick]![0]
    let nativeBitmap = try decodePNG(nativeDirectory.appendingPathComponent(nativeFrame.file))
    let oracleBitmap = try decodePNG(oracleDirectory.appendingPathComponent(oracleFrame.file))
    if let expected = nativeFrame.rgbaSHA256, digest(nativeBitmap.rgba) != expected {
      throw Failure(description: "Native capture hash changed at tick \(tick).")
    }
    if let expected = oracleFrame.rgbaSHA256, digest(oracleBitmap.rgba) != expected {
      throw Failure(description: "CE capture hash changed at tick \(tick).")
    }
    if let difference = try compare(nativeBitmap, oracleBitmap, tick: tick) {
      differences.append(difference)
    }
  }
  guard differences.isEmpty else {
    throw Failure(description: differences.joined(separator: "\n"))
  }
  print("Matched \(nativeByTick.count) native replay frames to independent CE captures.")
} catch {
  FileHandle.standardError.write(Data("NeoLemmix capture comparison failed: \(error)\n".utf8))
  exit(1)
}
