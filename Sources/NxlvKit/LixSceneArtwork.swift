import CoreGraphics
import Foundation
import ImageIO

/**
 * Presents CC0 Lix scene pixels over Classic geometry without changing its simulation.
 */
public struct LixSceneArtwork: Sendable {
    public enum Theme: String, CaseIterable, Sendable {
        case brick, earth, wood
    }

    public struct Frame: Sendable {
        public let width: Int
        public let height: Int
        public let pixelScale: Int
        public let rgba: Data
    }

    public enum DecodeError: Error, LocalizedError {
        case invalidImage, invalidDefinition, unsafeFile

        public var errorDescription: String? {
            switch self {
            case .invalidImage: "The Lix scene image is invalid."
            case .invalidDefinition: "The Lix scene definition is invalid."
            case .unsafeFile: "The Lix scene file is unavailable. Reinstall this build."
            }
        }
    }

    public struct Pixels: Sendable {
        public let width: Int, height: Int
        public let rgba: [UInt8]

        func crop(x: Int, y: Int, width: Int, height: Int) throws -> Pixels {
            guard x >= 0, y >= 0, width > 0, height > 0,
                  width <= self.width, height <= self.height,
                  x <= self.width - width, y <= self.height - height else {
                throw DecodeError.invalidImage
            }
            var result = [UInt8]()
            result.reserveCapacity(width * height * 4)
            for row in y..<(y + height) {
                let start = (row * self.width + x) * 4
                result.append(contentsOf: rgba[start..<(start + width * 4)])
            }
            return Pixels(width: width, height: height, rgba: result)
        }
    }

    public struct Area: Sendable, Equatable {
        var x: Int, y: Int, width: Int, height: Int
        public var centreX: Int { x + width / 2 }
        public var centreY: Int { y + height / 2 }
    }

    public enum Kind { case hatch, goal, water, fire, trap }

    public struct Gadget: Sendable {
        public let rows: [[Pixels]]
        public let trigger: Area
        public let openingFrame: Int
        public var first: Pixels { rows[0][0] }
    }

    public let terrain: [Theme: Pixels]
    public let steel: Pixels
    public let hatches: [Theme: Gadget]
    public let goals: [Theme: Gadget]
    let water: Gadget
    let waterBody: Pixels
    let fire: Gadget
    let trap: Gadget

    public init(directory: URL) throws {
        let directory = directory.standardizedFileURL
        try self.init(read: { relative in
            let url = directory.appendingPathComponent("assets/" + relative)
            var current = url
            while true {
                let values = try current.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw DecodeError.unsafeFile }
                if current.path == directory.path { break }
                current.deleteLastPathComponent()
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            let limit = relative.hasSuffix(".png") ? 2_000_000 : 8_192
            guard values.isRegularFile == true, let count = values.fileSize,
                  count > 0, count <= limit else { throw DecodeError.unsafeFile }
            return try Data(contentsOf: url)
        })
    }

    init(read: (String) throws -> Data) throws {
        func image(_ name: String) throws -> Pixels { try Self.decode(read("images/" + name)) }
        func gadget(_ name: String, _ kind: Kind, definition: Bool = false) throws -> Gadget {
            let data = try read("images/" + name + ".png")
            let sidecar = definition ? try read("images/" + name + ".txt") : Data()
            return try Self.decodeGadget(data, kind: kind, definition: sidecar)
        }
        let textures: [Theme: Pixels] = [
            .brick: try image("matt/bricks/03.png"),
            .earth: try image("matt/earth/00.png").crop(x: 24, y: 20, width: 32, height: 32),
            .wood: try image("matt/goldmine/plank.png"),
        ]
        let steel = try image("matt/steel/32x32.S.png")
        // Source silhouettes must not create holes in the engine's solid mask.
        guard (Array(textures.values) + [steel]).allSatisfy({ image in
            stride(from: 3, to: image.rgba.count, by: 4).allSatisfy { image.rgba[$0] == 255 }
        }) else { throw DecodeError.invalidImage }
        self.terrain = textures
        self.steel = steel
        hatches = [
            .brick: try gadget("matt/bricks/Hatch.H", .hatch, definition: true),
            .earth: try gadget("matt/earth/Hatch.H", .hatch, definition: true),
            .wood: try gadget("matt/goldmine/Hatch.H", .hatch, definition: true),
        ]
        goals = [
            .brick: try gadget("matt/bricks/Goal.G", .goal),
            .earth: try gadget("matt/earth/Goal.G", .goal, definition: true),
            .wood: try gadget("matt/goldmine/Goal.G", .goal),
        ]
        water = try gadget("simon/water.W", .water)
        waterBody = try image("simon/water_main.W.png")
        fire = try gadget("proxima/flame.F", .fire, definition: true)
        trap = try gadget("geoo/construction/squisher.T", .trap, definition: true)
    }

