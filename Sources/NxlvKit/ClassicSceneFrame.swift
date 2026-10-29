import Foundation

/// Combines the current terrain mask with the original animated objects.
/// Collision triggers are independent from this visual composition.
public enum ClassicSceneFrame {
    public static func terrainRGBA(_ level: ClassicRenderedLevel, terrain: ClassicDOSTerrain) -> Data {
        Data(terrainPixels(level, solid: terrain.renderingSolidMask))
    }

    private static func terrainPixels(_ level: ClassicRenderedLevel, solid: [UInt8]) -> [UInt8] {
        let original = [UInt8](level.solidMask)
        var pixels = [UInt8](level.rgba)
        guard solid.count == original.count, pixels.count == solid.count * 4 else { return pixels }
        for index in solid.indices {
            let offset = index * 4
            if solid[index] == 0 && original[index] != 0 {
                pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
            } else if solid[index] != 0 && original[index] == 0 {
                // Construction pixels have no source texture.
                pixels[offset] = 240; pixels[offset + 1] = 208; pixels[offset + 2] = 96; pixels[offset + 3] = 255
            }
        }
        return pixels
    }

    public static func rgba(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation, terrain: Data? = nil) -> Data {
        let solid = simulation.terrain.renderingSolidMask
        let visualTerrain = terrain ?? Data(terrainPixels(level, solid: solid))
        guard solid.count == level.solidMask.count, visualTerrain.count == solid.count * 4 else { return level.rgba }
        let region = SceneRasterContext.region(width: level.width, height: level.height)
        var pixels = [UInt8](SceneRasterContext.crop(visualTerrain, width: level.width, height: level.height))
        var triggerIndex = 0
        for object in level.objects {
            let graphic = object.graphic
            let placement = object.placement
            let isArrow = graphic.triggerEffect == ClassicDOSObjectEffect.oneWayLeft.rawValue
                || graphic.triggerEffect == ClassicDOSObjectEffect.oneWayRight.rawValue
            let interactive = placement.slot < level.interactiveObjectSlotLimit
                && graphic.triggerEffect != 0
            let cooldown = interactive ? simulation.objectCooldown(at: triggerIndex) : 0
            if interactive { triggerIndex += 1 }
            guard !object.rgbaFrames.isEmpty else { continue }
            let frame = Self.frameIndex(of: object, cooldown: cooldown, tick: simulation.tickCount)
            let source = [UInt8](object.rgbaFrames[max(0, frame)])
            if graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue,
               !placement.draw.isUpsideDown, !placement.draw.onlyOverwrite {
                ClassicLiquidFill.draw(source: source, sourceWidth: graphic.width,
                    sourceHeight: graphic.height, x: placement.x, y: placement.y,
                    into: &pixels, width: level.width, height: level.height,
                    solid: solid, scale: 1, minimumBottom: placement.y + graphic.height)
            }
            for y in 0..<graphic.height {
                let targetY = placement.y + y
                guard (0..<level.height).contains(targetY) else { continue }
                let sourceY = placement.draw.isUpsideDown ? graphic.height - 1 - y : y
                for x in 0..<graphic.width {
                    let targetX = placement.x + x
                    guard (0..<level.width).contains(targetX) else { continue }
                    let src = (sourceY * graphic.width + x) * 4
                    guard source[src + 3] != 0 else { continue }
                    let index = targetY * level.width + targetX
                    if isArrow {
                        // Converted port levels can omit the terrain-only placement flag.
                        if visualTerrain[index * 4 + 3] == 0 { continue }
                    } else {
                        if placement.draw.noOverwrite && solid[index] != 0 { continue }
                        if placement.draw.onlyOverwrite && solid[index] == 0 { continue }
                    }
                    guard let dst = region.offset(x: targetX, y: targetY) else { continue }
                    pixels[dst] = source[src]; pixels[dst + 1] = source[src + 1]
                    pixels[dst + 2] = source[src + 2]; pixels[dst + 3] = source[src + 3]
                }
            }
        }
        return Data(pixels)
    }

    /// The animation frame an object shows on a tick. `cooldown` is the
    /// remaining trigger delay for objects that react to lemmings.
    public static func frameIndex(of object: ClassicRenderedObject, cooldown: Int, tick: Int) -> Int {
        let count = object.rgbaFrames.count
        guard count > 0 else { return 0 }
        let first = min(max(0, object.graphic.firstFrameIndex), count - 1)
        switch object.graphic.animationType {
        case .none: return first
        case .continuous: return (first + tick) % count
        case .onceAtStart:
            let elapsed = max(0, tick - ClassicDOSRules.entranceOpenTick)
            return min(first + elapsed, count - 1)
        case .triggered:
            return cooldown > 0 ? min(count - cooldown, count - 1) : first
        }
    }
}

