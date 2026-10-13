import Foundation
import NxlvKit

/**
 * Draws the native Chronicles scene and animated lemmings into an RGBA frame.
 */
public struct Lemmings3MobileSceneRenderer: Sendable {
    public struct CreatureBank: Sendable {
        public let animations: [Lemmings3Sprites.Animation]
        public let palette: [UInt8]

        public init(animations: [Lemmings3Sprites.Animation], palette: [UInt8]) {
            self.animations = animations
            self.palette = palette
        }
    }

    private let scene: Lemmings3Scene
    private let palette: [UInt8]
    private let animations: [Lemmings3Sprites.Animation]
    private let brickPixels: [UInt8]
    private let toolFrames: [Int: SequelIndexedImage]
    private let creatureBanks: [Lemmings3Runtime.Creature.Kind: CreatureBank]

    public init(scene: Lemmings3Scene, style: Lemmings3Style,
                sprites: Lemmings3Sprites, palette: [UInt8],
                creatureBanks: [Lemmings3Runtime.Creature.Kind: CreatureBank] = [:]) throws {
        guard palette.count == 1024 else { throw MobileSessionError.invalidFrame }
        self.scene = scene
        self.palette = palette
        animations = sprites.animations
        self.creatureBanks = creatureBanks
        brickPixels = try style.constructionTile().pixels
        toolFrames = try Dictionary(uniqueKeysWithValues: Lemmings3Runtime.Tool.allCases.map { tool in
            (tool.rawValue, try style.permanent.image(object: tool.sourceIdentifier, palette: style.palette))
        })
    }

    public func render(_ runtime: Lemmings3Runtime, highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        let width = scene.image.width
        let height = scene.image.height
        guard width > 0, height > 0, width <= Int.max / height,
              scene.image.pixels.count == width * height else { throw MobileSessionError.invalidFrame }
        var pixels = scene.background.pixels
        for index in pixels.indices where scene.image.pixels[index] != scene.background.pixels[index] {
            pixels[index] = scene.image.pixels[index]
        }
        for (index, filled) in runtime.terrainEdits where pixels.indices.contains(index) {
            pixels[index] = filled
                ? brickPixels[(index / width % 8) * 8 + index % width % 8]
                : scene.background.pixels[index]
        }
        var rgba = Self.expand(pixels, palette: palette)
        for pickup in runtime.pickups where pickup.quantity > 0 {
            guard let frame = toolFrames[pickup.tool.rawValue] else { continue }
            Self.composite(frame.pixels, frameWidth: frame.width, frameHeight: frame.height,
                           palette: frame.palette, x: pickup.x, y: pickup.y,
                           width: width, height: height, into: &rgba)
        }
        for explosive in runtime.explosives {
            guard let frame = toolFrames[explosive.tool.rawValue] else { continue }
            Self.composite(frame.pixels, frameWidth: frame.width, frameHeight: frame.height,
                           palette: frame.palette, x: explosive.x - 4, y: explosive.y - 7,
                           width: width, height: height, into: &rgba)
        }
        for creature in runtime.creatures where creature.alive {
            guard let bank = creatureBanks[creature.kind] else { continue }
            let animationIndex = creature.direction > 0 ? 0 : 1
            guard bank.animations.indices.contains(animationIndex) else { continue }
            let animation = bank.animations[animationIndex]
            guard !animation.frames.isEmpty else { continue }
            let frame = animation.frames[(creature.age / 3) % animation.frames.count]
            Self.composite(frame, animation: animation, palette: bank.palette,
                           x: creature.x - animation.width / 2,
                           y: creature.y - animation.height,
                           width: width, height: height, into: &rgba)
        }
        for lemming in runtime.lemmings where lemming.active {
            let animationIndex = lemming.direction > 0 ? 0 : 1
            guard animations.indices.contains(animationIndex),
                  !animations[animationIndex].frames.isEmpty else { continue }
            let animation = animations[animationIndex]
            let frame = animation.frames[(lemming.state == .blocking ? 0 : lemming.age) % animation.frames.count]
            Self.composite(frame, animation: animation, palette: palette,
                           x: lemming.x - animation.width / 2,
                           y: lemming.y - animation.height, width: width, height: height, into: &rgba)
        }
        if let highlight, let lemming = runtime.lemmings.first(where: { $0.id == highlight.id && $0.active }) {
            Self.drawMarker(x: lemming.x, y: lemming.y - 12, width: width, height: height, into: &rgba)
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(rgba))
    }

