import Foundation

extension Lemmings2Style {
    public func specialAnimation(_ identifier: Int) throws -> [Lemmings2SpriteFrame] {
        try Lemmings2SpecialGraphics(container: container).animation(identifier)
    }
}

/// The same sprite bank format is used by style objects, MASKS and INTERN.
public struct Lemmings2SpecialGraphics: Sendable {
    public let container: Lemmings2Form
    public enum Addressing: Sendable { case style, frontEnd }
    private let addressing: Addressing

    public init(data: Data, addressing: Addressing = .style) throws {
        let form = try Lemmings2Form(data: data)
        guard form.type == "L2VG" else { throw SequelDataError.invalid("Expected L2VG sprite bank.") }
        container = form
        self.addressing = addressing
    }
    init(container: Lemmings2Form) { self.container = container; addressing = .style }
    public var animationCount: Int {
        get throws { try SequelBinary(container.requiredSection("L2SI")).u16(0) }
    }
    /// Decode L2SI → L2SA → L2SF → L2SS without discarding signed anchors or
    /// opaque black pixels. L2SS pointers omit each entry's two-byte size word.
    public func animation(_ identifier: Int) throws -> [Lemmings2SpriteFrame] {
        let index = SequelBinary(try container.requiredSection("L2SI"))
        let count = try index.u16(0)
        guard index.count == 2 + count * 2, identifier >= 0, identifier < count else {
            throw SequelDataError.invalid("Unknown L2 special animation \(identifier).")
        }
        let animations = SequelBinary(try container.requiredSection("L2SA"))
        var animationOffsets = Set<Int>()
        var cursor = 2
        for _ in 0..<(try animations.u16(0)) {
            animationOffsets.insert(cursor)
            let frames = try animations.u16(cursor)
            guard frames <= 1024 else { throw SequelDataError.invalid("Too many L2 special frames.") }
            _ = try animations.slice(cursor + 2, frames * 2)
            cursor += 2 + frames * 2
        }
        let start = try index.u16(2 + identifier * 2) + 2
        guard cursor == animations.count, animationOffsets.contains(start) else {
            throw SequelDataError.invalid("Invalid L2 special animation offset.")
        }
        let positions = SequelBinary(try container.requiredSection("L2SF"))
        guard positions.count == 2 + (try positions.u16(0)) * 6 else {
            throw SequelDataError.invalid("Invalid L2 special frame table size.")
        }
        let shapes = SequelBinary(try container.requiredSection("L2SS"))
        var shapeOffsets: [Int: Range<Int>] = [:]
        cursor = 2
        var logical = 0
        for _ in 0..<(try shapes.u16(0)) {
            let size = try shapes.u16(cursor)
            guard size >= 12 else { throw SequelDataError.invalid("Truncated L2 special sprite header.") }
            _ = try shapes.slice(cursor + 2, size)
            shapeOffsets[logical] = (cursor + 2)..<(cursor + 2 + size)
            cursor += size + 2
            logical += size
        }
        // DOS style banks pad an odd-length sprite section with one zero byte.
        let padded = cursor % 2 == 1 && shapes.count == cursor + 1 && shapes.bytes[cursor] == 0
        guard cursor == shapes.count || padded else {
            throw SequelDataError.invalid("Invalid L2 special sprite table size.")
        }
        var budget = 16 * 1024 * 1024
        return try (0..<(try animations.u16(start))).map { frame in
            let positionOffset = try animations.u16(start + 2 + frame * 2)
            guard positionOffset.isMultiple(of: 6), positionOffset / 6 < (try positions.u16(0)) else {
                throw SequelDataError.invalid("Invalid L2 special frame offset.")
            }
            let p = positionOffset + 2
            // GAL uses paragraph addresses for its larger front-end banks.
            // Its plane pointers are local to each shape (GAL 1fa0–2073).
            let shapeOffset = try positions.u16(p + 4) * (addressing == .frontEnd ? 16 : 1)
            guard let shape = shapeOffsets[shapeOffset] else {
                throw SequelDataError.invalid("Invalid L2 special sprite offset.")
            }
            let width = try shapes.u16(shape.lowerBound), height = try shapes.u16(shape.lowerBound + 2)
            guard width > 0, height > 0, width <= 1024, height <= 1024, width * height <= budget else {
                throw SequelDataError.invalid("L2 special sprite exceeds the decode limit.")
            }
            budget -= width * height
            let planes = try (0..<4).map {
                try shapes.u16(shape.lowerBound + 4 + $0 * 2) + shape.lowerBound
                    - (addressing == .style ? shapeOffset : 0)
            }
            let decoded = try Lemmings2SpriteCommands.decode(shapes, width: width, height: height,
                planes: planes, within: (shape.lowerBound + 12)..<shape.upperBound)
            return Lemmings2SpriteFrame(
                x: Int(Int16(bitPattern: UInt16(try positions.u16(p)))),
                y: Int(Int16(bitPattern: UInt16(try positions.u16(p + 2)))),
                width: width, height: height, pixels: decoded.pixels, opaque: decoded.opaque)
        }
    }
}
