import Foundation
import LemmingsAppCore
import NxlvKit

/// Resolves curated Classic routes against the installed release libraries.
public enum MobileStarterPlaylists {
    public static func hasSources(for route: StarterPlaylistRoute, in catalogue: MobileCatalogue) -> Bool {
        let sourceIDs = Set(route.identities.map(\.packID))
        return sourceIDs.allSatisfy { sourceID in
            packID(for: sourceID).flatMap(catalogue.pack(id:)) != nil
        }
    }

    public static func playlist(for route: StarterPlaylistRoute, portsRoot: URL) throws -> MobilePlaylist {
        let catalogue = MobileCatalogue(portsRoot: portsRoot)
        var sources: [String: (pack: MobileContentPack, library: ClassicMobileLibrary, fingerprint: String)] = [:]
        let entries = try route.identities.map { identity -> MobileFavourites.Entry in
            try Task.checkCancellation()
            guard identity.engine == .classic else { throw MobileSessionError.journeyEngineUnavailable }
            if sources[identity.packID] == nil {
                guard let id = packID(for: identity.packID), let pack = catalogue.pack(id: id),
                      let library = try catalogue.library(for: pack) as? ClassicMobileLibrary,
                      library.dataSet.identifierKey == identity.packID else { throw MobileSessionError.changedLevel }
                let fingerprint = try MobileContentFingerprint.digest(directory: library.directory)
                sources[identity.packID] = (pack, library, fingerprint)
            }
            guard let source = sources[identity.packID],
                  let index = Int(identity.levelID.prefix(while: { $0 != ":" })),
                  source.library.levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
            let level = source.library.dataSet.campaign.levels[index]
            let key = "\(index):\(level.rank):\(level.number):\(level.archiveFile):\(level.archiveSection)"
            guard key == identity.levelID else { throw MobileSessionError.changedLevel }
            return MobileFavourites.Entry(pack: source.pack.id, level: source.library.levelKey(at: index),
                title: source.library.levels[index].title, sourceFingerprint: source.fingerprint)
        }
        return MobilePlaylist(id: route.id, name: route.title, entries: entries)
    }

    private static func packID(for sourceID: String) -> String? {
        if sourceID == StarterPlaylistCatalogue.authoredPackID { return "authored/" + GameStarterContent.identifier }
        guard let name = sourceID.split(separator: "-").first,
              let title = ClassicTitle(rawValue: String(name)) else { return nil }
        return "release/" + title.rawValue
    }
}