/// Extends the liquid body down to terrain without changing collision masks.
enum ClassicLiquidFill {
    static func draw(source: [UInt8], sourceWidth: Int, sourceHeight: Int,
        x: Int, y: Int, into pixels: inout [UInt8], width: Int, height: Int,
        solid: [UInt8], scale: Int, minimumBottom: Int? = nil, visualTerrain: Data? = nil) {
        guard sourceWidth > 0, sourceHeight > 0,
              source.count == sourceWidth * sourceHeight * 4 else { return }
        // Use the dominant colour in the lowest opaque row, below the wave highlights.
        var bottom = sourceHeight - 1
        var colours: [UInt32: Int] = [:]
        while bottom >= 0 {
            for column in 0..<sourceWidth {
                let p = (bottom * sourceWidth + column) * 4
                guard source[p + 3] == 255 else { continue }
                let colour = UInt32(source[p]) << 16 | UInt32(source[p + 1]) << 8 | UInt32(source[p + 2])
                colours[colour, default: 0] += 1
            }
            if !colours.isEmpty { break }
            bottom -= 1
        }
        guard let colour = colours.keys.sorted().max(by: { colours[$0]! < colours[$1]! }) else { return }
        let left = max(0, x), right = min(width, x + sourceWidth)
        let top = max(0, y + bottom + 1)
        guard left < right, top < height else { return }
        // Macintosh liquid follows the rendered terrain's individual pixels, including
        // digging and construction. Collision cells remain untouched.
        func occupied(_ row: Int, _ column: Int) -> Bool {
            if let visualTerrain { return visualTerrain[(row * width + column) * 4 + 3] != 0 }
            return solid[(row / scale) * (width / scale) + column / scale] != 0
        }
        let region = SceneRasterContext.region(width: width, height: height)
        let clippedLeft = max(left, region.x), clippedRight = min(right, region.x + region.width)
        guard clippedLeft < clippedRight else { return }
        for column in clippedLeft..<clippedRight {
            for row in max(0, y)..<height {
                let terrain = occupied(row, column)
                // Short Macintosh wave sprites still represent the entire authored liquid tile.
                // A bridge inside that tile masks water; it must not truncate the body below it.
                if terrain {
                    if let minimumBottom, row < minimumBottom { continue }
                    break
                }
                // Beyond the authored tile, a floor still seals cavities underneath the pool.
                if let minimumBottom, row == minimumBottom, row > 0,
                   occupied(row - 1, column) { break }
                guard row >= top, let p = region.offset(x: column, y: row), pixels[p + 3] == 0 else { continue }
                pixels[p] = UInt8((colour >> 16) & 255)
                pixels[p + 1] = UInt8((colour >> 8) & 255)
                pixels[p + 2] = UInt8(colour & 255)
                pixels[p + 3] = 255
            }
        }
    }
}

/// A synchronous raster request, inherited only by work inside the scoped render.
/// Coordinates remain in authored level pixels; sprite-cache renders keep their own canvas.
public enum SceneRasterContext {
    public struct Viewport: Equatable, Sendable {
        public let levelWidth: Int
        public let levelHeight: Int
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
        public init(levelWidth: Int, levelHeight: Int, x: Int, y: Int, width: Int, height: Int) {
            self.levelWidth = levelWidth; self.levelHeight = levelHeight
            self.x = max(0, min(levelWidth - 1, x)); self.y = max(0, min(levelHeight - 1, y))
            self.width = max(1, min(levelWidth - self.x, width)); self.height = max(1, min(levelHeight - self.y, height))
        }
    }
    public struct Region: Sendable {
        public let x: Int, y: Int, width: Int, height: Int
        public var byteCount: Int { width * height * 4 }
        public func intersects(x: Int, y: Int, width: Int, height: Int) -> Bool {
            x < self.x + self.width && y < self.y + self.height && x + width > self.x && y + height > self.y
        }
        public func offset(x: Int, y: Int) -> Int? {
            guard x >= self.x, y >= self.y, x < self.x + width, y < self.y + height else { return nil }
            return ((y - self.y) * width + x - self.x) * 4
        }
    }
    public static let drawActors = TaskLocal<Bool>(wrappedValue: true)
    public static let request = TaskLocal<Viewport?>(wrappedValue: nil)
    public static var viewport: Viewport? { request.wrappedValue }
    public static func region(width: Int, height: Int) -> Region {
        if let viewport, viewport.levelWidth > 0, viewport.levelHeight > 0,
           width % viewport.levelWidth == 0, height % viewport.levelHeight == 0,
           width / viewport.levelWidth == height / viewport.levelHeight {
            let scale = width / viewport.levelWidth
            if scale == 1 || scale == 2 {
                return Region(x: viewport.x * scale, y: viewport.y * scale,
                    width: viewport.width * scale, height: viewport.height * scale)
            }
        }
        return Region(x: 0, y: 0, width: width, height: height)
    }
    public static func doubled(byteCount: Int, width: Int, height: Int) -> Bool {
        byteCount == region(width: width * 2, height: height * 2).byteCount
    }
    public static func crop(_ rgba: Data, width: Int, height: Int) -> Data {
        let region = region(width: width, height: height)
        guard region.width != width || region.height != height else { return rgba }
        guard rgba.count == width * height * 4 else { return rgba }
        var result = Data(count: region.byteCount)
        result.withUnsafeMutableBytes { destination in
            rgba.withUnsafeBytes { source in
                for y in 0..<region.height {
                    destination.baseAddress!.advanced(by: y * region.width * 4).copyMemory(
                        from: source.baseAddress!.advanced(by: ((region.y + y) * width + region.x) * 4),
                        byteCount: region.width * 4)
                }
            }
        }
        return result
    }
    public static func crop(_ rgba: [UInt8], width: Int, height: Int) -> [UInt8] {
        let region = region(width: width, height: height)
        guard region.width != width || region.height != height else { return rgba }
        guard rgba.count == width * height * 4 else { return rgba }
        var result = [UInt8](repeating: 0, count: region.byteCount)
        result.withUnsafeMutableBufferPointer { destination in
            rgba.withUnsafeBufferPointer { source in
                for y in 0..<region.height {
                    destination.baseAddress!.advanced(by: y * region.width * 4).update(
                        from: source.baseAddress!.advanced(by: ((region.y + y) * width + region.x) * 4), count: region.width * 4)
                }
            }
        }
        return result
    }
}
