import Foundation
import CryptoKit

/// Decoded L2LV data. Unknown fields and object parameters remain available
/// without assigning them speculative gameplay behaviour.
public struct Lemmings2Level: Sendable {
    public struct SkillSlot: Equatable, Sendable {
        public let identifier: Int
        public let count: Int
    }
    public struct Tile: Equatable, Sendable {
        public let modifier: Int
        /// The original second big-endian map word, including interaction tags.
        public let rawIdentifier: Int
        /// VGA.RKO DrawTheBack (0269–026e) masks this word to ten bits.
        public var identifier: Int { rawIdentifier & 0x03ff }
        public var metadata: Int { rawIdentifier & 0xfc00 }
    }
    public struct Object: Equatable, Sendable {
        public let identifier: Int
        public let x: Int
        public let y: Int
        public let parameter1: Int
        public let parameter2: Int
    }
    public let container: Lemmings2Form
    /// Binds a run to this exact local level file before recording progress.
    public let fingerprint: String
    public let title: String
    public let skills: [SkillSlot]
    public let timeLimitSeconds: Int
    public let style: Int
    public let tileColumns: Int
    public let screenX: Int
    public let screenY: Int
    public let minimumScreenX: Int
    public let minimumScreenY: Int
    public let maximumScreenX: Int
    public let maximumScreenY: Int
    public let allowedLossesForGold: Int
    public let releaseRate: Int
    public let tiles: [Tile]
    public let objects: [Object]

    public init(data: Data) throws {
        let form = try Lemmings2Form(data: data)
        guard form.type == "L2LV" else {
            throw SequelDataError.invalid("Expected an L2LV level, found \(form.type).")
        }
        let header = SequelBinary(try form.requiredSection("L2LH"))
        guard header.count >= 74 else {
            throw SequelDataError.invalid("The L2LH level header is truncated.")
        }
        container = form
        fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        title = String(decoding: try header.slice(0, 24), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        skills = try (0..<8).map {
            SkillSlot(identifier: try header.u16(24 + $0 * 2), count: Int(header.bytes[40 + $0]))
        }
        timeLimitSeconds = Int(header.bytes[48]) * 60 + Int(header.bytes[50])
        screenX = try header.u16(54)
        screenY = try header.u16(56)
        minimumScreenX = try header.u16(58)
        minimumScreenY = try header.u16(60)
        maximumScreenX = try header.u16(62)
        maximumScreenY = try header.u16(64)
        guard minimumScreenX <= maximumScreenX, minimumScreenY <= maximumScreenY,
              maximumScreenX <= 4096, maximumScreenY <= 4096 else {
            throw SequelDataError.invalid("Invalid L2 camera bounds.")
        }
        allowedLossesForGold = try header.u16(66)
        releaseRate = Int(Int16(bitPattern: UInt16(try header.u16(68))))

        let map = SequelBinary(try form.requiredSection("L2MH"))
        style = try map.u16(0)
        let arrangement = try map.u16(2)
        let columns = [80, 64, 50, 40, 32, 24, 20]
        guard columns.indices.contains(arrangement) else {
            throw SequelDataError.invalid("Unknown Lemmings 2 tile arrangement \(arrangement).")
        }
        tileColumns = columns[arrangement]
        let terrain = SequelBinary(try form.requiredSection("L2MP"))
        guard terrain.count.isMultiple(of: 4) else {
            throw SequelDataError.invalid("L2MP contains a partial terrain record.")
        }
        tiles = stride(from: 0, to: terrain.count, by: 4).map { offset in
            Tile(modifier: Int(terrain.bytes[offset]) << 8 | Int(terrain.bytes[offset + 1]),
                 rawIdentifier: Int(terrain.bytes[offset + 2]) << 8 | Int(terrain.bytes[offset + 3]))
        }
        let objectData = SequelBinary(try form.requiredSection("L2BO"))
        guard objectData.count.isMultiple(of: 10) else {
            throw SequelDataError.invalid("L2BO contains a partial object record.")
        }
        objects = try stride(from: 0, to: objectData.count, by: 10).map { offset in
            Object(identifier: try objectData.u16(offset),
                   x: try objectData.u16(offset + 2), y: try objectData.u16(offset + 4),
                   parameter1: try objectData.u16(offset + 6), parameter2: try objectData.u16(offset + 8))
        }
    }
}
