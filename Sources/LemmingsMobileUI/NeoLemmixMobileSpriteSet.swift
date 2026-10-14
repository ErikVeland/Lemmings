import CoreGraphics
import Foundation
import ImageIO
import LemmingsMobileCore
import NxlvKit

struct NeoLemmixMobileSpriteFrame {
    let rgba: [UInt8]
    let width: Int
    let height: Int
    let footX: Int
    let footY: Int
}

/**
 * Decodes lemming sheets from the player's resolved NeoLemmix styles.
 */
final class NeoLemmixMobileSpriteSet {
    private struct Animation {
        let frameCount: Int
        let loopFrame: Int?
        let leftFoot: CGPoint
        let rightFoot: CGPoint
        let sheet: CGImage
        let frameWidth: Int
        let frameHeight: Int
    }

    private let animations: [String: Animation]
    private let recolouring: [UInt32: UInt32]
    private let athleteColours: [UInt32: UInt32]
    private let zombieColours: [UInt32: UInt32]
    private let neutralColours: [UInt32: UInt32]
    private var cache: [String: NeoLemmixMobileSpriteFrame] = [:]

    init(stylesRootURL: URL, themeStyle: String) throws {
        let resolver = NxlvStyleResolver(stylesRootURL: stylesRootURL)
        let requestedTheme = themeStyle.isEmpty ? "default" : themeStyle
        let themeResolution = resolver.resolve(references: [
            NxlvStyleAssetReference(kind: .theme, style: requestedTheme),
        ])
        guard themeResolution.isComplete, let themeAsset = themeResolution.assets.first,
              let themeURL = themeAsset.metadataURL,
              let themeText = try? String(contentsOf: themeURL, encoding: .utf8) else {
            throw NeoLemmixMobileSpriteError.missingTheme(requestedTheme)
        }
        let theme = NxlvParser.parse(themeText)
        let lemmingStyle = theme.trimmedLine("lemmings") ?? "default"
        let spriteResolution = resolver.resolve(references: [
            NxlvStyleAssetReference(kind: .lemmings, style: lemmingStyle),
        ])
        guard spriteResolution.isComplete, let spriteAsset = spriteResolution.assets.first,
              let schemeURL = spriteAsset.metadataURL,
              let schemeText = try? String(contentsOf: schemeURL, encoding: .utf8) else {
            throw NeoLemmixMobileSpriteError.missingSpriteStyle(lemmingStyle)
        }
        let scheme = NxlvParser.parse(schemeText)
        let source = Self.namedColors(scheme.section("spriteset_recoloring"))
        let themeColours = Self.namedColors(theme.section("colors"))
        var mapping: [UInt32: UInt32] = [:]
        for (name, colour) in source {
            if let target = themeColours[name] { mapping[colour] = target }
        }
        let shades = Self.shades(scheme.section("shades"))
        for (alternate, primary) in shades {
            if let target = mapping[primary] {
                mapping[alternate] = Self.applyColorShift(to: target, primary: primary, alternate: alternate)
            }
        }
        recolouring = mapping
        let stateRecolouring = scheme.section("state_recoloring")
        athleteColours = Self.stateColours(stateRecolouring, name: "athlete", base: mapping, shades: shades)
        zombieColours = Self.stateColours(stateRecolouring, name: "zombie", base: mapping, shades: shades)
        neutralColours = Self.stateColours(stateRecolouring, name: "neutral", base: mapping, shades: shades)

        var graphics: [String: URL] = [:]
        for url in spriteAsset.graphicURLs {
            graphics[url.deletingPathExtension().lastPathComponent.lowercased()] = url
        }
        guard let sections = scheme.section("animations") else {
            throw NeoLemmixMobileSpriteError.missingAnimationMetadata
        }
        var decoded: [String: Animation] = [:]
        for section in sections.subsections {
            let name = section.keyword.lowercased()
            guard let frameCount = section.numeric("frames"), frameCount > 0,
                  let right = section.section("right"), let left = section.section("left"),
                  let rightX = right.numeric("foot_x"), let rightY = right.numeric("foot_y"),
                  let leftX = left.numeric("foot_x"), let leftY = left.numeric("foot_y"),
                  let url = graphics[name], let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  sheet.width.isMultiple(of: 2), sheet.height.isMultiple(of: frameCount) else { continue }
            let frameWidth = sheet.width / 2
            let frameHeight = sheet.height / frameCount
            guard frameWidth > 0, frameHeight > 0,
                  (0...frameWidth).contains(rightX), (0...frameHeight).contains(rightY),
                  (0...frameWidth).contains(leftX), (0...frameHeight).contains(leftY) else { continue }
            decoded[name] = Animation(frameCount: frameCount, loopFrame: section.numeric("loop_to_frame"),
                leftFoot: CGPoint(x: leftX, y: leftY), rightFoot: CGPoint(x: rightX, y: rightY),
                sheet: sheet, frameWidth: frameWidth, frameHeight: frameHeight)
        }
        for name in Set(NeoLemmixAction.allCases.compactMap(Self.animationName)) where decoded[name] == nil {
            throw NeoLemmixMobileSpriteError.missingAnimation(name)
        }
        animations = decoded
    }

