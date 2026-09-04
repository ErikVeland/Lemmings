import Foundation

/// A native VLEMMS animation frame. Offsets are relative to the animation origin.
public struct Lemmings2SpriteFrame: Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]
    public let opaque: [Bool]
    public init(x: Int, y: Int, width: Int, height: Int, pixels: [UInt8], opaque: [Bool]) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.pixels = pixels; self.opaque = opaque
    }
}

/// Shared pixel interpreter for VLEMMS and L2SS. A caller supplies the exact
/// command-data range so a truncated plane cannot read the next sprite entry.
enum Lemmings2SpriteCommands {
    static func decode(_ r: SequelBinary, width: Int, height: Int, planes: [Int],
                       within bounds: Range<Int>) throws -> (pixels: [UInt8], opaque: [Bool]) {
        guard width > 0, height > 0, width <= 1024, height <= 1024, planes.count == 4 else {
            throw SequelDataError.invalid("Invalid L2 sprite dimensions or plane count.")
        }
        var pixels = [UInt8](repeating: 0, count: width * height)
        var opaque = [Bool](repeating: false, count: width * height)
        for plane in 0..<4 {
            var cursor = planes[plane]
            guard bounds.contains(cursor) else {
                throw SequelDataError.invalid("L2 sprite plane is outside its command data.")
            }
            var column = 0, row = 0
            while true {
                guard cursor < bounds.upperBound else {
                    throw SequelDataError.invalid("Unterminated L2 sprite plane.")
                }
                let command = try r.slice(cursor, 1)[0]
                cursor += 1
                if command == 255 { break }
                let high = Int(command >> 4), low = Int(command & 15)
                var literal = 0, skipAfter = 0
                var newline = false
                // VGA.RKO 2a09–2a4e treats each nibble independently:
                // 1…7 copy pixels, 8…15 skip 0…7; low zero ends a row.
                // In particular E1 is a six-pixel skip followed by one pixel.
                if high < 8 { literal = high } else { column += high - 8 }
                if low == 0 { newline = true }
                else if low < 8 { literal += low }
                else { skipAfter = low - 8 }
                guard literal <= bounds.upperBound - cursor else {
                    throw SequelDataError.invalid("Truncated L2 sprite pixels.")
                }
                let values = try r.slice(cursor, literal)
                cursor += literal
                for value in values {
                    let px = column * 4 + plane
                    guard row < height, px < width else {
                        throw SequelDataError.invalid("L2 sprite pixel exceeds its frame.")
                    }
                    pixels[row * width + px] = value
                    opaque[row * width + px] = true
                    column += 1
                }
                column += skipAfter
                if newline { column = 0; row += 1 }
                guard row <= height, column <= (width + 3) / 4 else {
                    throw SequelDataError.invalid("L2 sprite cursor leaves its frame.")
                }
            }
        }
        return (pixels, opaque)
    }
}

/// Interprets VLEMMS four-plane pixel commands without executing DOS code.
public struct Lemmings2Sprites: Sendable {
    public let animations: [String: [Lemmings2SpriteFrame]]

    public init(data: Data) throws {
        let form = try Lemmings2Form(data: data)
        guard form.type == "L2VL" else {
            throw SequelDataError.invalid("Expected L2VL sprite data, found \(form.type).")
        }
        var result: [String: [Lemmings2SpriteFrame]] = [:]
        var budget = 16 * 1024 * 1024
        for section in form.sections where section.identifier.hasPrefix("LM") {
            guard result[section.identifier] == nil else {
                throw SequelDataError.invalid("Duplicate L2 sprite animation.")
            }
            let r = SequelBinary(section.data)
            let count = try r.u16(0)
            let tableEnd = 2 + count * 2
            _ = try r.slice(2, count * 2)
            var frames: [Lemmings2SpriteFrame] = []
            for index in 0..<count {
                let start = try r.u16(2 + index * 2)
                guard start >= tableEnd else {
                    throw SequelDataError.invalid("L2 sprite frame overlaps its pointer table.")
                }
                let x = Int(Int16(bitPattern: UInt16(try r.u16(start))))
                let y = Int(Int16(bitPattern: UInt16(try r.u16(start + 2))))
                guard try r.u16(start + 4) == start + 6 else {
                    throw SequelDataError.invalid("L2 sprite size pointer does not match its frame.")
                }
                let width = try r.u16(start + 6)
                let height = try r.u16(start + 8)
                guard width > 0, height > 0, width <= 1024, height <= 1024,
                      width * height <= budget else {
                    throw SequelDataError.invalid("L2 sprite dimensions exceed the decode limit.")
                }
                budget -= width * height
                let planes = try (0..<4).map { try r.u16(start + 10 + $0 * 2) }
                let decoded = try Lemmings2SpriteCommands.decode(r, width: width, height: height,
                    planes: planes, within: (start + 18)..<r.count)
                frames.append(Lemmings2SpriteFrame(x: x, y: y, width: width, height: height,
                                                  pixels: decoded.pixels, opaque: decoded.opaque))
            }
            result[section.identifier] = frames
        }
        guard !result.isEmpty else { throw SequelDataError.invalid("No L2 lemming animations found.") }
        animations = result
    }
}
