import Foundation

/// Levels that shipped on one machine and never reached the DOS release,
/// gathered into a single pack.
///
/// The pack is named "Oh Yes! More Lemmings!". It exists because several
/// releases carry levels the DOS game never had, and a player who only knows
/// the DOS campaigns has no way to reach them.
///
/// What the pack holds is decided by what can actually be read off the disks:
///
/// - The Amiga two-player levels are real records in the game's own format,
///   twenty in Lemmings and ten in Oh No! More Lemmings. They are here.
/// - The Mega Drive levels Sunsoft wrote for the Japanese release are here as
///   well, converted to the DOS container format. The cartridge itself holds
///   202 level records, of which 113 appear in no DOS or Amiga release, but
///   those records carry parameters and a title only. The converted archive
///   carries the geometry too, so these can be played.
/// - The Super Nintendo "Sunsoft Special" levels are named in this project but
///   are not extracted. `SNESLevelDecoder.decodeROM` returns a fixed list
///   whatever ROM it is given, and it carries no terrain, so nothing can be
///   drawn from it. The same is true of `GenesisLevelDecoder`, whose entries
///   come from a formula. Both stay out until somebody reads real levels off
///   the cartridge.
///
/// A source is added here when its levels load with terrain, not when its name
/// is known.
public enum PortExclusivePack {
    public static let name = "Oh Yes! More Lemmings!"

    /// A group of levels within the pack, shown together and in this order.
    public struct Rank: Sendable {
        public let name: String
        public let levels: [ClassicLevel]
    }

    /// Where the Mega Drive levels sit, converted to the DOS container format.
    public static let sunsoftFolder = "Genesis-Sunsoft"
    public static let sunsoftArchive = "Genesis Sunsoft.dat"

    /// Ground numbers overlap between the original game and Oh No. Keep the
    /// level records unchanged and select the source release for each rank.
    public static func artworkDirectory(for entry: ClassicCampaignLevel, portsRoot: URL) -> URL {
        if entry.rank == "Mega Drive Sunsoft" { return portsRoot.appendingPathComponent(sunsoftFolder, isDirectory: true) }
        let release: ClassicStyleResolver.Release = entry.rank == "Oh No! More Lemmings Versus"
            ? .ohNoMore : .lemmings
        return portsRoot.appendingPathComponent(release.folders[0], isDirectory: true)
    }

    /// The conversion supplies ground metadata and its special picture. It
    /// shares the original game's planar graphics and lemming sprites.
    public static func fallbackArtworkDirectory(for entry: ClassicCampaignLevel, portsRoot: URL) -> URL? {
        entry.rank == "Mega Drive Sunsoft"
            ? portsRoot.appendingPathComponent(ClassicStyleResolver.Release.lemmings.folders[0], isDirectory: true) : nil
    }

    /// Reads the Mega Drive levels out of their converted archive.
    ///
    /// Each section of the archive is one 2048 byte level record, the same
    /// layout the DOS game uses, so `ClassicLevel` reads them unchanged.
    public static func sunsoftLevels(portsRoot: URL) throws -> [ClassicLevel] {
        let url = portsRoot
            .appendingPathComponent(sunsoftFolder, isDirectory: true)
            .appendingPathComponent(sunsoftArchive)
        guard let data = try? Data(contentsOf: url) else { return [] }
        var levels: [ClassicLevel] = []
        for section in try ClassicDATArchive.decode(data) {
            var start = 0
            while start + ClassicLevel.recordSize <= section.data.count {
                let record = section.data.subdata(
                    in: start..<(start + ClassicLevel.recordSize))
                if let level = try? ClassicLevel(data: record) { levels.append(level) }
                start += ClassicLevel.recordSize
            }
        }
        return levels
    }

    /// Builds the pack from whatever port data is installed.
    ///
    /// A release whose data is missing contributes nothing rather than failing,
    /// so the pack follows what the player has.
    public static func load(amigaRoot: URL, portsRoot: URL? = nil) throws -> [Rank] {
        let entries = (try? AmigaVersusCampaign.load(from: amigaRoot)) ?? []
        var byRank: [(name: String, levels: [ClassicLevel])] = []
        for source in AmigaVersusCampaign.sources {
            let levels = entries
                .filter { $0.source.family == source.family }
                .sorted { $0.number < $1.number }
                .map(\.level)
            guard !levels.isEmpty else { continue }
            byRank.append((name: "\(source.title) Versus", levels: levels))
        }
        // The Amiga tree sits inside the ports tree, so the parent is the
        // default place to look for the other releases.
        let ports = portsRoot ?? amigaRoot.deletingLastPathComponent()
        let sunsoft = (try? sunsoftLevels(portsRoot: ports)) ?? []
        if !sunsoft.isEmpty {
            byRank.append((name: "Mega Drive Sunsoft", levels: sunsoft))
        }
        return byRank.map { Rank(name: $0.name, levels: $0.levels) }
    }

    /// Every level in the pack, in rank order.
    public static func allLevels(amigaRoot: URL, portsRoot: URL? = nil) throws -> [ClassicLevel] {
        try load(amigaRoot: amigaRoot, portsRoot: portsRoot).flatMap(\.levels)
    }

    /// Presents the pack as a data set the game library can list and launch.
    ///
    /// The levels are already in memory rather than in a folder of `LEVEL*.DAT`
    /// files, so this builds the campaign directly instead of scanning a
    /// directory. Ranks keep the order `load` gave them, and each level is
    /// numbered from one within its rank.
    ///
    /// Returns nothing when no port data is installed, so the library shows the
    /// pack as missing rather than as an empty game.
    public static func dataSet(amigaRoot: URL, portsRoot: URL? = nil) throws -> ClassicDataSet? {
        let ranks = try load(amigaRoot: amigaRoot, portsRoot: portsRoot)
        guard !ranks.isEmpty else { return nil }

        var campaignLevels: [ClassicCampaignLevel] = []
        for rank in ranks {
            for (index, level) in rank.levels.enumerated() {
                campaignLevels.append(ClassicCampaignLevel(
                    rank: rank.name,
                    number: index + 1,
                    // These levels come from memory, not from an archive, so
                    // the archive coordinates are not meaningful here.
                    archiveFile: 0,
                    archiveSection: campaignLevels.count,
                    usesOddTableProperties: false,
                    level: level))
            }
        }

        let styles = Set(campaignLevels.map { $0.level.groundStyle }).sorted()
        let specials = Set(campaignLevels.map { $0.level.specialStyle })
            .filter { $0 != 0 }.sorted()

        return ClassicDataSet(
            kind: .scanned,
            title: .ohYesMoreLemmings,
            name: name,
            levelFilePrefix: "OHYES",
            campaign: ClassicCampaign(name: name, levels: campaignLevels),
            groundStyles: styles,
            specialIndices: specials)
    }
}
