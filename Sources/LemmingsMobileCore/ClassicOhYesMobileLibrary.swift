import Foundation
import NxlvKit

/// Oh Yes! More Lemmings!: levels that shipped on one machine and never reached DOS.
///
/// The Amiga two-player levels and the Mega Drive levels sit in small level
/// files. Each rank draws with the stock graphics of the release it came from,
/// as on the Mac.
public final class ClassicOhYesMobileLibrary: MobileGameLibrary {
    public let portsRoot: URL
    public let dataSet: ClassicDataSet
    public let levels: [MobileLevelSummary]
    public var displayName: String { dataSet.name }

    private var assets: [URL: ClassicMainDATAssets] = [:]

    public init(portsRoot: URL) throws {
        self.portsRoot = portsRoot
        guard let found = try PortExclusivePack.dataSet(
            amigaRoot: portsRoot.appendingPathComponent("amiga_extracted", isDirectory: true), portsRoot: portsRoot) else {
            throw MobileSessionError.changedLevel
        }
        dataSet = found
        levels = found.campaign.levels.enumerated().map { index, item in
            MobileLevelSummary(index: index, rank: item.rank, number: item.number, title: item.level.title)
        }
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard dataSet.campaign.levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = dataSet.campaign.levels[index]
        let level = entry.level
        let directory = PortExclusivePack.artworkDirectory(for: entry, portsRoot: portsRoot)
        let fallback = PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: portsRoot)
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory, fallbackDirectory: fallback)
        let special: ClassicSpecialGraphic? = level.specialStyle > 0
            ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory, fallbackDirectory: fallback)
            : nil
        let assetsDirectory = fallback ?? directory
        let sprites: ClassicMainDATAssets
        if let cached = assets[assetsDirectory] { sprites = cached }
        else { sprites = try ClassicMainDATAssets.load(from: assetsDirectory); assets[assetsDirectory] = sprites }
        return try ClassicMobileSession.makeContent(
            summary: levels[index], level: level, ground: ground, special: special, assets: sprites,
            mechanics: ClassicDOSMechanics(title: dataSet.title, rank: entry.rank),
            objectSemantics: .dos,
            levelIdentifier: "\(dataSet.identifierKey)/\(entry.rank)/\(entry.number)",
            levelIndex: index, artworkFamily: assetsDirectory.lastPathComponent.lowercased().contains("oh_no") ? "ohno" : "lemmings")
    }
}