    /**
     * Returns native Lix detail at twice the simulation coordinates, or a sampled 1× frame.
     */
    public func frame(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation,
                      theme: Theme = .brick, pixelScale: Int = 2) -> Frame {
        guard (1...4_096).contains(level.width), (1...1_024).contains(level.height),
              simulation.terrain.width == level.width, simulation.terrain.height == level.height,
              simulation.terrain.solidMask.count == level.width * level.height,
              simulation.terrain.steelMask.count == level.width * level.height,
              let texture = terrain[theme] else {
            return Frame(width: 1, height: 1, pixelScale: 1, rgba: Data([0, 0, 0, 0]))
        }
        let width = level.width * 2, height = level.height * 2
        let solid = [UInt8](simulation.terrain.solidMask), protected = [UInt8](simulation.terrain.steelMask)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let cell = (y / 2) * level.width + x / 2
                guard solid[cell] != 0 else { continue }
                let source = protected[cell] != 0 ? steel : texture
                let offset = ((y % source.height) * source.width + x % source.width) * 4
                let target = (y * width + x) * 4
                pixels[target] = source.rgba[offset]
                pixels[target + 1] = source.rgba[offset + 1]
                pixels[target + 2] = source.rgba[offset + 2]
                pixels[target + 3] = 255
            }
        }
        var triggerIndex = 0, entranceIndex = 0
        for object in level.objects {
            let interactive = object.placement.slot < level.interactiveObjectSlotLimit
                && object.graphic.triggerEffect != 0
            let trigger = interactive && simulation.configuration.triggers.indices.contains(triggerIndex)
                ? simulation.configuration.triggers[triggerIndex] : nil
            let cooldown = interactive ? simulation.objectCooldown(at: triggerIndex) : 0
            if interactive { triggerIndex += 1 }
            var selected: Gadget?
            var row = 0, index = 0
            var anchor: ClassicDOSPoint?
            if object.placement.id == 1 {
                selected = hatches[theme]
                if simulation.configuration.entrances.indices.contains(entranceIndex) {
                    anchor = simulation.configuration.entrances[entranceIndex]
                    index = max(0, simulation.tickCount - ClassicDOSRules.entranceOpenTick
                        + (selected?.openingFrame ?? 1))
                } else if Self.safe(object.placement.x), Self.safe(object.placement.y) {
                    let mechanics = simulation.configuration.mechanics
                    let x = mechanics == .golems
                        ? object.placement.sourceX ?? object.placement.x : object.placement.x
                    if Self.safe(x) {
                        anchor = ClassicDOSPoint(x: x + mechanics.hatchOffsetX, y: object.placement.y + 14)
                    }
                }
                entranceIndex += 1
            } else {
                switch ClassicDOSObjectEffect(rawValue: object.graphic.triggerEffect) {
                case .exit: selected = goals[theme]
                case .water: selected = water
                case .fire: selected = fire
                case .triggeredTrap:
                    selected = trap
                    if cooldown > 0, trap.rows.count > 1 {
                        row = 1
                        let count = max(1, object.rgbaFrames.count)
                        index = max(0, count - cooldown) * trap.rows[1].count / count
                    } else { index = simulation.tickCount }
                default: break
                }
                if let trigger {
                    let bounds = trigger.bounds
                    guard Self.safe(bounds.x1), Self.safe(bounds.x2),
                          Self.safe(bounds.y1), Self.safe(bounds.y2) else { continue }
                    anchor = ClassicDOSPoint(x: bounds.x1 + (bounds.x2 - bounds.x1) / 2,
                                             y: bounds.y1 + (bounds.y2 - bounds.y1) / 2)
                }
            }
            guard let selected, let anchor, Self.safe(anchor.x), Self.safe(anchor.y) else {
                Self.drawOriginal(object, cooldown: cooldown, tick: simulation.tickCount,
                                  pixels: &pixels, width: width, height: height, solid: solid)
                continue
            }
            if object.placement.id != 1, object.graphic.triggerEffect != ClassicDOSObjectEffect.triggeredTrap.rawValue {
                index = simulation.tickCount
            }
            let sequence = selected.rows[row]
            let source: Pixels
            if object.placement.id == 1 {
                source = sequence[min(index, sequence.count - 1)]
            } else { source = sequence[((index % sequence.count) + sequence.count) % sequence.count] }
            let upsideDown = object.placement.draw.isUpsideDown
            let sourceY = upsideDown ? source.height - selected.trigger.centreY : selected.trigger.centreY
            var left = anchor.x * 2 - selected.trigger.centreX
            var top = anchor.y * 2 - sourceY
            if object.graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue, let trigger {
                left = trigger.bounds.x1 * 2
                let triggerTop = upsideDown
                    ? source.height - selected.trigger.y - selected.trigger.height : selected.trigger.y
                top = trigger.bounds.y1 * 2 - triggerTop
                let right = min(width, trigger.bounds.x2 * 2)
                guard left < right else { continue }
                for x in stride(from: left, to: right, by: source.width) {
                    Self.draw(source, x: x, y: top, upsideDown: upsideDown, right: right,
                              properties: object.placement.draw, pixels: &pixels,
                              width: width, height: height, solid: solid)
                }
                if !upsideDown && !object.placement.draw.onlyOverwrite {
                    fillWater(left: left, right: right, top: top,
                              bodyTop: top + source.height, pixels: &pixels,
                              width: width, height: height, solid: solid)
                }
            } else {
                Self.draw(source, x: left, y: top, upsideDown: upsideDown, right: width,
                          properties: object.placement.draw, pixels: &pixels,
                          width: width, height: height, solid: solid)
            }
        }
        if pixelScale == 1 {
            var sampled = [UInt8](repeating: 0, count: level.width * level.height * 4)
            for y in 0..<level.height { for x in 0..<level.width {
                let target = (y * level.width + x) * 4, source = (y * 2 * width + x * 2) * 4
                sampled[target] = pixels[source]; sampled[target + 1] = pixels[source + 1]
                sampled[target + 2] = pixels[source + 2]; sampled[target + 3] = pixels[source + 3]
            } }
            return Frame(width: level.width, height: level.height, pixelScale: 1, rgba: Data(sampled))
        }
        return Frame(width: width, height: height, pixelScale: 2, rgba: Data(pixels))
    }

    private static func safe(_ coordinate: Int) -> Bool { (-16_384...16_384).contains(coordinate) }

    private func fillWater(left: Int, right: Int, top: Int, bodyTop: Int, pixels: inout [UInt8],
                           width: Int, height: Int, solid: [UInt8]) {
        guard max(0, left) < min(width, right), max(0, top) < height else { return }
        for x in max(0, left)..<min(width, right) {
            for y in max(0, top)..<height {
                if solid[(y / 2) * (width / 2) + x / 2] != 0 { break }
                let target = (y * width + x) * 4
                guard y >= bodyTop, pixels[target + 3] == 0 else { continue }
                let source = (((y - bodyTop) % waterBody.height) * waterBody.width
                    + (x - left) % waterBody.width) * 4
                pixels.replaceSubrange(target..<(target + 4), with: waterBody.rgba[source..<(source + 4)])
            }
        }
    }

    private static func draw(_ source: Pixels, x: Int, y: Int, upsideDown: Bool, right: Int,
                             properties: ClassicDrawProperties, pixels: inout [UInt8],
                             width: Int, height: Int, solid: [UInt8]) {
        let left = max(0, x), end = min(width, right, x + source.width)
        let top = max(0, y), bottom = min(height, y + source.height)
        guard left < end, top < bottom else { return }
        for targetY in top..<bottom { for targetX in left..<end {
            let sourceY = upsideDown ? source.height - 1 - (targetY - y) : targetY - y
            let offset = (sourceY * source.width + targetX - x) * 4
            guard source.rgba[offset + 3] != 0 else { continue }
            let cell = (targetY / 2) * (width / 2) + targetX / 2
            if properties.noOverwrite && solid[cell] != 0 { continue }
            if properties.onlyOverwrite && solid[cell] == 0 { continue }
            let target = (targetY * width + targetX) * 4
            pixels.replaceSubrange(target..<(target + 4), with: source.rgba[offset..<(offset + 4)])
        } }
    }

    private static func drawOriginal(_ object: ClassicRenderedObject, cooldown: Int, tick: Int,
                                     pixels: inout [UInt8], width: Int, height: Int, solid: [UInt8]) {
        guard !object.rgbaFrames.isEmpty, safe(object.placement.x), safe(object.placement.y),
              (1...4_096).contains(object.graphic.width), (1...1_024).contains(object.graphic.height) else { return }
        let frame = ClassicSceneFrame.frameIndex(of: object, cooldown: cooldown, tick: tick)
        let bytes = [UInt8](object.rgbaFrames[frame])
        guard bytes.count == object.graphic.width * object.graphic.height * 4 else { return }
        var expanded = [UInt8](repeating: 0, count: bytes.count * 4)
        let expandedWidth = object.graphic.width * 2
        for y in 0..<(object.graphic.height * 2) { for x in 0..<expandedWidth {
            let source = ((y / 2) * object.graphic.width + x / 2) * 4
            let target = (y * expandedWidth + x) * 4
            expanded.replaceSubrange(target..<(target + 4), with: bytes[source..<(source + 4)])
        } }
        draw(Pixels(width: expandedWidth, height: object.graphic.height * 2, rgba: expanded),
             x: object.placement.x * 2, y: object.placement.y * 2,
             upsideDown: object.placement.draw.isUpsideDown, right: width,
             properties: object.placement.draw, pixels: &pixels, width: width, height: height, solid: solid)
    }

    static func decode(_ data: Data) throws -> Pixels {
        guard !data.isEmpty, data.count <= 2_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == "public.png", CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...4_096).contains(width), (1...4_096).contains(height),
              width * height <= 2_000_000,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw DecodeError.invalidImage }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DecodeError.invalidImage
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[offset + 3])
            if alpha > 0 && alpha < 255 {
                for channel in 0..<3 {
                    bytes[offset + channel] = UInt8(min(255, (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha))
                }
            }
            if bytes[offset] == 255 && bytes[offset + 1] == 0 && bytes[offset + 2] == 255 {
                bytes.replaceSubrange(offset..<(offset + 4), with: [0, 0, 0, 0])
            }
        }
        return Pixels(width: width, height: height, rgba: bytes)
    }

    public static func decodeGadget(_ data: Data, kind: Kind, definition: Data) throws -> Gadget {
        let sheet = try decode(data)
        guard definition.count <= 8_192, let text = String(data: definition, encoding: .utf8) else {
            throw DecodeError.invalidDefinition
        }
        func pixel(_ x: Int, _ y: Int) -> ArraySlice<UInt8> {
            let start = (y * sheet.width + x) * 4
            return sheet.rgba[start..<(start + 4)]
        }
        let grid = pixel(0, 0)
        var width = sheet.width, height = sheet.height, columns = 1, rowCount = 1
        if width > 1, height > 1, pixel(0, 1) == grid, pixel(1, 0) == grid, pixel(1, 1) != grid {
            let frameWidth = (2..<width).first { pixel($0, 1) == grid }.map { $0 - 1 } ?? width
            let frameHeight = (2..<height).first { pixel(1, $0) == grid }.map { $0 - 1 } ?? height
            columns = max(1, (width - 1) / (frameWidth + 1))
            rowCount = max(1, (height - 1) / (frameHeight + 1))
            if columns > 1 || rowCount > 1 { width = frameWidth; height = frameHeight }
        }
        guard columns * rowCount <= 128 else { throw DecodeError.invalidImage }
        var rows: [[Pixels]] = []
        for row in 0..<rowCount {
            var frames: [Pixels] = []
            for column in 0..<columns {
                let x = columns > 1 || rowCount > 1 ? 1 + column * (width + 1) : 0
                let y = columns > 1 || rowCount > 1 ? 1 + row * (height + 1) : 0
                if columns > 1 || rowCount > 1, pixel(x, y) == grid { break }
                frames.append(try sheet.crop(x: x, y: y, width: width, height: height))
            }
            guard !frames.isEmpty else { throw DecodeError.invalidImage }
            rows.append(frames)
        }
        var x = 0, y = 0, sizeX = 0, sizeY = 0, centreX = false, centreY = false
        switch kind {
        case .hatch: x = width / 2; y = max(20, height - 24)
        case .goal: x = width / 2; y = height - 2; sizeX = 12; sizeY = 12; centreX = true; centreY = true
        case .water: y = 20; sizeX = width; sizeY = max(0, height - 20)
        case .fire: sizeX = width; sizeY = height
        case .trap: x = width / 2; y = height * 4 / 5; sizeX = 4; sizeY = 6; centreX = true; centreY = true
        }
        var opening = 1
        let keys: Set<String> = ["TRIGGER_AREA_POSITION_ABSOLUTE_X", "TRIGGER_AREA_POSITION_ABSOLUTE_Y",
            "TRIGGER_AREA_POSITION_FROM_CENTER_X", "TRIGGER_AREA_POSITION_FROM_CENTER_Y",
            "TRIGGER_AREA_POSITION_FROM_BOTTOM_Y", "TRIGGER_AREA_SIZE_X", "TRIGGER_AREA_SIZE_Y", "HATCH_OPENING_FRAME"]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let first = fields.first, first.first == "#" else { continue }
            let key = String(first.dropFirst())
            guard keys.contains(key) else { continue }
            guard fields.count >= 2, let value = Int(fields[1]), (-4_096...4_096).contains(value) else {
                throw DecodeError.invalidDefinition
            }
            switch key {
            case "TRIGGER_AREA_POSITION_ABSOLUTE_X": x = value; centreX = false
            case "TRIGGER_AREA_POSITION_ABSOLUTE_Y": y = value; centreY = false
            case "TRIGGER_AREA_POSITION_FROM_CENTER_X": x = width / 2 + value; centreX = true
            case "TRIGGER_AREA_POSITION_FROM_CENTER_Y": y = height / 2 + value; centreY = true
            case "TRIGGER_AREA_POSITION_FROM_BOTTOM_Y": y = height - 2 + value; centreY = true
            case "TRIGGER_AREA_SIZE_X": sizeX = max(0, value)
            case "TRIGGER_AREA_SIZE_Y": sizeY = max(0, value)
            case "HATCH_OPENING_FRAME":
                guard value >= 0 else { throw DecodeError.invalidDefinition }
                opening = value
            default: break
            }
        }
        // Upstream fire hazards extend twelve source pixels down for foot checks.
        if kind == .fire { if centreY { y += 6 }; sizeY += 12 }
        return Gadget(rows: rows, trigger: Area(x: x - (centreX ? sizeX / 2 : 0),
            y: y - (centreY ? sizeY / 2 : 0), width: sizeX, height: sizeY), openingFrame: opening)
    }
}
