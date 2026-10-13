import Foundation

/// Data-only images extracted from the original optimized walker drawing.
public struct Lemmings2Walker: Sendable {
    public let frames: [Lemmings2SpriteFrame]
    public init(data: Data) throws {
        let reader = SequelBinary(data)
        guard try reader.tag(0) == "L2WK", try reader.u16(4) == 16, try reader.u16(6) == 10,
              reader.count == 2568 else { throw SequelDataError.invalid("Invalid L2 walker images.") }
        frames = try (0..<16).map { phase in
            let pixels = try reader.slice(8+phase*160,160)
            guard pixels.allSatisfy({$0 <= 3}) else { throw SequelDataError.invalid("Invalid L2 walker colour.") }
            return .init(x:-(phase&7),y:0,width:16,height:10,pixels:pixels,opaque:pixels.map{$0 != 0})
        }
    }
    public static func phase(x: Int, direction: Int) -> Int { ((x-2)&7)+(direction < 0 ? 8 : 0) }
}
