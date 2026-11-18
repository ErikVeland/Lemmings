import CoreGraphics
import Foundation
import ImageIO
import NxlvKit

func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    guard condition() else { fatalError("FAIL \(label)") }
}

let pack = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = pack.appendingPathComponent("assets/data/images")
let spritePNG = try Data(contentsOf: source.appendingPathComponent("lixsprites.png"))
let recolourPNG = try Data(contentsOf: source.appendingPathComponent("lixrecol.png"))
let metadata = try Data(contentsOf: pack.appendingPathComponent("sprite-metadata.json"))
let artwork = try LixArtwork(directory: pack)
check(artwork.frameCount(for: .walker) == 11, "pinned walking sequence")
check(artwork.frameCount(for: .builder) == 16, "pinned builder sequence")
check(artwork.frameCount(for: .exploder) == 0, "missing source sequence stays explicit")
check(artwork.frame(activity: .exploder, animationFrame: 0, facingLeft: false) == nil, "no invented explosion frames")
let right = artwork.frame(activity: .walker, animationFrame: 0, facingLeft: false)!
let left = artwork.frame(activity: .walker, animationFrame: 0, facingLeft: true)!
check(right.rgba[3] == 0, "source black becomes transparent through the upstream recolour table")
check(right.rgba.enumerated().contains { $0.offset % 4 == 3 && $0.element == 255 }, "character remains visible")
check(right.footX == 16 && left.footX == 16 && right.footY == 26 && left.footY == 26, "stable two-pixel foot anchor")
for y in 0..<34 {
    for x in 0..<34 {
        let a = (y * 34 + x) * 4
        let b = (y * 34 + 33 - x) * 4
        check(Array(right.rgba[a..<(a + 4)]) == Array(left.rgba[b..<(b + 4)]), "exact horizontal mirroring")
    }
}
check(artwork.frame(activity: .walker, animationFrame: -1, facingLeft: false)?.index == 10, "negative tick wraps safely")
check(artwork.frame(activity: .walker, animationFrame: Int.min, facingLeft: false) != nil, "minimum tick does not overflow")

func rejects(_ data: Data, _ label: String) {
    do {
        _ = try LixArtwork(spritePNG: spritePNG, recolourPNG: recolourPNG, metadata: data)
        fatalError("FAIL \(label)")
    } catch { }
}
var model = try JSONSerialization.jsonObject(with: metadata) as! [String: Any]
var rows = model["rows"] as! [[String: Any]]
rows[0]["activity"] = "walker"
model["rows"] = rows
rejects(try JSONSerialization.data(withJSONObject: model), "duplicate activity rejection")
model = try JSONSerialization.jsonObject(with: metadata) as! [String: Any]
rows = model["rows"] as! [[String: Any]]
rows[9]["frames"] = [["x": Int.max, "y": 316, "width": 34, "height": 34]]
model["rows"] = rows
rejects(try JSONSerialization.data(withJSONObject: model), "out-of-bounds frame rejection")
model = try JSONSerialization.jsonObject(with: metadata) as! [String: Any]
model["frameWidth"] = Int.max
rejects(try JSONSerialization.data(withJSONObject: model), "unbounded dimensions rejected before arithmetic")
do {
    _ = try LixArtwork(spritePNG: Data([0, 1]), recolourPNG: recolourPNG, metadata: metadata)
    fatalError("FAIL malformed image rejection")
} catch { }

let activities: [LixArtwork.Activity] = [.walker, .climber, .floater, .builder, .basher, .miner, .digger, .blocker]
let scale = 3, cell = 34 * 3, width = cell * 8, height = cell * activities.count
var pixels = [UInt8](repeating: 0, count: width * height * 4)
for offset in stride(from: 0, to: pixels.count, by: 4) {
    pixels[offset] = 36; pixels[offset + 1] = 35; pixels[offset + 2] = 51; pixels[offset + 3] = 255
}
for (row, activity) in activities.enumerated() {
    for column in 0..<8 {
        let frame = artwork.frame(activity: activity, animationFrame: column / 2, facingLeft: column % 2 == 1)!
        for y in 0..<34 {
            for x in 0..<34 {
                let source = (y * 34 + x) * 4
                guard frame.rgba[source + 3] != 0 else { continue }
                for dy in 0..<scale { for dx in 0..<scale {
                    let target = ((row * cell + y * scale + dy) * width + column * cell + x * scale + dx) * 4
                    pixels.replaceSubrange(target..<(target + 4), with: frame.rgba[source..<(source + 4)])
                } }
            }
        }
    }
}
let provider = CGDataProvider(data: Data(pixels) as CFData)!
let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
    decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("lix-rendered-poses.png") as CFURL,
    "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
check(CGImageDestinationFinalize(destination), "write rendered pose capture")
print("PASS Lix source decode, alpha, anchors, mirroring, timing bounds and malformed-input checks")