    func frame(action: NeoLemmixAction, direction: NeoLemmixDirection,
               animationFrame: Int, traits: Set<NeoLemmixTrait>) -> NeoLemmixMobileSpriteFrame? {
        guard let name = Self.animationName(action), let animation = animations[name] else { return nil }
        let index = Self.frameIndex(action: action, frame: animationFrame,
                                    count: animation.frameCount, loopFrame: animation.loopFrame)
        let traitKey = traits.map(\.rawValue).sorted().joined(separator: ",")
        let key = "\(name)-\(direction.rawValue)-\(index)-\(traitKey)"
        if let cached = cache[key] { return cached }
        let column = direction == .left ? 0 : 1
        let crop = CGRect(x: column * animation.frameWidth, y: index * animation.frameHeight,
                          width: animation.frameWidth, height: animation.frameHeight)
        guard let cropped = animation.sheet.cropping(to: crop),
              var pixels = Self.rgba(cropped) else { return nil }
        recolour(&pixels, traits: traits)
        let foot = direction == .left ? animation.leftFoot : animation.rightFoot
        let frame = NeoLemmixMobileSpriteFrame(rgba: pixels, width: animation.frameWidth,
            height: animation.frameHeight, footX: Int(foot.x), footY: Int(foot.y))
        if cache.count < 4096 { cache[key] = frame }
        return frame
    }

    private func recolour(_ pixels: inout [UInt8], traits: Set<NeoLemmixTrait>) {
        for offset in stride(from: 0, to: pixels.count, by: 4) where pixels[offset + 3] > 0 {
            let source = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            var target = recolouring[source] ?? source
            if !traits.isDisjoint(with: [.slider, .climber, .swimmer, .floater, .glider, .disarmer]) {
                target = athleteColours[target] ?? target
            }
            if traits.contains(.zombie) { target = zombieColours[target] ?? target }
            if traits.contains(.neutral) { target = neutralColours[target] ?? target }
            pixels[offset] = UInt8((target >> 16) & 0xff)
            pixels[offset + 1] = UInt8((target >> 8) & 0xff)
            pixels[offset + 2] = UInt8(target & 0xff)
        }
    }

