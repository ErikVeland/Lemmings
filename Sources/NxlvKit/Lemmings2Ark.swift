import Foundation

/// The original ARK.ANM planar run-length and delta frames (VGA 4c27–4d27).
public struct Lemmings2Ark: Sendable {
    public let palette: [UInt8]
    public let frames: [[UInt8]]
    public static let frameDuration = 4.0/70.0

    public init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count > 768 else { throw SequelDataError.invalid("Truncated L2 ark animation.") }
        var palette = [UInt8](repeating:255,count:1024)
        for i in 0..<768 { palette[i/3*4+i%3] = UInt8(Int(bytes[i]&63)*255/63) }
        self.palette = palette
        var cursor = 768
        func byte() throws -> Int {
            guard cursor < bytes.count else { throw SequelDataError.invalid("Truncated L2 ark frame.") }
            defer { cursor += 1 }; return Int(bytes[cursor])
        }
        var frames: [[UInt8]] = [], previous = [UInt8](repeating:0,count:64000)
        for _ in 0..<100 {
            var frame = previous
            for plane in 0..<4 {
                var offset = 0
                while offset < 16000 {
                    let command = try byte()
                    let count: Int, mode: Int
                    if command == 0 { count = try byte(); mode = 1 }
                    else if command < 128 { count = command; mode = 2 }
                    else if command == 128 {
                        let length = try byte() | (byte() << 8)
                        if length < 0x8000 { count = length; mode = 0 }
                        else if length < 0xc000 { count = length-0x8000; mode = 2 }
                        else { count = length-0xc000; mode = 1 }
                    } else { count = command-128; mode = 0 }
                    guard count > 0, count <= 16000-offset else { throw SequelDataError.invalid("Invalid L2 ark frame run.") }
                    if mode == 1 {
                        let colour = UInt8(try byte())
                        for pixel in offset..<(offset+count) { frame[pixel*4+plane] = colour }
                    } else if mode == 2 {
                        for pixel in offset..<(offset+count) { frame[pixel*4+plane] = UInt8(try byte()) }
                    }
                    offset += count
                }
            }
            frames.append(frame); previous = frame
        }
        guard cursor == bytes.count else { throw SequelDataError.invalid("Unexpected data after L2 ark animation.") }
        self.frames = frames
    }
}
