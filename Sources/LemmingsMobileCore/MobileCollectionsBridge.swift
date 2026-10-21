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
    public var playlists: MobilePlaylistStore { playlists(hotSeatID: store.activeRunHotSeatID) }

    public func playlists(hotSeatID: String?) -> MobilePlaylistStore {
        let lists = store.playlists.map { MobilePlaylist(id: $0.id, name: $0.name, entries: $0.entries.map(Self.mobileEntry)) }
        let saved = store.activeRun.flatMap { store.activeRunHotSeatID == hotSeatID ? store.resumableRun(id: $0.id) : nil }
            ?? store.savedRuns.first { $0.hotSeatID == hotSeatID }
        let run = saved.map { saved in
            let value = saved.run
            let source: UUID? = if case let .playlist(id) = value.source { id } else { nil }
            return MobilePlaylistRun(id: value.id, playlist: source, name: value.pool.summary, entries: value.entries.map(Self.mobileEntry),
                                     position: value.currentIndex, shuffled: value.algorithm != nil, seed: value.seed ?? 0)
        }
        return MobilePlaylistStore(playlists: lists, run: run)
    }

    public func save(favourites: MobileFavourites, recents: MobileRecents, playlists: MobilePlaylistStore,
                     hotSeatID: String? = nil) throws {
        let lists = try playlists.playlists.map { list in
            try LevelPlaylist(id: list.id, name: list.name, entries: Self.sharedEntries(list.entries))
        }
        let run = try playlists.run.map { value in
            let old = (store.activeRunHotSeatID == hotSeatID ? store.activeRun : nil)
                ?? store.savedRuns.first { $0.hotSeatID == hotSeatID }?.run
            let source: LevelSequenceSource = value.playlist.map(LevelSequenceSource.playlist) ?? .shuffleAll
            let oldEntries = old?.entries.map(Self.mobileEntry)
            let same = old?.id == value.id && old?.source == source && old?.pool.summary == value.name && oldEntries == value.entries
                && oldEntries?.map(\.sourceFingerprint) == value.entries.map(\.sourceFingerprint)
            return try LevelSequenceRun(id: value.id, source: source,
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
                catalogueRevision: "mobile-v1", sourceRevision: value.sourceFingerprint.map { "mobile-content-v1:" + $0 } ?? "mobile-v1", packNameSnapshot: value.pack,
                levelNameSnapshot: value.title ?? value.level, levelNumberSnapshot: index + 1)
        }
    }

    public static func mobileEntry(_ value: LevelPlaylistEntry) -> MobileFavourites.Entry {
        .init(pack: value.identity.packID, level: value.identity.levelID, title: value.levelNameSnapshot,
            sourceFingerprint: value.sourceRevision.hasPrefix("mobile-content-v1:")
                ? String(value.sourceRevision.dropFirst("mobile-content-v1:".count)) : nil)
    }
}
