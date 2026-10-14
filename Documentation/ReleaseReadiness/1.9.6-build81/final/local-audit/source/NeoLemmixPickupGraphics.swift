import CoreGraphics
import Foundation
import ImageIO

/// CE's generated 24x24 pickup-skill animation. Frames are ordered as
/// exhausted/available pairs for the 21 current skills.
enum NeoLemmixPickupGraphics {
    struct Result {
        let width: Int
        let height: Int
        let framesRGBA: [[UInt8]]
    }

    private struct Animation {
        let frames: Int
        let rightFoot: (x: Int, y: Int)
        let leftFoot: (x: Int, y: Int)
        let sheet: Image
    }

    private struct Image {
        let width: Int
        let height: Int
        var rgba: [UInt8]
    }

    private struct Pose {
        let name: String
        let frame: Int
        let left: Bool
        let footX: Int
        let footY: Int
    }

    static func make(
        themeAsset: NxlvResolvedStyleAsset,
        stylesRootURL: URL,
        eraseFrames: [[UInt8]]?,
        eraseWidth: Int,
        eraseHeight: Int
    ) -> Result? {
        guard let themeURL = themeAsset.metadataURL,
              let themeText = try? String(contentsOf: themeURL, encoding: .utf8) else { return nil }
        let theme = NxlvParser.parse(themeText)
        let lemmingStyle = theme.trimmedLine("lemmings") ?? "default"
        let resolution = NxlvStyleResolver(stylesRootURL: stylesRootURL).resolve(references: [
            NxlvStyleAssetReference(kind: .lemmings, style: lemmingStyle),
        ])
        guard resolution.isComplete,
              let asset = resolution.assets.first,
              let schemeURL = asset.metadataURL,
              let schemeText = try? String(contentsOf: schemeURL, encoding: .utf8),
              let animationSections = NxlvParser.parse(schemeText).section("animations") else {
            return nil
        }
        let scheme = NxlvParser.parse(schemeText)
        let sourceColors = namedColors(in: scheme.section("spriteset_recoloring"))
        let themeColors = namedColors(in: theme.section("colors"))
        var recoloring: [UInt32: UInt32] = [:]
        for (name, source) in sourceColors {
            if let target = themeColors[name] { recoloring[source] = target }
        }
        for (alternate, primary) in shades(in: scheme.section("shades")) {
            if let target = recoloring[primary] {
                recoloring[alternate] = applyColorShift(
                    to: target, primary: primary, alternate: alternate
                )
            }
        }
        let graphics = Dictionary(uniqueKeysWithValues: asset.graphicURLs.map {
            ($0.deletingPathExtension().lastPathComponent.lowercased(), $0)
        })
        var animations: [String: Animation] = [:]
        for section in animationSections.subsections {
            let name = section.keyword.lowercased()
            guard let count = section.numeric("frames"), count > 0,
                  let right = section.section("right"), let left = section.section("left"),
                  let rightX = right.numeric("foot_x"), let rightY = right.numeric("foot_y"),
                  let leftX = left.numeric("foot_x"), let leftY = left.numeric("foot_y"),
                  let url = graphics[name], var sheet = decode(url),
                  sheet.width.isMultiple(of: 2), sheet.height.isMultiple(of: count) else { continue }
            recolor(&sheet.rgba, with: recoloring)
            animations[name] = Animation(
                frames: count,
                rightFoot: (rightX, rightY),
                leftFoot: (leftX, leftY),
                sheet: sheet
            )
        }

        let poses: [NxlvSkill: [Pose]] = [
            .walker: [Pose(name: "walker", frame: 1, left: false, footX: 11, footY: 18)],
            .jumper: [Pose(name: "jumper", frame: 0, left: false, footX: 11, footY: 16)],
            .shimmier: [Pose(name: "shimmier", frame: 1, left: false, footX: 11, footY: 15)],
            .slider: [Pose(name: "slider", frame: 0, left: true, footX: 9, footY: 17)],
            .climber: [Pose(name: "climber", frame: 3, left: false, footX: 14, footY: 18)],
            .swimmer: [Pose(name: "swimmer", frame: 2, left: false, footX: 12, footY: 13)],
            .floater: [Pose(name: "floater", frame: 4, left: false, footX: 10, footY: 25)],
            .glider: [Pose(name: "glider", frame: 4, left: false, footX: 10, footY: 25)],
            .disarmer: [Pose(name: "disarmer", frame: 6, left: false, footX: 9, footY: 16)],
            .bomber: [Pose(name: "ohnoer", frame: 7, left: false, footX: 11, footY: 16)],
            .stoner: [Pose(name: "stoner", frame: 0, left: false, footX: 12, footY: 18)],
            .blocker: [Pose(name: "blocker", frame: 0, left: false, footX: 11, footY: 18)],
            .platformer: [Pose(name: "platformer", frame: 1, left: false, footX: 11, footY: 15)],
            .builder: [Pose(name: "builder", frame: 1, left: false, footX: 11, footY: 16)],
            .stacker: [Pose(name: "stacker", frame: 0, left: false, footX: 11, footY: 17)],
            .laserer: [Pose(name: "laserer", frame: 0, left: false, footX: 12, footY: 17)],
            .basher: [Pose(name: "basher", frame: 0, left: false, footX: 12, footY: 17)],
            .fencer: [Pose(name: "fencer", frame: 1, left: false, footX: 11, footY: 17)],
            .miner: [Pose(name: "miner", frame: 12, left: false, footX: 8, footY: 17)],
            .digger: [Pose(name: "digger", frame: 4, left: false, footX: 12, footY: 15)],
            .cloner: [
                Pose(name: "walker", frame: 1, left: true, footX: 10, footY: 18),
                Pose(name: "walker", frame: 1, left: false, footX: 13, footY: 18),
            ],
        ]
        var icons: [[UInt8]] = []
        for skill in NxlvSkill.allCases {
            var icon = Array(repeating: UInt8(0), count: 24 * 24 * 4)
            for pose in poses[skill] ?? [] {
                guard let animation = animations[pose.name] else { return nil }
                draw(
                    animation: animation,
                    frame: pose.frame,
                    left: pose.left,
                    footX: pose.footX,
                    footY: pose.footY,
                    into: &icon
                )
            }
            drawBricks(for: skill, color: brickColor(themeColors), into: &icon)
            var exhausted = icon
            var available = icon
            if let eraseFrames, eraseFrames.count >= 2,
               eraseWidth == 24, eraseHeight == 24 {
                erase(eraseFrames[0], from: &exhausted)
                erase(eraseFrames[1], from: &available)
            } else {
                exhausted = Array(repeating: 0, count: 24 * 24 * 4)
            }
            icons.append(exhausted)
            icons.append(available)
        }
        return Result(width: 24, height: 24, framesRGBA: icons)
    }

