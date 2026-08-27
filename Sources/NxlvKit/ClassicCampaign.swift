import Foundation

public enum ClassicCampaignError: Error, Equatable, CustomStringConvertible {
    case malformedOddTable(size: Int)
    case missingFile(String)
    case archiveSectionCount(file: String, expected: Int, actual: Int)
    case invalidEncodedReference(Int)
    case invalidLevelReference(rank: String, number: Int, file: Int, section: Int)
    case missingOddTableEntry(index: Int)

    public var description: String {
        switch self {
        case let .malformedOddTable(size):
            return "ODDTABLE.DAT size \(size) is not a multiple of 56 bytes."
        case let .missingFile(file):
            return "Required classic game-data file is missing: \(file)."
        case let .archiveSectionCount(file, expected, actual):
            return "\(file) contains \(actual) sections; expected \(expected)."
        case let .invalidEncodedReference(reference):
            return "Classic campaign level reference \(reference) cannot be decoded."
        case let .invalidLevelReference(rank, number, file, section):
            return "\(rank) \(number) refers to missing LEVEL\(String(format: "%03d", file)).DAT section \(section)."
        case let .missingOddTableEntry(index):
            return "ODDTABLE.DAT has no property record at index \(index)."
        }
    }
}

/// The uncompressed alternate-property table used for official repeat levels.
public struct ClassicOddTable: Sendable {
    public static let recordSize = 56
    public let properties: [ClassicLevelProperties]

    public init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count.isMultiple(of: Self.recordSize) else {
            throw ClassicCampaignError.malformedOddTable(size: bytes.count)
        }

        var result: [ClassicLevelProperties] = []
        result.reserveCapacity(bytes.count / Self.recordSize)
        for recordOffset in stride(from: 0, to: bytes.count, by: Self.recordSize) {
            var skills: [ClassicSkill: Int] = [:]
            for (index, skill) in ClassicSkill.allCases.enumerated() {
                skills[skill] = Self.word(bytes, at: recordOffset + 8 + index * 2)
            }
            let titleData = Data(bytes[(recordOffset + 24)..<(recordOffset + 56)])
            let title = String(data: titleData, encoding: .isoLatin1)
                ?? String(decoding: titleData, as: UTF8.self)
            result.append(ClassicLevelProperties(
                title: ClassicLevel.cleanTitle(title),
                releaseRate: Self.word(bytes, at: recordOffset),
                lemmingCount: Self.word(bytes, at: recordOffset + 2),
                saveRequirement: Self.word(bytes, at: recordOffset + 4),
                timeLimitMinutes: Self.word(bytes, at: recordOffset + 6),
                skills: skills
            ))
        }
        properties = result
    }

    public subscript(index: Int) -> ClassicLevelProperties? {
        properties.indices.contains(index) ? properties[index] : nil
    }

    private static func word(_ bytes: [UInt8], at offset: Int) -> Int {
        (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
    }
}

public struct ClassicCampaignLevel: Codable, Equatable, Sendable {
    public let rank: String
    public let number: Int
    public let archiveFile: Int
    public let archiveSection: Int
    public let usesOddTableProperties: Bool
    public let level: ClassicLevel
}

public struct ClassicCampaign: Codable, Equatable, Sendable {
    public let name: String
    public let levels: [ClassicCampaignLevel]

    public var ranks: [String] {
        levels.reduce(into: []) { result, level in
            if result.last != level.rank { result.append(level.rank) }
        }
    }
}

public struct ClassicRankDefinition: Codable, Equatable, Sendable {
    public let name: String
    public let order: [Int]

    public init(name: String, order: [Int]) {
        self.name = name
        self.order = order
    }
}

public struct ClassicCampaignDefinition: Codable, Equatable, Sendable {
    public let name: String
    public let levelFilePrefix: String
    public let ranks: [ClassicRankDefinition]
    public let usesOddTable: Bool

    public init(name: String, levelFilePrefix: String, ranks: [ClassicRankDefinition], usesOddTable: Bool) {
        self.name = name
        self.levelFilePrefix = levelFilePrefix
        self.ranks = ranks
        self.usesOddTable = usesOddTable
    }

