import Foundation

/// Detects official campaigns and applies their retail level order. Custom
/// classic archives can still be scanned in physical order.
public struct ClassicDataSet: Sendable {
    public enum Kind: String, Sendable {
        /// Retail Lemmings, loaded through its authored rank order.
        case originalLemmings
        /// Any other set in the same format, listed by scanning.
        case scanned
        case officialCampaign
        case macintoshHoliday
    }

    public let kind: Kind
    /// The official release this data belongs to, when it can be identified.
    public let title: ClassicTitle?
    public let name: String
    public let levelFilePrefix: String
    public let campaign: ClassicCampaign
    /// Ground styles the directory actually provides.
    public let groundStyles: [Int]
    /// Special graphic indices the directory actually provides.
    public let specialIndices: [Int]

    /// A stable key for storing progress against this game.
    public var identifierKey: String {
        "\(title?.rawValue ?? kind.rawValue)-\(levelFilePrefix)-\(campaign.levels.count)"
    }

    /// The key used before releases with the same-sized campaigns were told
    /// apart. Kept only so existing progress migrates on first load.
    public var legacyIdentifierKey: String {
        "\(kind == .officialCampaign ? Kind.scanned.rawValue : kind.rawValue)-\(levelFilePrefix)-\(campaign.levels.count)"
    }

    /// Map saves from the former physical-file order to the retail ratings.
    public func migrateProgress(_ saved: ClassicGameFlow.Progress) -> ClassicGameFlow.Progress {
        guard kind == .officialCampaign,
              saved.furthestReached["All"] != nil || saved.passed.contains(where: { $0.hasPrefix("All#") }) else { return saved }
        let physical = campaign.levels.sorted {
            ($0.archiveFile, $0.archiveSection) < ($1.archiveFile, $1.archiveSection)
        }
        var reached: [String: Int] = [:]
        var passed: [String] = []
        for (index, level) in physical.enumerated() {
            if saved.passed.contains("All#\(index)") {
                passed.append("\(level.rank)#\(level.number - 1)")
                reached[level.rank] = max(reached[level.rank] ?? 0, level.number - 1)
            }
            if saved.furthestReached["All"] == index {
                reached[level.rank] = max(reached[level.rank] ?? 0, level.number - 1)
            }
        }
        return .init(furthestReached: reached, passed: passed)
    }

    /// Prefixes worth trying, longest first so `DLVEL` wins over `LEVEL`.
    private static let knownPrefixes = ["DLVEL", "LEVEL"]

    public static func detect(directory: URL) throws -> ClassicDataSet {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let names = Set(contents.map { $0.lastPathComponent.lowercased() })

        for (title, filename) in [(ClassicTitle.holidayLemmings1993, "holiday1993.rsrc"),
                                  (.holidayLemmings1994, "holiday1994.rsrc")] {
            if let file = contents.first(where: { $0.lastPathComponent.lowercased() == filename }) {
                let campaign = try ClassicHolidayCampaign.load(resourceFork: Data(contentsOf: file), title: title)
                return .init(kind: .macintoshHoliday, title: title, name: title.displayName,
                    levelFilePrefix: "MACLEVL", campaign: campaign, groundStyles: [2], specialIndices: [])
            }
        }

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
                title: .lemmings,
                name: "Lemmings",
                levelFilePrefix: prefix,
                campaign: campaign,
                groundStyles: groundStyles,
                specialIndices: specialIndices)
        }

        let scanned = try ClassicCampaign.scan(
            directory: directory,
            name: directory.lastPathComponent,
            levelFilePrefix: prefix)
        let titles = scanned.levels.map { $0.level.title }
        let title: ClassicTitle?
        if titles == ["Merry Christmas Mr Lemming", "Christmas Bonus", "Time waits for no Lemming", "This Corrosion"] {
            title = .xmasLemmings1991
        } else if titles == ["Jingle Lemming", "Happy Holidays Mr Lemming!", "A Lemming Holiday", "The North Poles"] {
            title = .xmasLemmings1992
        } else {
            title = ClassicTitle.identify(levelPrefix: prefix, levelCount: scanned.levels.count,
                                          folderName: directory.lastPathComponent)
        }
        let definition = title == .ohNoMoreLemmings
            ? ClassicCampaignDefinition.ohNoMoreLemmings
            : title.flatMap { ClassicCampaignDefinition.festive($0) }
        let campaign = try definition?.load(from: directory) ?? scanned
        return ClassicDataSet(
            kind: definition == nil ? .scanned : .officialCampaign,
            title: title,
            name: title?.displayName
                ?? (prefix == "DLVEL" ? "Oh No! More Lemmings" : directory.lastPathComponent),
            levelFilePrefix: prefix,
            campaign: campaign,
            groundStyles: groundStyles,
            specialIndices: specialIndices)
    }
}
