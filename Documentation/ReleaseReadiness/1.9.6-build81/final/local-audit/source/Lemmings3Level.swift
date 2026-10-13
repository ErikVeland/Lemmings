import Foundation

/// Native Chronicles metadata. Terrain and object graphics live in separate
/// resources. This is not a conversion to Lemmings 1 physics.
public struct Lemmings3Level: Sendable {
    public let rawData: Data
    public let lemmingStyle: Int
    public let caveMapReference: Int
    public let caveGraphicsReference: Int
    public let temporaryObjectsReference: Int
    public let permanentObjectsReference: Int
    public let style: Int
    public let width: Int
    public let height: Int
    public let screenX: Int
    public let screenY: Int
    public let timeLimitSeconds: Int
    public let extraLemmings: Int
    public let releaseRate: Int
    public let releaseDelay: Int
    public let enemyCount: Int

    public init(data: Data) throws {
        let reader = SequelBinary(data)
        guard reader.count >= 30 else {
            throw SequelDataError.invalid("The Lemmings 3 level header is shorter than 30 bytes.")
        }
        rawData = data
        lemmingStyle = try reader.u16(0)
        caveMapReference = try reader.u16(2)
        caveGraphicsReference = try reader.u16(4)
        temporaryObjectsReference = try reader.u16(6)
        permanentObjectsReference = try reader.u16(8)
        style = try reader.u16(10)
        width = try reader.u16(12)
        height = try reader.u16(14)
        guard width > 0, height > 0, width.isMultiple(of: 4), height.isMultiple(of: 4) else {
            throw SequelDataError.invalid("Lemmings 3 dimensions must be positive multiples of four.")
        }
        screenX = try reader.u16(16)
        screenY = try reader.u16(18)
        timeLimitSeconds = try reader.u16(20)
        extraLemmings = Int(reader.bytes[22])
        releaseRate = try reader.u16(24)
        releaseDelay = try reader.u16(26)
        enemyCount = try reader.u16(28)
    }
}

/// Raw permanent or temporary object placements. IDs are preserved until the
/// matching style interpreter defines their rendering and trigger behaviour.
public struct Lemmings3Objects: Sendable {
    public struct Placement: Equatable, Sendable {
        public let identifier: Int
        public let x: Int
        public let y: Int
    }
    public let placements: [Placement]

    public init(data: Data) throws {
        let reader = SequelBinary(data)
        guard reader.count.isMultiple(of: 6) else {
            throw SequelDataError.invalid("Lemmings 3 object data contains a partial six-byte record.")
        }
        placements = try stride(from: 0, to: reader.count, by: 6).map { offset in
            Placement(identifier: try reader.u16(offset),
                      x: try reader.u16(offset + 2), y: try reader.u16(offset + 4))
        }
    }
}
