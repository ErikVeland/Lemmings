import Foundation
import NxlvKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func writePNG(_ image: SequelIndexedImage, to path: String) throws {
    try writePNG(width: image.width, height: image.height, rgba: image.rgba(), to: path)
}

func writePNG(width: Int, height: Int, rgba: [UInt8], to path: String) throws {
    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
        let cg = CGImage(width: width, height: height,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        throw SequelDataError.invalid("Could not create the preview image.")
    }
    let output = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw SequelDataError.invalid("Could not create the PNG destination.")
    }
    CGImageDestinationAddImage(destination, cg, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "PNG", code: 1) }
}

do {
    guard CommandLine.arguments.count >= 2 else {
        throw NSError(domain: "Usage: SequelProbe DATA_ROOT [OUTPUT.png]", code: 1)
    }
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    if CommandLine.arguments.contains("--sprites") {
        var frames: [(Int, Int, [UInt8], [Bool])] = []
        let palette: [UInt8]
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("L3CD.EXE").path) {
            let creature = CommandLine.arguments.first { $0.hasPrefix("--creature=") }.flatMap { Int($0.dropFirst(11)) }
            let prefix = creature.map { String(format: "GRAPHICS/CREAT%03d", $0) } ?? "GRAPHICS/TRIBE004"
            let bank = try Lemmings3Sprites(
                index: Data(contentsOf: root.appendingPathComponent(prefix + ".IND")),
                commands: Data(contentsOf: root.appendingPathComponent(prefix + ".CMP")))
            let base = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: 1).palette
            palette = try Lemmings3Sprites.palette(Data(contentsOf: root.appendingPathComponent(prefix + ".PAL")), over: base)
            for (id, animation) in bank.animations.enumerated() {
                if let frame = animation.frames.first {
                    print("\(frames.count): animation \(id), \(animation.frames.count) frames")
                    frames.append((animation.width, animation.height, frame.pixels, frame.opaque))
                }
            }
        } else {
            let bank = try Lemmings2Sprites(data: Data(contentsOf: root.appendingPathComponent("VLEMMS.DAT")))
            palette = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/CLASSIC.DAT"))).palette
            for key in bank.animations.keys.sorted() {
                if let frame = bank.animations[key]?.first {
                    print("\(frames.count): \(key), \(bank.animations[key]!.count) frames, offset \(frame.x),\(frame.y)")
                    frames.append((frame.width, frame.height, frame.pixels, frame.opaque))
                }
            }
        }
        let width = 8 * 64
        let height = max(1, (frames.count + 7) / 8) * 64
        var rgba = Array(repeating: UInt8(32), count: width * height * 4)
        for pixel in 0..<(width * height) { rgba[pixel * 4 + 3] = 255 }
        for (index, frame) in frames.enumerated() {
            for y in 0..<min(64, frame.1) {
                for x in 0..<min(64, frame.0) where frame.3[y * frame.0 + x] {
                    let destination = ((index / 8 * 64 + y) * width + index % 8 * 64 + x) * 4
                    let colour = Int(frame.2[y * frame.0 + x]) * 4
                    rgba.replaceSubrange(destination..<(destination + 4), with: palette[colour..<(colour + 4)])
                }
            }
        }
        try writePNG(width: width, height: height, rgba: rgba, to: CommandLine.arguments[2])
        exit(0)
    }
    if FileManager.default.fileExists(atPath: root.appendingPathComponent("L3CD.EXE").path) {
        let option = CommandLine.arguments.first { $0.hasPrefix("--level=") }
        let number = option.flatMap { Int($0.dropFirst(8)) } ?? 1
        guard (1...999).contains(number) else { throw SequelDataError.invalid("Choose a native L3 level file number from 1 to 999.") }
        let level = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: level.style)
        if let option = CommandLine.arguments.first(where: { $0.hasPrefix("--object=") }),
           let identifier = Int(option.dropFirst(9)) {
            let frameNumber = CommandLine.arguments.first { $0.hasPrefix("--frame=") }.flatMap { Int($0.dropFirst(8)) } ?? 0
            let frame = try style.permanent.image(object: identifier, frame: frameNumber, palette: style.palette)
            if CommandLine.arguments.count > 2 {
                let rgba = frame.rgba()
                let scaled = (0..<(frame.height * 8)).flatMap { y in
                    (0..<(frame.width * 8)).flatMap { x -> [UInt8] in
                        let offset = ((y / 8) * frame.width + x / 8) * 4
                        return Array(rgba[offset..<(offset + 4)])
                    }
                }
                try writePNG(width: frame.width * 8, height: frame.height * 8, rgba: scaled, to: CommandLine.arguments[2])
            }
            print("L3 object \(identifier): \(frame.width)x\(frame.height)")
            exit(0)
        }
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let scene = try Lemmings3Scene(level: level, style: style, permanent: permanent, temporary: temporary)
        if CommandLine.arguments.count > 2 { try writePNG(scene.image, to: CommandLine.arguments[2]) }
        print("Lemmings 3: \(scene.image.width)x\(scene.image.height), \(permanent.placements.count + temporary.placements.count) placed objects")
        exit(0)
    }
    let option = CommandLine.arguments.first { $0.hasPrefix("--level=") }
    let number = option.flatMap { Int($0.dropFirst(8)) } ?? 0
    guard (0..<120).contains(number) || [904, 906, 908, 910].contains(number) else {
        throw SequelDataError.invalid("Choose an L2 campaign level from 0 to 119, or practice level 904, 906, 908 or 910.")
    }
    let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
    let styles = ["CLASSIC", "BEACH", "CAVEMAN", "CIRCUS", "EGYPTIAN", "HIGHLAND", "MEDIEVAL", "OUTDOOR", "POLAR", "SHADOW", "SPACE", "SPORTS"]
    guard styles.indices.contains(level.style) else { throw SequelDataError.invalid("Unknown L2 style.") }
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(styles[level.style]).DAT")))
    let terrain = try Lemmings2Terrain(level: level, style: style)
    if CommandLine.arguments.count > 2 {
        var pixels = terrain.image.pixels
        let objects = try Lemmings2Objects(level: level, style: style)
        for part in objects.parts {
                guard let frame = part.frames.first else { continue }
                for y in 0..<frame.height {
                    for x in 0..<frame.width {
                        let px = part.x + frame.x + x
                        let py = part.y + frame.y + y
                        let colour = frame.pixels[y * frame.width + x]
                        if px >= 0 && py >= 0 && px < terrain.image.width && py < terrain.image.height && frame.opaque[y * frame.width + x] {
                            pixels[py * terrain.image.width + px] = colour
                        }
                    }
                }
        }
        let rgba = pixels.flatMap { value -> [UInt8] in
            let index = Int(value) * 4
            return Array(style.palette[index..<(index + 4)])
        }
        try writePNG(width: terrain.image.width, height: terrain.image.height,
                     rgba: rgba, to: CommandLine.arguments[2])
    }
    print("\(level.title): \(terrain.image.width)x\(terrain.image.height), \(level.skills.count) skill slots")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
