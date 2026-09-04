import Foundation

/// Chronicles object graphics. OBJ describes dimensions and FRL references;
/// FRL assembles 8x2 blocks from BLK. Unknown object fields remain available.
public struct Lemmings3StyleBank: Sendable {
    public struct Object: Sendable {
        public let identifier: Int
        public let flags: Int
        public let frameOffset: Int
        public let attributesOffset: Int
        public let columns: Int
        public let rows: Int
        public let frameCount: Int
        public let rawRecord: Data
        public var animationStartFrame: Int { Int(rawRecord[11]) }
        public var animationFrameDelay: Int { Int(rawRecord[12]) & 0x7f }
        public var animationMode: Int { (Int(rawRecord[12]) >> 7 | Int(rawRecord[13]) << 1) & 3 }
        public var animationCyclePause: Int { Int(rawRecord[13]) >> 1 }
    }
    public let objects: [Int: Object]
    public let blocks: [[UInt8]]
    private let frameData: Data

    public init(objects: Data, frames: Data, blocks: Data) throws {
        let definitions = SequelBinary(objects)
        guard definitions.count.isMultiple(of: 15), blocks.count.isMultiple(of: 16) else {
            throw SequelDataError.invalid("Partial Chronicles object or graphics block record.")
        }
        var result: [Int: Object] = [:]
        for offset in stride(from: 0, to: definitions.count, by: 15) {
            let record = try definitions.slice(offset, 15)
            let identifier = try definitions.u16(offset)
            guard result[identifier] == nil else {
                throw SequelDataError.invalid("Duplicate Chronicles object ID \(identifier).")
            }
            result[identifier] = Object(identifier: identifier,
                flags: try definitions.u16(offset + 2), frameOffset: try definitions.u16(offset + 4),
                attributesOffset: try definitions.u16(offset + 6),
                columns: Int(record[8]), rows: Int(record[9]), frameCount: Int(record[10]), rawRecord: Data(record))
        }
        self.objects = result
        frameData = frames
        let bytes = Array(blocks)
        self.blocks = stride(from: 0, to: bytes.count, by: 16).map { offset in
            var pixels = Array(repeating: UInt8(0), count: 16)
            for index in 0..<16 { pixels[(index % 4) * 4 + index / 4] = bytes[offset + index] }
            return pixels
        }
    }

    /// Native 8x2-cell attributes. The second OBJ pointer addresses tag data,
    /// not graphics. A zero pointer uses the object's uniform flags.
    public func attributes(object identifier: Int) throws -> [UInt16] {
        guard let object = objects[identifier], object.columns > 0, object.rows > 0 else {
            throw SequelDataError.invalid("Invalid Chronicles attribute object.")
        }
        let size = object.columns * object.rows
        var result = [UInt16](repeating: UInt16(object.flags), count: size)
        guard object.attributesOffset != 0 else { return result }
        let reader = SequelBinary(frameData)
        let offset = object.attributesOffset
        let kind = try reader.slice(offset, 1)[0]
        let count = try reader.u16(offset + 1)
        guard (kind == 0 || kind == 1), count <= size else {
            throw SequelDataError.invalid("Invalid Chronicles attribute grid.")
        }
        var cursor = kind == 0 ? try reader.u16(offset + 3) : offset + 3
        for index in 0..<count {
            var position = index
            if kind == 0 {
                let x = Int(try reader.slice(cursor, 1)[0])
                let y = Int(try reader.slice(cursor + 1, 1)[0])
                guard x < object.columns, y < object.rows else {
                    throw SequelDataError.invalid("Chronicles attribute cell is outside its object.")
                }
                position = y * object.columns + x; cursor += 2
            }
            result[position] = UInt16(try reader.u16(cursor)); cursor += 2
        }
        return result
    }

