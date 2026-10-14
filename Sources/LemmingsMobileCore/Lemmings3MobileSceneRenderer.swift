import Foundation
import NxlvKit

/**
 * Draws the native Chronicles scene and animated lemmings into an RGBA frame.
 */
public struct Lemmings3MobileSceneRenderer: Sendable {
    public static let directionAnimationIndex = 91

    /** One indexed native trap animation at its level position. */
    public struct AnimatedObject: Sendable {
        /** One decoded trap frame with its source palette. */
        public struct Frame: Sendable {
            public let width: Int
            public let height: Int
            public let pixels: [UInt8]
            public let palette: [UInt8]

            /** Creates a frame from a native indexed image. */
            public init(width: Int, height: Int, pixels: [UInt8], palette: [UInt8]) throws {
                guard width > 0, height > 0, width <= Int.max / height,
                      pixels.count == width * height, palette.count == 1024 else {
                    throw MobileSessionError.invalidFrame
                }
                self.width = width
                self.height = height
                self.pixels = pixels
                self.palette = palette
            }
        }

        public let id: Int
        public let x: Int
        public let y: Int
        public let frames: [Frame]

        /** Creates an animated object keyed by its placement index. */
        public init(id: Int, x: Int, y: Int, frames: [Frame]) {
            self.id = id
            self.x = x
            self.y = y
            self.frames = frames
        }
    }

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
    private let animatedObjects: [Int: AnimatedObject]

    public init(scene: Lemmings3Scene, style: Lemmings3Style,
                sprites: Lemmings3Sprites, palette: [UInt8],
                creatureBanks: [Lemmings3Runtime.Creature.Kind: CreatureBank] = [:],
                animatedObjects: [AnimatedObject] = []) throws {
        guard palette.count == 1024 else { throw MobileSessionError.invalidFrame }
        self.scene = scene
        self.palette = palette
        animations = sprites.animations
        self.creatureBanks = creatureBanks
        self.animatedObjects = Dictionary(uniqueKeysWithValues: animatedObjects.map { ($0.id, $0) })
        brickPixels = try style.constructionTile().pixels
        toolFrames = try Dictionary(uniqueKeysWithValues: Lemmings3Runtime.Tool.allCases.map { tool in
            (tool.rawValue, try style.permanent.image(object: tool.sourceIdentifier, palette: style.palette))
        })
    }

    static func panelFrame(directory: URL, tribe: Int) throws -> MobilePixelFrame {
        let graphics = directory.appendingPathComponent("GRAPHICS")
        let raw = try Data(contentsOf: graphics.appendingPathComponent(String(format: "PAN%03d.RAW", tribe)))
        let colours = try Data(contentsOf: graphics.appendingPathComponent(String(format: "TRIBE%03d.PAL", tribe)))
        return try decodePanel(raw: raw, colours: colours)
    }

    static func decodePanel(raw: Data, colours: Data) throws -> MobilePixelFrame {
        guard raw.count == 12_800, colours.count == 96 else { throw MobileSessionError.invalidFrame }
        var palette = [UInt8](repeating: 0, count: 1024)
        for index in 0..<32 {
            for channel in 0..<3 {
                palette[index * 4 + channel] = UInt8(Int(colours[index * 3 + channel] & 63) * 255 / 63)
            }
            palette[index * 4 + 3] = 255
        }
        var pixels = [UInt8](repeating: 0, count: 320 * 40)
        for y in 0..<40 {
            for x in 0..<320 {
                pixels[y * 320 + x] = raw[(x % 4) * 3_200 + y * 80 + x / 4]
            }
        }
        return try MobilePixelFrame(width: 320, height: 40,
                                    rgba: Data(expand(pixels, palette: palette)))
    }

    /** Returns the eight native arrow frames for the tool direction picker. */
    public func directionPickerFrames() throws -> [MobilePixelFrame] {
        guard animations.indices.contains(Self.directionAnimationIndex) else {
            throw MobileSessionError.invalidFrame
        }
        let animation = animations[Self.directionAnimationIndex]
        guard animation.width == 16, animation.height == 16, animation.frames.count == 8 else {
            throw MobileSessionError.invalidFrame
        }
        return try animation.frames.map { frame in
            guard frame.pixels.count == animation.width * animation.height,
                  frame.opaque.count == frame.pixels.count else { throw MobileSessionError.invalidFrame }
            var rgba = Self.expand(frame.pixels, palette: palette)
            for index in frame.opaque.indices where !frame.opaque[index] {
                rgba.replaceSubrange((index * 4)..<(index * 4 + 4), with: [0, 0, 0, 0])
            }
            return try MobilePixelFrame(width: animation.width, height: animation.height, rgba: Data(rgba))
        }
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
        for trap in runtime.configuration.traps {
            guard let object = animatedObjects[trap.id],
                  let frameIndex = Self.animatedFrameIndex(runtime.trapFrame(id: trap.id), count: object.frames.count),
                  object.frames.indices.contains(frameIndex) else { continue }
            let frame = object.frames[frameIndex]
            Self.composite(frame, x: object.x, y: object.y, width: width, height: height, into: &rgba)
        }
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
        for fireball in runtime.fireballs {
            Self.compositeFireball(x: fireball.x - 3, y: fireball.y - 2,
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

    static func animatedFrameIndex(_ frame: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(count - 1, max(0, frame))
    }

    static func composite(_ frame: AnimatedObject.Frame, x: Int, y: Int,
                          width: Int, height: Int, into rgba: inout [UInt8]) {
        composite(frame.pixels, frameWidth: frame.width, frameHeight: frame.height,
                  palette: frame.palette, x: x, y: y, width: width, height: height, into: &rgba)
    }

    static func compositeFireball(x: Int, y: Int, width: Int, height: Int, into rgba: inout [UInt8]) {
        let rows = [".boob.", "boywyo", "boyyob", "..bb.."]
        guard width > 0, height > 0, width <= Int.max / height else { return }
        let pixelCount = width * height
        guard pixelCount <= Int.max / 4, rgba.count == pixelCount * 4 else { return }
        for (offsetY, row) in rows.enumerated() {
            let targetY = y + offsetY
            guard (0..<height).contains(targetY) else { continue }
            for (offsetX, pixel) in row.enumerated() {
                let targetX = x + offsetX
                guard (0..<width).contains(targetX) else { continue }
                let colour: [UInt8]
                switch pixel {
                case "b": colour = [0, 120, 184, 255]
                case "o": colour = [0, 230, 255, 255]
                case "y": colour = [142, 255, 255, 255]
                case "w": colour = [255, 255, 238, 255]
                default: continue
                }
                let index = (targetY * width + targetX) * 4
                rgba[index..<index + 4] = colour[...]
            }
        }
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
