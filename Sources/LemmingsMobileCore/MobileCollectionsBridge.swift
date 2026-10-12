import Foundation
import LemmingsAppCore
import NxlvKit

/// Uses the shared collection file while retaining copies that older iPad builds can read.
@MainActor public final class MobileCollectionsBridge {
    public let store: LevelPlaylistStore
    private let mobile: MobileStorage
    private let defaults: UserDefaults
    private let marker: String

    public init(profileID: String, appStorage: AppStorage = .current(), mobileStorage: MobileStorage? = nil) throws {
        mobile = mobileStorage ?? .standard(profile: profileID)
        defaults = appStorage.defaults
        marker = "mobile.collections.shared.v1." + profileID
        store = try LevelPlaylistStore(profileID: profileID, storage: appStorage)
        if !defaults.bool(forKey: marker) {
            let legacy = profileID == MobileProfiles.defaultID
            let favourites = MobileFavourites.load(from: mobile, defaults: defaults, legacy: legacy)
            let recents = MobileRecents.load(from: mobile, defaults: defaults, legacy: legacy)
            let playlists = MobilePlaylistStore.load(from: mobile, defaults: defaults, legacy: legacy)
            // A prior shared file takes precedence after a partial upgrade.
            if store.playlists.isEmpty && store.favourites.isEmpty && store.recentlyPlayed.isEmpty && store.activeRun == nil {
                try save(favourites: favourites, recents: recents, playlists: playlists)
            }
            defaults.set(true, forKey: marker)
        }
    }

    public var favourites: MobileFavourites { .init(entries: store.favourites.map(Self.mobileEntry)) }
    public var recents: MobileRecents { .init(entries: store.recentlyPlayed.map(Self.mobileEntry)) }
    public var playlists: MobilePlaylistStore {
        let lists = store.playlists.map { MobilePlaylist(id: $0.id, name: $0.name, entries: $0.entries.map(Self.mobileEntry)) }
        let run = store.activeRun.map {
            let source: UUID? = if case let .playlist(id) = $0.source { id } else { nil }
            return MobilePlaylistRun(playlist: source, name: $0.pool.summary, entries: $0.entries.map(Self.mobileEntry),
                                     position: $0.currentIndex, shuffled: $0.algorithm != nil, seed: $0.seed ?? 0)
        }
        return MobilePlaylistStore(playlists: lists, run: run)
    }

    public func save(favourites: MobileFavourites, recents: MobileRecents, playlists: MobilePlaylistStore,
                     hotSeatID: String? = nil) throws {
        let lists = try playlists.playlists.map { list in
            try LevelPlaylist(id: list.id, name: list.name, entries: Self.sharedEntries(list.entries))
        }
        let run = try playlists.run.map { value in
            let old = store.activeRun
            let source: LevelSequenceSource = value.playlist.map(LevelSequenceSource.playlist) ?? .shuffleAll
            let same = old?.source == source && old?.pool.summary == value.name && old?.entries.map(Self.mobileEntry) == value.entries
            return try LevelSequenceRun(id: same ? old!.id : UUID(), source: source,
                pool: LevelPool(id: "mobile", summary: value.name), entries: Self.sharedEntries(value.entries),
                currentIndex: value.position, seed: value.shuffled ? value.seed : nil,
                algorithm: value.shuffled ? .splitMix64FisherYatesV1 : nil,
                createdAt: same ? old!.createdAt : Date())
        }
        try store.importMobileCollections(playlists: lists, favourites: Self.sharedEntries(favourites.entries),
                                         recents: Self.sharedEntries(recents.entries), run: run, hotSeatID: hotSeatID)
        // Shared storage is authoritative. These copies preserve downgrade compatibility.
        try mobile.save(favourites.entries, name: "favourites")
        try mobile.save(recents.entries, name: "recents")
        try mobile.save(playlists, name: "playlists")
    }

    public static func sharedEntries(_ values: [MobileFavourites.Entry]) throws -> [LevelPlaylistEntry] {
        try values.enumerated().map { index, value in
            try LevelPlaylistEntry(identity: .init(engine: .classic, packID: value.pack, levelID: value.level),
                catalogueRevision: "mobile-v1", sourceRevision: "mobile-v1", packNameSnapshot: value.pack,
                levelNameSnapshot: value.title ?? value.level, levelNumberSnapshot: index + 1)
        }
    }

    public static func mobileEntry(_ value: LevelPlaylistEntry) -> MobileFavourites.Entry {
        .init(pack: value.identity.packID, level: value.identity.levelID, title: value.levelNameSnapshot)
    }
}