    /// Each sparse frame is a delta. Unwritten blocks retain their previous
    /// values, so compose frames zero through the requested frame.
    public func image(object identifier: Int, frame: Int = 0, palette: [UInt8]) throws -> SequelIndexedImage {
        guard let object = objects[identifier], frame >= 0, frame < object.frameCount,
            object.columns > 0, object.rows > 0, palette.count == 1024 else {
            throw SequelDataError.invalid("Invalid Chronicles object, frame, dimensions, or palette.")
        }
        let reader = SequelBinary(frameData)
        let width = object.columns * 8
        let height = object.rows * 2
        // Index 255 is reserved here for unwritten pixels, not a colour from BLK.
        var pixels = Array(repeating: UInt8(255), count: width * height)
        for current in 0...frame {
            let offset = try reader.u16(object.frameOffset + current * 2)
            let kind = try reader.slice(offset, 1)[0]
            let count = try reader.u16(offset + 1)
            guard kind == 0 || kind == 1 else {
                throw SequelDataError.invalid("Unknown Chronicles frame encoding \(kind).")
            }
            var cursor = kind == 0 ? try reader.u16(offset + 3) : offset + 3
            guard count <= object.columns * object.rows else {
                throw SequelDataError.invalid("Chronicles frame exceeds its dimensions.")
            }
            for index in 0..<count {
                let x: Int
                let y: Int
                if kind == 0 {
                    let position = try reader.slice(cursor, 2)
                    x = Int(position[0])
                    y = Int(position[1])
                    cursor += 2
                } else {
                    x = index % object.columns
                    y = index / object.columns
                }
                let block = try reader.u16(cursor)
                cursor += 2
                guard x < object.columns, y < object.rows, blocks.indices.contains(block) else {
                    throw SequelDataError.invalid("Invalid Chronicles frame block or position.")
                }
                for py in 0..<2 {
                    for px in 0..<8 {
                        pixels[(y * 2 + py) * width + x * 8 + px] = blocks[block][py * 8 + px]
                    }
                }
            }
        }
        return SequelIndexedImage(width: width, height: height, pixels: pixels, palette: palette)
    }
}

public struct Lemmings3Style: Sendable {
    public let permanent: Lemmings3StyleBank
    public let temporary: Lemmings3StyleBank
    public let palette: [UInt8]
    public func constructionTile() throws -> SequelIndexedImage {
        let candidates = temporary.objects.values.filter { $0.columns == 1 && $0.rows == 4 && $0.flags == 0x2020 }
        guard candidates.count == 1, let tile = candidates.first else { throw SequelDataError.invalid("Missing or ambiguous Chronicles construction tile.") }
        return try temporary.image(object: tile.identifier, palette: palette)
    }

    public init(directory: URL, number: Int, lemmingStyle: Int? = nil) throws {
        func read(_ prefix: String, _ suffix: String) throws -> Data {
            try Data(contentsOf: directory.appendingPathComponent(String(format: "%@%03d.%@", prefix, number, suffix)))
        }
        permanent = try Lemmings3StyleBank(objects: read("PERM", "OBJ"), frames: read("PERM", "FRL"), blocks: read("PERM", "BLK"))
        temporary = try Lemmings3StyleBank(objects: read("TEMP", "OBJ"), frames: read("TEMP", "FRL"), blocks: read("TEMP", "BLK"))
        let bytes = Array(try read("DATA", "PAL"))
        guard bytes.count == 208 * 3 else {
            throw SequelDataError.invalid("Invalid Chronicles style palette.")
        }
        var colours = Array(repeating: UInt8(0), count: 1024)
        let defaultTribes = [1: 4, 2: 10, 3: 5]
        guard let tribe = lemmingStyle ?? defaultTribes[number] else {
            throw SequelDataError.invalid("Unknown Chronicles tribe palette.")
        }
        let tribeURL = directory.deletingLastPathComponent().appendingPathComponent(
            String(format: "GRAPHICS/TRIBE%03d.PAL", tribe))
        let tribeColours = Array(try Data(contentsOf: tribeURL))
        guard tribeColours.count >= 96 else {
            throw SequelDataError.invalid("Truncated Chronicles tribe palette.")
        }
        // The VGA DAC consumes the low six bits. Local CD palettes include
        // values with the upper two bits set, so retain that hardware rule.
        for index in 0..<32 {
            for channel in 0..<3 { colours[index * 4 + channel] = UInt8(Int(tribeColours[index * 3 + channel] & 63) * 255 / 63) }
            colours[index * 4 + 3] = 255
        }
        for index in 0..<208 {
            for channel in 0..<3 { colours[(index + 32) * 4 + channel] = UInt8(Int(bytes[index * 3 + channel] & 63) * 255 / 63) }
            colours[(index + 32) * 4 + 3] = 255
        }
        palette = colours
    }
}
