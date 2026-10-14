import Foundation

public struct SequelIndexedImage: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]
    /// Packed RGBA, including alpha, in palette-index order.
    public let palette: [UInt8]

    public func rgba() -> [UInt8] {
        pixels.flatMap { value in
            let index = Int(value) * 4
            return Array(palette[index..<(index + 4)])
        }
    }
}

/// Native L2VG tiles, palette and object definitions. The raw container keeps
/// the animation sections available for the object interpreter.
public struct Lemmings2Style: Sendable {
    public struct Component: Sendable {
        public let interaction: Int
        public let positioningFlags: Int
        public let x: Int
        public let y: Int
        public let triggerFlags: Int
        public let solidity: Int
        public let graphics: Int
        public let graphicsFlags: Int
    }
    public struct Object: Sendable {
        public let type: Int
        public let parameters: [Int]
        public let sound: Int
        public let components: [Component]
    }
    public let container: Lemmings2Form
    public let palette: [UInt8]
    public let tiles: [[UInt8]]
    public let objects: [Object]

    /// Decode a regular object animation. Frame offsets omit the length words
    /// in L2BF, so resolve them through a payload-offset table.
    public func animation(_ identifier: Int) throws -> [SequelIndexedImage] {
        let index = SequelBinary(try container.requiredSection("L2BI"))
        guard identifier >= 0, identifier < (try index.u16(0)) else {
            throw SequelDataError.invalid("Unknown L2 animation \(identifier).")
        }
        let animations = SequelBinary(try container.requiredSection("L2BA"))
        let offset = try index.u16(2 + identifier * 2) + 2
        let count = try animations.u16(offset)
        let columns = try animations.u16(offset + 2)
        let rows = try animations.u16(offset + 4)
        guard columns > 0, rows > 0, columns * rows <= 4096, count <= 1024,
            count * columns * rows * 128 <= 16 * 1024 * 1024 else {
            throw SequelDataError.invalid("Invalid L2 animation dimensions or frame count.")
        }
        let frames = SequelBinary(try container.requiredSection("L2BF"))
        var offsets: [Int: Int] = [:]
        var cursor = 2
        var logical = 0
        for _ in 0..<(try frames.u16(0)) {
            let size = try frames.u16(cursor)
            _ = try frames.slice(cursor + 2, size)
            offsets[logical] = cursor + 2
            logical += size
            cursor += size + 2
        }
        return try (0..<count).map { frame in
            let reference = try animations.u16(offset + 6 + frame * 2)
            guard let start = offsets[reference] else {
                throw SequelDataError.invalid("Unknown L2 frame offset \(reference).")
            }
            guard try frames.u16(start - 2) == columns * rows * 2 else {
                throw SequelDataError.invalid("L2 frame size does not match its dimensions.")
            }
            let width = columns * 16
            var pixels = Array(repeating: UInt8(0), count: width * rows * 8)
            for tile in 0..<(columns * rows) {
                let blockID = try frames.u16(start + tile * 2)
                guard tiles.indices.contains(blockID) else {
                    throw SequelDataError.invalid("L2 animation references missing tile \(blockID).")
                }
                for y in 0..<8 {
                    for x in 0..<16 {
                        pixels[(tile / columns * 8 + y) * width + tile % columns * 16 + x] = tiles[blockID][y * 16 + x]
                    }
                }
            }
            return SequelIndexedImage(width: width, height: rows * 8, pixels: pixels, palette: palette)
        }
    }

    public init(data: Data) throws {
        let form = try Lemmings2Form(data: data)
        guard form.type == "L2VG" else {
            throw SequelDataError.invalid("Expected an L2VG style, found \(form.type).")
        }
        container = form
        let colors = SequelBinary(try form.requiredSection("L2CL"))
        let channels = try colors.slice(2, 384)
        guard channels.allSatisfy({ $0 <= 63 }) else {
            throw SequelDataError.invalid("L2CL contains an invalid six-bit colour.")
        }
        var rgba = Array(repeating: UInt8(0), count: 1024)
        for index in 0..<128 {
            for channel in 0..<3 {
                rgba[index * 4 + channel] = UInt8(Int(channels[index * 3 + channel]) * 255 / 63)
            }
            rgba[index * 4 + 3] = 255
        }
        palette = rgba
        let blocks = SequelBinary(try form.requiredSection("L2BL"))
        let count = try blocks.u16(0)
        guard blocks.count == 2 + count * 128 else {
            throw SequelDataError.invalid("L2BL tile count does not match its length.")
        }
        tiles = (0..<count).map { index in
            var pixels = Array(repeating: UInt8(0), count: 128)
            for source in 0..<128 {
                pixels[(source % 32) * 4 + source / 32] = blocks.bytes[2 + index * 128 + source]
            }
            return pixels
        }
        let definitions = SequelBinary(try form.requiredSection("L2OB"))
        let objectCount = try definitions.u16(0)
        var cursor = 2
        var result: [Object] = []
        for _ in 0..<objectCount {
            let header = SequelBinary(Data(try definitions.slice(cursor, 20)))
            let componentCount = try header.u16(0)
            cursor += 20
            var components: [Component] = []
            for _ in 0..<componentCount {
                let entry = SequelBinary(Data(try definitions.slice(cursor, 12)))
                components.append(Component(
                    interaction: Int(entry.bytes[0]), positioningFlags: Int(entry.bytes[1]),
                    x: Int(Int16(bitPattern: UInt16(try entry.u16(2)))),
                    y: Int(Int16(bitPattern: UInt16(try entry.u16(4)))),
                    triggerFlags: try entry.u16(7), solidity: Int(entry.bytes[9]),
                    graphics: Int(entry.bytes[10]), graphicsFlags: Int(entry.bytes[11])))
                cursor += 12
            }
            result.append(Object(type: try header.u16(2),
                parameters: try stride(from: 4, to: 18, by: 2).map { try header.u16($0) },
                sound: try header.u16(18), components: components))
        }
        guard cursor == definitions.count else {
            throw SequelDataError.invalid("L2OB object count does not match its length.")
        }
        objects = result
    }
}

public struct Lemmings2Terrain: Sendable {
    public let image: SequelIndexedImage
    /// Terrain only. Steel and object collision are not included yet.
    public let solid: [Bool]

    public init(level: Lemmings2Level, style: Lemmings2Style) throws {
        let columns = level.tileColumns
        let rows = 1600 / columns
        let width = columns * 16
        let height = rows * 8
        var pixels = Array(repeating: UInt8(0), count: width * height)
        var solid = Array(repeating: false, count: width * height)
        for row in 0..<rows {
            for column in 0..<columns {
                let record = (row + 2) * (columns + 2) + column + 1
                guard level.tiles.indices.contains(record) else {
                    throw SequelDataError.invalid("L2MP is too short for its tile arrangement.")
                }
                let tile = level.tiles[record]
                guard style.tiles.indices.contains(tile.identifier) else {
                    throw SequelDataError.invalid("L2MP references missing tile \(tile.identifier).")
                }
                let block = style.tiles[tile.identifier]
                for y in 0..<8 {
                    for x in 0..<16 {
                        let position = (row * 8 + y) * width + column * 16 + x
                        let colour = block[y * 16 + x]
                        pixels[position] = colour
                        solid[position] = colour != 0 && tile.modifier & 0x4000 == 0
                    }
                }
            }
        }
        image = SequelIndexedImage(width: width, height: height, pixels: pixels, palette: style.palette)
        self.solid = solid
    }
}
