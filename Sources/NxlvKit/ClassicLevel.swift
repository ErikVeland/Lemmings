import Foundation

public enum ClassicSkill: String, CaseIterable, Codable, Sendable {
    case climber
    case floater
    case bomber
    case blocker
    case builder
    case basher
    case miner
    case digger
}

public struct ClassicDrawProperties: Codable, Equatable, Sendable {
    public let isUpsideDown: Bool
    public let noOverwrite: Bool
    public let onlyOverwrite: Bool
    public let isErase: Bool

    public init(isUpsideDown: Bool, noOverwrite: Bool, onlyOverwrite: Bool, isErase: Bool) {
        self.isUpsideDown = isUpsideDown
        self.noOverwrite = noOverwrite
        self.onlyOverwrite = onlyOverwrite
        self.isErase = isErase
    }
}

public struct ClassicObjectPlacement: Codable, Equatable, Sendable {
    /// Original zero-based slot in the 32-entry LVL object table.
    public let slot: Int
    public let x: Int
    public let y: Int
    public let id: Int
    public let draw: ClassicDrawProperties

    public init(slot: Int = 0, x: Int, y: Int, id: Int, draw: ClassicDrawProperties) {
        self.slot = slot
        self.x = x
        self.y = y
        self.id = id
        self.draw = draw
    }
}

public struct ClassicTerrainPlacement: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let id: Int
    public let draw: ClassicDrawProperties

    public init(x: Int, y: Int, id: Int, draw: ClassicDrawProperties) {
        self.x = x
        self.y = y
        self.id = id
        self.draw = draw
    }
}

public struct ClassicSteelArea: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ClassicLevelProperties: Codable, Equatable, Sendable {
    public let title: String
    public let releaseRate: Int
    public let lemmingCount: Int
    public let saveRequirement: Int
    public let timeLimitMinutes: Int
    public let skills: [ClassicSkill: Int]

    public init(
        title: String,
        releaseRate: Int,
        lemmingCount: Int,
        saveRequirement: Int,
        timeLimitMinutes: Int,
        skills: [ClassicSkill: Int]
    ) {
        self.title = title
        self.releaseRate = releaseRate
        self.lemmingCount = lemmingCount
        self.saveRequirement = saveRequirement
        self.timeLimitMinutes = timeLimitMinutes
        self.skills = skills
    }
}

public enum ClassicLevelError: Error, Equatable, CustomStringConvertible {
    case invalidSize(actual: Int, minimum: Int)
    case invalidRecordSize(actual: Int, expected: Int)

    public var description: String {
        switch self {
        case let .invalidSize(actual, minimum):
            return "A classic level must contain at least \(minimum) bytes; found \(actual)."
        case let .invalidRecordSize(actual, expected):
            return "An unpacked classic LVL file must contain exactly \(expected) bytes; found \(actual)."
        }
    }
}

/// One unpacked 2,048-byte DOS/LemEdit level record.
public struct ClassicLevel: Codable, Equatable, Sendable {
    public static let recordSize = 2_048
    public static let width = 1_600
    public static let height = 160

    public let title: String
    public let releaseRate: Int
    public let lemmingCount: Int
    public let saveRequirement: Int
    public let timeLimitMinutes: Int
    public let skills: [ClassicSkill: Int]
    public let startX: Int
    public let groundStyle: Int
    public let specialStyle: Int
    public let isSuperLemming: Bool
    public let objects: [ClassicObjectPlacement]
    public let terrain: [ClassicTerrainPlacement]
    public let steel: [ClassicSteelArea]

    public init(data: Data, propertiesOverride: ClassicLevelProperties? = nil) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= Self.recordSize else {
            throw ClassicLevelError.invalidSize(actual: bytes.count, minimum: Self.recordSize)
        }

        var parsedSkills: [ClassicSkill: Int] = [:]
        for (index, skill) in ClassicSkill.allCases.enumerated() {
            parsedSkills[skill] = Self.word(bytes, at: 0x0008 + index * 2)
        }

