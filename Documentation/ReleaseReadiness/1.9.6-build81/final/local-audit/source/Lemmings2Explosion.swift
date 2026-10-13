import Foundation

/// Original explosion point frames from PROCESS 15c4, drawn by VGA 3b32.
public struct Lemmings2Explosion: Sendable {
    public struct Point: Sendable, Equatable {
        public let x: Int
        public let y: Int
        public let colour: Int
    }
    public let frames: [[Point]]

    public init(data: Data) throws {
        let reader = SequelBinary(data)
        guard try reader.tag(0) == "L2EP", try reader.u16(4) == 52, try reader.u16(6) == 80,
              reader.count == 8328 else { throw SequelDataError.invalid("Invalid L2 explosion animation.") }
        frames = (0..<52).map { frame in
            var colour = 0
            return (0..<80).compactMap { point in
                let offset = 8+frame*160+point*2
                let x = reader.bytes[offset]
                guard x != 128 else { return nil }
                defer { colour = (colour+1)&15 }
                return Point(x:Int(Int8(bitPattern:x)),y:Int(Int8(bitPattern:reader.bytes[offset+1])),colour:colour)
            }
        }
    }

    public init(root: URL) throws {
        let extracted = root.appendingPathComponent("EXPLOSION.DAT")
        if FileManager.default.fileExists(atPath:extracted.path) {
            try self.init(data:Data(contentsOf:extracted)); return
        }
        // Original installations store this data inside an overlay. Read its
        // container offsets only. The app never executes overlay instructions.
        let reader = SequelBinary(try Data(contentsOf:root.appendingPathComponent("PROCESS.RKO")))
        var cursor = 16
        for _ in 0..<(try reader.u16(0)) {
            let length = Int(try reader.slice(cursor,1)[0])
            guard length > 0, try reader.slice(cursor+length,1)[0] == 0 else {
                throw SequelDataError.invalid("Invalid L2 overlay symbol.")
            }
            cursor += length+1
        }
        var recognised = false
        for _ in 0..<(try reader.u16(2)) {
            let segment = try reader.slice(cursor+1,1)[0]
            if segment == 1, try reader.u16(cursor+2) == 0x0a53 { recognised = true }
            cursor += 4
        }
        cursor += try reader.u32(4)+reader.u16(8)*3
        guard recognised, try reader.u16(10) >= 0x15c4+8320 else {
            throw SequelDataError.invalid("Unrecognised L2 explosion animation layout.")
        }
        try self.init(data:Data(Array("L2EP".utf8)+[52,0,80,0]+reader.slice(cursor+0x15c4,8320)))
    }
}
