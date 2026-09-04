import Foundation
import NxlvKit

// Match native sprite pixels against the recorded Beach practice sequence.
// Only literal sprite pixels are compared. Skipped pixels retain the terrain.
// The follow-up search uses the measured flat-platform region and LM5C bank.
// A match identifies pixels, not the active skill or the engine's sprite ID.
do {
    guard CommandLine.arguments.count == 4 else {
        throw SequelDataError.invalid("Usage: SequelTrace L2_ROOT STYLE RAW_RGB24")
    }
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let bank = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(CommandLine.arguments[2]).DAT")))
    let video = [UInt8](try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
    let stride = 320 * 200 * 3
    guard video.count.isMultiple(of: stride) else { throw SequelDataError.invalid("Partial RGB24 video frame.") }
    struct Template {
        let animation: String
        let frame: Int
        let width: Int
        let height: Int
        let originX: Int
        let originY: Int
        let pixels: [(Int, Int, Int, Int)]
    }
    var templates: [Template] = []
    for name in bank.animations.keys.sorted() {
        for (index, frame) in bank.animations[name]!.enumerated() {
            var pixels: [(Int, Int, Int, Int)] = []
            for p in frame.pixels.indices where frame.opaque[p] {
                let colour = Int(frame.pixels[p]) * 4
                pixels.append(((p / frame.width * 320 + p % frame.width) * 3,
                               Int(style.palette[colour]), Int(style.palette[colour + 1]), Int(style.palette[colour + 2])))
            }
            if pixels.count >= 12 {
                templates.append(Template(animation: name, frame: index, width: frame.width, height: frame.height,
                                          originX: frame.x, originY: frame.y, pixels: pixels))
            }
        }
    }
    print("videoFrame,animation,spriteFrame,x,y,originX,originY")
    for sample in 0..<(video.count / stride) {
        // Identify candidate animations from frame zero, then trace those.
        let candidates = sample == 0 ? templates : templates.filter { $0.animation == "LM5C" }
        for sprite in candidates {
            guard sprite.width <= 320, sprite.height <= 160 else { continue }
            for y in (sample == 0 ? 0 : 80)...min(160 - sprite.height, sample == 0 ? 160 : 100) {
                for x in (sample == 0 ? 0 : 160)...min(320 - sprite.width, sample == 0 ? 320 : 230) {
                    let start = sample * stride + (y * 320 + x) * 3
                    var matches = true
                    for (offset, r, g, b) in sprite.pixels {
                        if abs(Int(video[start + offset]) - r) > 3 ||
                            abs(Int(video[start + offset + 1]) - g) > 3 ||
                            abs(Int(video[start + offset + 2]) - b) > 3 {
                            matches = false
                            break
                        }
                    }
                    if matches { print("\(sample),\(sprite.animation),\(sprite.frame),\(x),\(y),\(x - sprite.originX),\(y - sprite.originY)") }
                }
            }
        }
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