        let titleBytes = Data(bytes[0x07E0..<0x0800])
        let decodedTitle = String(data: titleBytes, encoding: .isoLatin1)
            ?? String(decoding: titleBytes, as: UTF8.self)
        let baseProperties = ClassicLevelProperties(
            title: Self.cleanTitle(decodedTitle),
            releaseRate: Self.word(bytes, at: 0x0000),
            lemmingCount: Self.word(bytes, at: 0x0002),
            saveRequirement: Self.word(bytes, at: 0x0004),
            timeLimitMinutes: Self.word(bytes, at: 0x0006),
            skills: parsedSkills
        )
        let effectiveProperties = propertiesOverride ?? baseProperties
        title = effectiveProperties.title
        releaseRate = effectiveProperties.releaseRate
        lemmingCount = effectiveProperties.lemmingCount
        saveRequirement = effectiveProperties.saveRequirement
        timeLimitMinutes = effectiveProperties.timeLimitMinutes
        skills = effectiveProperties.skills

        startX = Self.word(bytes, at: 0x0018)
        groundStyle = Self.word(bytes, at: 0x001A)
        specialStyle = Self.word(bytes, at: 0x001C)
        // DOS/LemEdit uses the exact reserved marker 0xFFFF. Other reserved
        // values do not enable Superlemming mode.
        isSuperLemming = Self.word(bytes, at: 0x001E) == 0xFFFF

        var parsedObjects: [ClassicObjectPlacement] = []
        for index in 0..<32 {
            let offset = 0x0020 + index * 8
            guard bytes[offset..<(offset + 8)].contains(where: { $0 != 0 }) else { continue }
            let flags = Self.word(bytes, at: offset + 6)
            let storedX = Self.signedWord(bytes, at: offset)
            parsedObjects.append(ClassicObjectPlacement(
                slot: index,
                x: (storedX & ~7) - 16,
                y: Self.signedWord(bytes, at: offset + 2),
                id: Int(bytes[offset + 5] & 0x0F),
                draw: ClassicDrawProperties(
                    isUpsideDown: bytes[offset + 7] == 0x8F,
                    noOverwrite: flags & 0x8000 != 0,
                    onlyOverwrite: flags & 0x4000 != 0,
                    isErase: false
                )
            ))
        }
        objects = parsedObjects

        var parsedTerrain: [ClassicTerrainPlacement] = []
        for index in 0..<400 {
            let offset = 0x0120 + index * 4
            let value = Self.doubleWord(bytes, at: offset)
            guard value != UInt32.max else { continue }
            let yValue = Int((value >> 7) & 0x01FF)
            let flags = Int((value >> 29) & 0x0007)
            let noOverwrite = flags & 0x04 != 0
            parsedTerrain.append(ClassicTerrainPlacement(
                x: Int((value >> 16) & 0x0FFF) - 16,
                y: yValue - (yValue > 256 ? 516 : 4),
                id: Int(value & 0x003F),
                draw: ClassicDrawProperties(
                    isUpsideDown: flags & 0x02 != 0,
                    noOverwrite: noOverwrite,
                    onlyOverwrite: false,
                    isErase: !noOverwrite && flags & 0x01 != 0
                )
            ))
        }
        terrain = parsedTerrain

        var parsedSteel: [ClassicSteelArea] = []
        for index in 0..<32 {
            let offset = 0x0760 + index * 4
            let position = Self.word(bytes, at: offset)
            let size = Int(bytes[offset + 2])
            let reserved = bytes[offset + 3]
            guard position != 0 || size != 0 else { continue }
            guard reserved == 0 else { continue }
            parsedSteel.append(ClassicSteelArea(
                x: ((position >> 7) & 0x01FF) * 4 - 16,
                y: (position & 0x007F) * 4,
                width: ((size >> 4) & 0x0F) * 4 + 4,
                height: (size & 0x0F) * 4 + 4
            ))
        }
        steel = parsedSteel

    }

    public var properties: ClassicLevelProperties {
        ClassicLevelProperties(
            title: title,
            releaseRate: releaseRate,
            lemmingCount: lemmingCount,
            saveRequirement: saveRequirement,
            timeLimitMinutes: timeLimitMinutes,
            skills: skills
        )
    }

    private static func word(_ bytes: [UInt8], at offset: Int) -> Int {
        (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
    }

    private static func signedWord(_ bytes: [UInt8], at offset: Int) -> Int {
        Int(Int16(bitPattern: UInt16(word(bytes, at: offset))))
    }

    private static func doubleWord(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    static func cleanTitle(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.controlCharacters))
    }
}
