import Foundation

/// Native IND/CMP sprite command interpreter. Pixel zero is not transparency:
/// only skipped pixels are transparent.
public struct Lemmings3Sprites: Sendable {
    public struct Frame: Sendable {
        public let pixels: [UInt8]
        public let opaque: [Bool]
    }
    public struct Animation: Sendable {
        public let width: Int
        public let height: Int
        public let frames: [Frame]
    }
    public let animations: [Animation]
    /// Sprite palettes replace the low 32 VGA entries without changing terrain colors.
    public static func palette(_ data: Data, over base: [UInt8]) throws -> [UInt8] {
        guard data.count == 96, base.count == 1024 else { throw SequelDataError.invalid("Invalid L3 sprite palette.") }
        let bytes = Array(data)
        var colours = base
        for index in 0..<32 {
            for channel in 0..<3 { colours[index * 4 + channel] = UInt8(Int(bytes[index * 3 + channel] & 63) * 255 / 63) }
            colours[index * 4 + 3] = 255
        }
        return colours
    }

    public init(index: Data, commands: Data) throws {
        let info = SequelBinary(index)
        let code = SequelBinary(commands)
        guard info.count.isMultiple(of: 6) else {
            throw SequelDataError.invalid("L3 sprite index contains a partial record.")
        }
        var cursor = 0
        var budget = 16 * 1024 * 1024
        var result: [Animation] = []
        for offset in stride(from: 0, to: info.count, by: 6) {
            let width = try info.u16(offset)
            let height = try info.u16(offset + 2)
            let count = try info.u16(offset + 4)
            guard width > 0, height > 0, width <= 4096, height <= 4096,
                  count <= 4096, width * height * count <= budget else {
                throw SequelDataError.invalid("L3 sprite dimensions exceed the decode limit.")
            }
            budget -= width * height * count
            var frames: [Frame] = []
            for _ in 0..<count {
                var pixels = Array(repeating: UInt8(0), count: width * height)
                var opaque = Array(repeating: false, count: width * height)
                for plane in 0..<4 {
                    var x = 0
                    var y = 0
                    while true {
                        let command = try code.slice(cursor, 1)[0]
                        cursor += 1
                        if command == 255 { break }
                        // 00 is one newline, not two zero-nibble instructions.
                        let operations = command == 0 ? [0] : [Int(command >> 4), Int(command & 15)]
                        for operation in operations {
                            switch operation {
                            case 0: x = 0; y += 1
                            case 1...8:
                                let values = try code.slice(cursor, operation)
                                cursor += operation
                                for value in values {
                                    let px = x * 4 + plane
                                    guard y < height, px < width else {
                                        throw SequelDataError.invalid("L3 sprite command writes outside its frame.")
                                    }
                                    pixels[y * width + px] = value
                                    opaque[y * width + px] = true
                                    x += 1
                                }
                            case 9...14: x += operation - 8
                            default:
                                throw SequelDataError.invalid("Unsupported L3 sprite command \(command).")
                            }
                            guard y <= height, x <= (width + 3) / 4 else {
                                throw SequelDataError.invalid("L3 sprite cursor leaves its frame.")
                            }
                        }
                    }
                }
                frames.append(Frame(pixels: pixels, opaque: opaque))
            }
            result.append(Animation(width: width, height: height, frames: frames))
        }
        guard cursor == code.count else {
            throw SequelDataError.invalid("Trailing L3 sprite commands.")
        }
        animations = result
    }
}
