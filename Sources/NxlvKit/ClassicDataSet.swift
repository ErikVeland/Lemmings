import Foundation

/// Works out which Lemmings data set a directory holds, and loads it.
///
/// Titles in this container format differ in small ways. Retail Lemmings names
/// its levels `LEVEL###.DAT` and needs its authored order, because `ODDTABLE`
/// overrides and the shipped sequence do not follow file order. Oh No! More
/// Lemmings names them `DLVEL###.DAT`, ships no odd table, and can be listed
/// by scanning. Detecting this means the player picks a folder and the right
/// thing happens.
public struct ClassicDataSet: Sendable {
    public enum Kind: String, Sendable {
        /// Retail Lemmings, loaded through its authored rank order.
        case originalLemmings
        /// Any other set in the same format, listed by scanning.
        case scanned
    }

    public let kind: Kind
    public let name: String
    public let levelFilePrefix: String
    public let campaign: ClassicCampaign
    /// Ground styles the directory actually provides.
    public let groundStyles: [Int]
    /// Special graphic indices the directory actually provides.
    public let specialIndices: [Int]

    /// A stable key for storing progress against this game.
    public var identifierKey: String {
        "\(kind.rawValue)-\(levelFilePrefix)-\(campaign.levels.count)"
    }

    /// Prefixes worth trying, longest first so `DLVEL` wins over `LEVEL`.
    private static let knownPrefixes = ["DLVEL", "LEVEL"]

    public static func detect(directory: URL) throws -> ClassicDataSet {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let names = Set(contents.map { $0.lastPathComponent.lowercased() })

        func hasLevels(prefix: String) -> Bool {
            names.contains { name in
                let lower = prefix.lowercased()
                guard name.hasPrefix(lower), name.hasSuffix(".dat") else { return false }
                let middle = name.dropFirst(lower.count).dropLast(4)
                return middle.count == 3 && middle.allSatisfy(\.isNumber)
            }
        }

        guard let prefix = knownPrefixes.first(where: { hasLevels(prefix: $0) }) else {
            throw ClassicCampaignError.noLevelFiles(prefix: knownPrefixes.joined(separator: " or "))
        }

        // Ground and special sets vary by title, so take what is present.
        var groundStyles: [Int] = []
        for style in 0..<8 where names.contains("ground\(style)o.dat") {
            groundStyles.append(style)
        }
        var specialIndices: [Int] = []
        for index in 0..<8 where names.contains("vgaspec\(index).dat") {
            specialIndices.append(index)
        }

        // Retail Lemmings is the one set with an odd table and a known order.
        if prefix == "LEVEL", names.contains("oddtable.dat") {
            let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
            return ClassicDataSet(
                kind: .originalLemmings,
                name: "Lemmings",
                levelFilePrefix: prefix,
                campaign: campaign,
                groundStyles: groundStyles,
                specialIndices: specialIndices)
        }

        let campaign = try ClassicCampaign.scan(
            directory: directory,
            name: directory.lastPathComponent,
            levelFilePrefix: prefix)
        return ClassicDataSet(
            kind: .scanned,
            name: prefix == "DLVEL" ? "Oh No! More Lemmings" : directory.lastPathComponent,
            levelFilePrefix: prefix,
            campaign: campaign,
            groundStyles: groundStyles,
            specialIndices: specialIndices)
    }
}