    private static func draw(
        animation: Animation,
        frame: Int,
        left: Bool,
        footX: Int,
        footY: Int,
        into destination: inout [UInt8]
    ) {
        let frameWidth = animation.sheet.width / 2
        let frameHeight = animation.sheet.height / animation.frames
        let selected = min(max(0, frame), animation.frames - 1)
        // CE extracts RTL animations from the first half of a lemming sheet
        // and LTR animations from the second half.
        let sourceX = left ? 0 : frameWidth
        let sourceY = selected * frameHeight
        let foot = left ? animation.leftFoot : animation.rightFoot
        for y in 0..<frameHeight {
            for x in 0..<frameWidth {
                let dx = footX - foot.x + x
                let dy = footY - foot.y + y
                guard (0..<24).contains(dx), (0..<24).contains(dy) else { continue }
                let source = ((sourceY + y) * animation.sheet.width + sourceX + x) * 4
                let target = (dy * 24 + dx) * 4
                blend(animation.sheet.rgba, source, over: &destination, target)
            }
        }
    }

    private static func drawBricks(
        for skill: NxlvSkill,
        color: (UInt8, UInt8, UInt8),
        into image: inout [UInt8]
    ) {
        let points: [(Int, Int)]
        switch skill {
        case .platformer: points = stride(from: 6, through: 14, by: 2).map { ($0, 15) }
        case .builder: points = [(8, 17), (10, 16), (12, 15), (14, 14)]
        case .stacker: points = (12...17).map { (13, $0) }
        default: return
        }
        for (x, y) in points {
            for dx in 0..<2 where (0..<24).contains(x + dx) && (0..<24).contains(y) {
                let offset = (y * 24 + x + dx) * 4
                image[offset] = color.0
                image[offset + 1] = color.1
                image[offset + 2] = color.2
                image[offset + 3] = 255
            }
        }
    }

    private static func erase(_ mask: [UInt8], from image: inout [UInt8]) {
        guard mask.count == image.count else { return }
        for offset in stride(from: 0, to: image.count, by: 4) {
            let alpha = Int(image[offset + 3])
            let maskAlpha = Int(mask[offset + 3])
            image[offset + 3] = UInt8((alpha * (255 - maskAlpha) + 127) / 255)
        }
    }

    private static func blend(
        _ source: [UInt8], _ sourceOffset: Int,
        over destination: inout [UInt8], _ destinationOffset: Int
    ) {
        let alpha = Int(source[sourceOffset + 3])
        guard alpha > 0 else { return }
        if alpha == 255 {
            destination[destinationOffset..<(destinationOffset + 4)] = source[sourceOffset..<(sourceOffset + 4)]
            return
        }
        let inverse = 255 - alpha
        let destinationAlpha = Int(destination[destinationOffset + 3])
        let scale = alpha * 255 + destinationAlpha * inverse
        for channel in 0..<3 {
            let value = Int(source[sourceOffset + channel]) * alpha * 255
                + Int(destination[destinationOffset + channel]) * destinationAlpha * inverse
            destination[destinationOffset + channel] = UInt8((value + scale / 2) / scale)
        }
        destination[destinationOffset + 3] = UInt8((scale + 127) / 255)
    }