    /// The retail DOS campaign: four ranks and all 120 playable slots.
    /// A negative entry means that the geometry comes from the referenced
    /// archive section while its parameters come from the matching physical
    /// record in ODDTABLE.DAT.
    public static let originalDOSLemmings = ClassicCampaignDefinition(
        name: "Lemmings (DOS)",
        levelFilePrefix: "LEVEL",
        ranks: [
            ClassicRankDefinition(name: "Fun", order: [
                91, 95, 96, 92, 93, 94, 97, -6, -12, -32, -42, -7, 16, -17, -22,
                -24, -27, -43, -51, -63, -84, 13, -41, -57, -60, -71, -46, -61, -65, -82,
            ]),
            ClassicRankDefinition(name: "Tricky", order: [
                0, -16, -21, -30, -31, -33, -34, -47, -62, -73, -77, -80, -83, 2, -91,
                -93, -94, -95, -97, 3, 5, 6, 7, 10, 11, 12, 14, 15, 20, 17,
            ]),
            ClassicRankDefinition(name: "Taxing", order: [
                22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 1,
                40, 41, 42, 43, 44, 45, 46, 47, 50, 51, 52, 53, 54, 21, 67,
            ]),
            ClassicRankDefinition(name: "Mayhem", order: [
                55, 56, 57, 60, 61, 62, 63, 64, 65, 66, -67, 70, 71, 72, 73,
                74, 75, 76, 77, -92, 80, 4, 81, 82, 83, 84, 85, 86, 87, 90,
            ]),
        ],
        usesOddTable: true
    )

    public func load(from directory: URL) throws -> ClassicCampaign {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let filesByLowercaseName = Dictionary(
            fileURLs.map { ($0.lastPathComponent.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let references = ranks.flatMap(\.order)
        if let invalidReference = references.first(where: { $0 == Int.min }) {
            throw ClassicCampaignError.invalidEncodedReference(invalidReference)
        }
        let fileIDs = Set(references.map { abs($0) / 10 }).sorted()
        var sectionsByFile: [Int: [ClassicDATSection]] = [:]
        for fileID in fileIDs {
            let filename = String(format: "%@%03d.dat", levelFilePrefix.lowercased(), fileID)
            guard let url = filesByLowercaseName[filename] else {
                throw ClassicCampaignError.missingFile(filename)
            }
            let sections = try ClassicDATArchive.decode(Data(contentsOf: url, options: .mappedIfSafe))
            guard sections.count == 8 else {
                throw ClassicCampaignError.archiveSectionCount(file: url.lastPathComponent, expected: 8, actual: sections.count)
            }
            sectionsByFile[fileID] = sections
        }

        let oddTable: ClassicOddTable?
        if usesOddTable {
            guard let oddURL = filesByLowercaseName["oddtable.dat"] else {
                throw ClassicCampaignError.missingFile("ODDTABLE.DAT")
            }
            oddTable = try ClassicOddTable(data: Data(contentsOf: oddURL, options: .mappedIfSafe))
        } else {
            oddTable = nil
        }

        var campaignLevels: [ClassicCampaignLevel] = []
        for rank in ranks {
            for (levelIndex, encodedReference) in rank.order.enumerated() {
                let absoluteReference = abs(encodedReference)
                let fileID = absoluteReference / 10
                let sectionIndex = absoluteReference % 10
                guard let sections = sectionsByFile[fileID], sections.indices.contains(sectionIndex) else {
                    throw ClassicCampaignError.invalidLevelReference(
                        rank: rank.name,
                        number: levelIndex + 1,
                        file: fileID,
                        section: sectionIndex
                    )
                }

                let usesOverride = encodedReference < 0
                let override: ClassicLevelProperties?
                if usesOverride {
                    let physicalIndex = fileID * 8 + sectionIndex
                    guard let properties = oddTable?[physicalIndex] else {
                        throw ClassicCampaignError.missingOddTableEntry(index: physicalIndex)
                    }
                    override = properties
                } else {
                    override = nil
                }

                let level = try ClassicLevel(
                    data: sections[sectionIndex].data,
                    propertiesOverride: override
                )
                campaignLevels.append(ClassicCampaignLevel(
                    rank: rank.name,
                    number: levelIndex + 1,
                    archiveFile: fileID,
                    archiveSection: sectionIndex,
                    usesOddTableProperties: usesOverride,
                    level: level
                ))
            }
        }
        return ClassicCampaign(name: name, levels: campaignLevels)
    }
}