    private static func rgba(_ image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: &pixels, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0..<3 {
                pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha))
            }
        }
        return pixels
    }

    private static func namedColors(_ section: NxlvSection?) -> [String: UInt32] {
        guard let section else { return [:] }
        var result: [String: UInt32] = [:]
        for line in section.lineRecords {
            if let colour = parseColour(line.value) { result[line.keyword.lowercased()] = colour }
        }
        return result
    }

    private static func shades(_ section: NxlvSection?) -> [UInt32: UInt32] {
        var result: [UInt32: UInt32] = [:]
        for shade in section?.allSections("shade") ?? [] {
            guard let primary = shade.trimmedLine("primary").flatMap(parseColour) else { continue }
            for line in shade.lineRecords where line.keyword.caseInsensitiveCompare("alt") == .orderedSame {
                if let alternate = parseColour(line.value) { result[alternate] = primary }
            }
        }
        return result
    }

    private static func stateColours(_ section: NxlvSection?, name: String,
                                      base: [UInt32: UInt32], shades: [UInt32: UInt32]) -> [UInt32: UInt32] {
        var result: [UInt32: UInt32] = [:]
        for state in section?.allSections(name) ?? [] {
            guard let from = state.trimmedLine("from").flatMap(parseColour),
                  let to = state.trimmedLine("to").flatMap(parseColour) else { continue }
            let themedFrom = base[from] ?? from
            let themedTo = base[to] ?? to
            result[themedFrom] = themedTo
            for (alternate, primary) in shades where primary == from {
                result[applyColorShift(to: themedFrom, primary: primary, alternate: alternate)] =
                    applyColorShift(to: themedTo, primary: primary, alternate: alternate)
            }
        }
        return result
    }

    /**
     * Applies NeoLemmix's HSV shade shift to a theme colour, including its per-channel rounding correction.
     */
    private static func applyColorShift(to base: UInt32, primary: UInt32, alternate: UInt32) -> UInt32 {
        let primaryHSV = hsv(primary)
        let alternateHSV = hsv(alternate)
        let hueShift = alternateHSV.h - primaryHSV.h
        let saturationShift = alternateHSV.s - primaryHSV.s
        let valueShift = alternateHSV.v - primaryHSV.v
        let firstPass = shifted(primary, hue: hueShift, saturation: saturationShift, value: valueShift)
        let redAdjustment = component(alternate, shift: 16) - component(firstPass, shift: 16)
        let greenAdjustment = component(alternate, shift: 8) - component(firstPass, shift: 8)
        let blueAdjustment = component(alternate, shift: 0) - component(firstPass, shift: 0)
        let shiftedBase = shifted(base, hue: hueShift, saturation: saturationShift, value: valueShift)
        return colour(clamp(component(shiftedBase, shift: 16) + redAdjustment),
                      clamp(component(shiftedBase, shift: 8) + greenAdjustment),
                      clamp(component(shiftedBase, shift: 0) + blueAdjustment))
    }

    private static func hsv(_ colour: UInt32) -> (h: Double, s: Double, v: Double) {
        let red = Double(component(colour, shift: 16)) / 255
        let green = Double(component(colour, shift: 8)) / 255
        let blue = Double(component(colour, shift: 0)) / 255
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

    private static func shifted(_ source: UInt32, hue hueShift: Double,
                                saturation saturationShift: Double, value valueShift: Double) -> UInt32 {
        let source = hsv(source)
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
        return colour(Int(((rgb.0 + match) * 255).rounded()),
                      Int(((rgb.1 + match) * 255).rounded()),
                      Int(((rgb.2 + match) * 255).rounded()))
    }

    private static func component(_ colour: UInt32, shift: UInt32) -> Int {
        Int((colour >> shift) & 0xff)
    }

    private static func clamp(_ value: Int) -> Int { min(255, max(0, value)) }

    private static func colour(_ red: Int, _ green: Int, _ blue: Int) -> UInt32 {
        UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
    }

    private static func parseColour(_ value: String) -> UInt32? {
        var token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.first == "x" || token.first == "X" { token.removeFirst() }
        guard token.count == 6 else { return nil }
        return UInt32(token, radix: 16)
    }

    private static func frameIndex(action: NeoLemmixAction, frame: Int, count: Int, loopFrame: Int?) -> Int {
        let frame = max(0, frame)
        if action == .jumping, count == 3 { return frame <= 5 ? 0 : (frame == 6 ? 1 : 2) }
        if let loopFrame, frame >= count { return min(count - 1, loopFrame + (frame - loopFrame) % max(1, count - loopFrame)) }
        return frame % count
    }

    private static func animationName(_ action: NeoLemmixAction) -> String? {
        NeoLemmixMobileSupport.animationName(for: action)
    }
}

private enum NeoLemmixMobileSpriteError: Error, LocalizedError {
    case missingTheme(String)
    case missingSpriteStyle(String)
    case missingAnimationMetadata
    case missingAnimation(String)

    var errorDescription: String? {
        switch self {
        case let .missingTheme(style): L10n.text("The NeoLemmix theme \(style) could not be loaded.")
        case let .missingSpriteStyle(style): L10n.text("The NeoLemmix lemming style \(style) could not be loaded.")
        case .missingAnimationMetadata: L10n.text("The NeoLemmix lemming style has no animation metadata.")
        case let .missingAnimation(name): L10n.text("The NeoLemmix lemming style has no \(name) animation.")
        }
    }
}