    private static func expand(_ pixels: [UInt8], palette: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: pixels.count * 4)
        for (index, colour) in pixels.enumerated() {
            let source = Int(colour) * 4
            result[index * 4] = palette[source]
            result[index * 4 + 1] = palette[source + 1]
            result[index * 4 + 2] = palette[source + 2]
            result[index * 4 + 3] = 255
        }
        return result
    }

    static func composite(_ frame: Lemmings3Sprites.Frame, animation: Lemmings3Sprites.Animation,
                          palette: [UInt8],
                          x: Int, y: Int, width: Int, height: Int, into rgba: inout [UInt8]) {
        composite(frame.pixels, opaque: frame.opaque, frameWidth: animation.width,
                  frameHeight: animation.height, palette: palette, x: x, y: y,
                  width: width, height: height, into: &rgba)
    }

    static func composite(_ pixels: [UInt8], opaque: [Bool], frameWidth: Int, frameHeight: Int,
                          palette: [UInt8], x: Int, y: Int,
                          width: Int, height: Int, into rgba: inout [UInt8]) {
        guard pixels.count == frameWidth * frameHeight,
              opaque.count == pixels.count, palette.count == 1024 else { return }
        for sourceY in 0..<frameHeight {
            let targetY = y + sourceY
            guard (0..<height).contains(targetY) else { continue }
            for sourceX in 0..<frameWidth {
                let source = sourceY * frameWidth + sourceX
                guard opaque[source] else { continue }
                let targetX = x + sourceX
                guard (0..<width).contains(targetX) else { continue }
                let colour = Int(pixels[source]) * 4
                let target = (targetY * width + targetX) * 4
                rgba[target] = palette[colour]
                rgba[target + 1] = palette[colour + 1]
                rgba[target + 2] = palette[colour + 2]
                rgba[target + 3] = 255
            }
        }
    }

    private static func composite(_ pixels: [UInt8], frameWidth: Int, frameHeight: Int,
                                  palette: [UInt8], x: Int, y: Int,
                                  width: Int, height: Int, into rgba: inout [UInt8]) {
        guard pixels.count == frameWidth * frameHeight, palette.count == 1024 else { return }
        for sourceY in 0..<frameHeight {
            let targetY = y + sourceY
            guard (0..<height).contains(targetY) else { continue }
            for sourceX in 0..<frameWidth {
                let colour = pixels[sourceY * frameWidth + sourceX]
                guard colour != 255 else { continue }
                let targetX = x + sourceX
                guard (0..<width).contains(targetX) else { continue }
                let source = Int(colour) * 4
                let target = (targetY * width + targetX) * 4
                rgba[target] = palette[source]
                rgba[target + 1] = palette[source + 1]
                rgba[target + 2] = palette[source + 2]
                rgba[target + 3] = 255
            }
        }
    }

    private static func drawMarker(x: Int, y: Int, width: Int, height: Int, into rgba: inout [UInt8]) {
        for offset in -2...2 {
            for point in [(x + offset, y - 2), (x + offset, y + 2), (x - 2, y + offset), (x + 2, y + offset)] {
                guard (0..<width).contains(point.0), (0..<height).contains(point.1) else { continue }
                let target = (point.1 * width + point.0) * 4
                rgba[target] = 255; rgba[target + 1] = 220; rgba[target + 2] = 48; rgba[target + 3] = 255
            }
        }
    }
}
