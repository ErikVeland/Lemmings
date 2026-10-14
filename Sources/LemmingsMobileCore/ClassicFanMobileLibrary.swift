import Foundation
import NxlvKit

/// One fan or conversion pack, played with the Classic engine.
///
/// The pack supplies levels and sometimes graphics. Any graphics it does not
/// carry come from the stock release folders under `portsRoot`, exactly as on
/// the Mac. Rules that need replay evidence are selected by the archive's hash.
public final class ClassicFanMobileLibrary: MobileGameLibrary {
    /// The stock release the engine takes its lemming sprites and sounds from.
    public static let engineFolder = "lemmings_dos_1991-07-30"

    public let pack: ClassicFanPack
    public let portsRoot: URL
    public let entries: [ClassicFanPack.Entry]
    public let levels: [MobileLevelSummary]
    public var displayName: String { pack.displayName }
    public var catalogueID: String { ClassicFanPack.catalogueID(pack.url) }

    private let assets: ClassicMainDATAssets
    private let usesNativeArtwork: Bool

    public init(packURL: URL, portsRoot: URL) throws {
        pack = try ClassicFanPack(url: packURL)
        self.portsRoot = portsRoot
        usesNativeArtwork = Bundle.main.resourceURL.map { root in
            ["MacArtwork", "AmigaArtwork"].contains { kind in
                FileManager.default.fileExists(atPath: root.appendingPathComponent(kind + "/lemmings/manifest.json").path)
            }
        } ?? false
        assets = try ClassicMainDATAssets.load(from: portsRoot.appendingPathComponent(Self.engineFolder))
        let found = pack.entries()
        guard !found.isEmpty else { throw MobileSessionError.changedLevel }
        entries = found
        let name = pack.displayName
        levels = found.enumerated().map { index, entry in
            MobileLevelSummary(index: index, rank: name, number: index + 1, title: entry.label, origin: .fanMade, packName: name)
        }
    }

    public func levelKey(at index: Int) -> String {
        entries.indices.contains(index) ? entries[index].key : ""
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        return "fan/\(catalogueID)/\(pack.fingerprint.prefix(12))/\(entries[index].key)"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard entries.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = entries[index]
        let (level, styleName) = try pack.level(entry)
        let ground = try pack.groundSet(for: level, styleName: styleName, portsRoot: portsRoot, entry: entry)
        let special = try pack.specialGraphic(for: level, entry: entry, portsRoot: portsRoot)
        let artwork = usesNativeArtwork ? ClassicFanArtwork.artworkMatch(for: level, ground: ground, special: special, portsRoot: portsRoot) : nil
        return try ClassicMobileSession.makeContent(
            summary: levels[index], level: level, ground: ground, special: special, assets: assets,
            mechanics: pack.mechanics(for: entry),
            objectSemantics: .forFanLevel(level, groundSet: ground),
            clock: .golems,
            levelIdentifier: try checkpointLevelIdentifier(at: index)!,
            levelIndex: index, artworkFamily: artwork?.family, artworkMatch: artwork?.pieces)
    }
}