    private static func decode(_ url: URL) -> Image? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        var bytes = Array(repeating: UInt8(0), count: cgImage.width * cgImage.height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(cgImage.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0..<3 {
                bytes[offset + channel] = UInt8(
                    min(255, (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha)
                )
            }
        }
        return Image(width: cgImage.width, height: cgImage.height, rgba: bytes)
    }

    private static func recolor(_ bytes: inout [UInt8], with palette: [UInt32: UInt32]) {
        for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] != 0 {
            let source = color(bytes[offset], bytes[offset + 1], bytes[offset + 2])
            guard let target = palette[source] else { continue }
            bytes[offset] = UInt8((target >> 16) & 0xFF)
            bytes[offset + 1] = UInt8((target >> 8) & 0xFF)
            bytes[offset + 2] = UInt8(target & 0xFF)
        }
    }

    private static func namedColors(in section: NxlvSection?) -> [String: UInt32] {
        guard let section else { return [:] }
        return Dictionary(uniqueKeysWithValues: section.lineRecords.compactMap { line in
            parseColor(line.value).map { (line.keyword.lowercased(), $0) }
        })
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

    private static func parseColor(_ value: String) -> UInt32? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmed.hasPrefix("#") ? "$" + trimmed.dropFirst() : trimmed
        guard let number = NxlvNumber.unsignedInteger(String(token)), number <= 0xFF_FF_FF else {
            return nil
        }
        return UInt32(number)
    }

    private static func brickColor(_ colors: [String: UInt32]) -> (UInt8, UInt8, UInt8) {
        var value = colors["pickup_bricks"] ?? 0xFF_FF_FF
        if value == colors["mask"] { value = 0xFF_FF_FF }
        return (UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF))
    }

    private static func applyColorShift(to base: UInt32, primary: UInt32, alternate: UInt32) -> UInt32 {
        let p = hsv(primary), a = hsv(alternate)
        let first = shifted(primary, hue: a.h - p.h, saturation: a.s - p.s, value: a.v - p.v)
        let adjustment = (
            component(alternate, 16) - component(first, 16),
            component(alternate, 8) - component(first, 8),
            component(alternate, 0) - component(first, 0)
        )
        let result = shifted(base, hue: a.h - p.h, saturation: a.s - p.s, value: a.v - p.v)
        return color(
            clamp(component(result, 16) + adjustment.0),
            clamp(component(result, 8) + adjustment.1),
            clamp(component(result, 0) + adjustment.2)
        )
    }

    private static func hsv(_ value: UInt32) -> (h: Double, s: Double, v: Double) {
        let r = Double(component(value, 16)) / 255
        let g = Double(component(value, 8)) / 255
        let b = Double(component(value, 0)) / 255
        let maximum = max(r, g, b), minimum = min(r, g, b), delta = maximum - minimum
        var hue = 0.0
        if delta != 0 {
            if maximum == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maximum == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maximum == 0 ? 0 : delta / maximum, maximum)
    }

    private static func shifted(
        _ sourceColor: UInt32, hue: Double, saturation: Double, value: Double
    ) -> UInt32 {
        let source = hsv(sourceColor)
        var h = (source.h + hue).truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        let s = min(1, max(0, source.s + saturation))
        let v = min(1, max(0, source.v + value))
        let sector = h * 6, index = Int(floor(sector)), fraction = sector - floor(sector)
        let p = v * (1 - s), q = v * (1 - fraction * s), t = v * (1 - (1 - fraction) * s)
        let rgb: (Double, Double, Double)
        switch index % 6 {
        case 0: rgb = (v, t, p)
        case 1: rgb = (q, v, p)
        case 2: rgb = (p, v, t)
        case 3: rgb = (p, q, v)
        case 4: rgb = (t, p, v)
        default: rgb = (v, p, q)
        }
        return color(Int((rgb.0 * 255).rounded()), Int((rgb.1 * 255).rounded()), Int((rgb.2 * 255).rounded()))
    }

    private static func component(_ color: UInt32, _ shift: UInt32) -> Int {
        Int((color >> shift) & 0xFF)
    }

    private static func clamp(_ value: Int) -> Int { min(255, max(0, value)) }

    private static func color(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> UInt32 {
        color(Int(red), Int(green), Int(blue))
    }

    private static func color(_ red: Int, _ green: Int, _ blue: Int) -> UInt32 {
        UInt32(clamp(red) << 16 | clamp(green) << 8 | clamp(blue))
    }
}
