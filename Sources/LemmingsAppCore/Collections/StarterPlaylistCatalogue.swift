import Foundation
import NxlvKit

public struct StarterPlaylistRoute: Identifiable, Sendable {
    public enum Kind: Sendable { case collection, tinyJourney }

    public let id: UUID
    public let key: String
    public let kind: Kind
    public let identities: [LevelCatalogueIdentity]

    public var poolID: String { "starter-playlist-v1:" + key }

    public var title: String {
        switch key {
        case "first-shift": L10n.text("First Shift")
        case "permit-to-build": L10n.text("Permit to Build")
        case "below-street-level": L10n.text("Below Street Level")
        case "open-starter": L10n.text("Open Starter")
        case "tame": L10n.text("The Tame Shift")
        case "holiday-fun": L10n.text("Holiday Fun")
        default: key
        }
    }

    fileprivate init(id: String, key: String, kind: Kind, identities: [LevelCatalogueIdentity]) {
        self.id = UUID(uuidString: id)!
        self.key = key
        self.kind = kind
        self.identities = identities
    }

    public func matches(_ entries: [LevelPlaylistEntry]) -> Bool {
        entries.map(\.identity) == identities
    }

    public func playlist(resolving resolve: (LevelCatalogueIdentity) -> LevelPlaylistEntry?) -> LevelPlaylist? {
        var entries: [LevelPlaylistEntry] = []
        for identity in identities {
            guard let entry = resolve(identity), entry.identity == identity else { return nil }
            entries.append(entry)
        }
        return try? LevelPlaylist(id: id, name: title, entries: entries)
    }

    public func run(playlist: LevelPlaylist) throws -> LevelSequenceRun {
        guard playlist.id == id, matches(playlist.entries) else { throw LevelPlaylistError.invalidSequence }
        return try LevelSequenceRun.playlist(playlist, pool: .init(id: poolID, summary: title))
    }
}

public enum StarterPlaylistCatalogue {
    /// The scanned catalogue ID for the verified project-authored levels.
    public static let authoredPackID = "scanned-LEVEL-3"

    private static let classicPackID = "lemmings-LEVEL-120"
    private static let ohNoPackID = "ohNoMoreLemmings-DLVEL-100"
    private static let fun = ClassicCampaignDefinition.originalDOSLemmings.ranks[0]
    private static let tame = ClassicCampaignDefinition.ohNoMoreLemmings.ranks[0]

    public static let routes: [StarterPlaylistRoute] = [
        .init(id: "F9811767-1383-4DDC-AA01-000000000001", key: "first-shift", kind: .tinyJourney,
            identities: classic([1, 2, 3])),
        .init(id: "F9811767-1383-4DDC-AA01-000000000002", key: "permit-to-build", kind: .tinyJourney,
            identities: classic([5, 7]) + ohNo([14])),
        .init(id: "F9811767-1383-4DDC-AA01-000000000003", key: "below-street-level", kind: .tinyJourney,
            identities: ohNo([4, 6, 10, 17])),
        .init(id: "F9811767-1383-4DDC-AA01-000000000004", key: "open-starter", kind: .tinyJourney,
            identities: (0..<3).map { identity(pack: authoredPackID, rank: "All", index: $0, archive: 0, section: $0) }),
        .init(id: "F9811767-1383-4DDC-AA01-000000000005", key: "tame", kind: .collection,
            identities: ohNo(Array(1...tame.order.count))),
        .init(id: "F9811767-1383-4DDC-AA01-000000000006", key: "holiday-fun", kind: .collection,
            identities: holidayFun),
    ]

    /// Allow locked levels only in the complete ordered route from this catalogue.
    public static func permitsLocked(_ entry: LevelPlaylistEntry, in run: LevelSequenceRun) -> Bool {
        guard run.algorithm == nil, run.seed == nil,
              let route = routes.first(where: { $0.poolID == run.pool.id && run.source == .playlist($0.id) }),
              route.matches(run.entries) else { return false }
        return run.entries.contains(entry)
    }

    private static func classic(_ numbers: [Int]) -> [LevelCatalogueIdentity] {
        orderedRank(numbers, pack: classicPackID, rank: fun)
    }

    private static func ohNo(_ numbers: [Int]) -> [LevelCatalogueIdentity] {
        orderedRank(numbers, pack: ohNoPackID, rank: tame)
    }

    private static func orderedRank(_ numbers: [Int], pack: String, rank: ClassicRankDefinition) -> [LevelCatalogueIdentity] {
        numbers.map { number in
            let index = number - 1
            let reference = abs(rank.order[index])
            return identity(pack: pack, rank: rank.name, index: index, archive: reference / 10, section: reference % 10)
        }
    }

    private static let holidayFun: [LevelCatalogueIdentity] = [
        ("xmasLemmings1991-LEVEL-4", "Xmas", 0, 4),
        ("xmasLemmings1992-LEVEL-4", "Xmas", 0, 4),
        ("holidayLemmings1993-MACLEVL-32", "Flurry", 4, 16),
        ("holidayLemmings1994-MACLEVL-32", "Frost", 0, 16),
    ].flatMap { pack, rank, firstArchive, count in
        (0..<count).map { index in
            identity(pack: pack, rank: rank, index: index, archive: firstArchive + index / 8, section: index % 8)
        }
    }

    private static func identity(pack: String, rank: String, index: Int, archive: Int, section: Int) -> LevelCatalogueIdentity {
        .init(engine: .classic, packID: pack, levelID: "\(index):\(rank):\(index + 1):\(archive):\(section)")
    }
}
