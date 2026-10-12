import Foundation

/// A player's levels, newest first, capped at fifty distinct levels.
public struct MobileRecents: Equatable, Sendable {
    public static let limit = 50
    public static let defaultsKey = "mobile.recents"

    public private(set) var entries: [MobileFavourites.Entry]

    public init(entries: [MobileFavourites.Entry] = []) { self.entries = entries }

    public static func load(from storage: MobileStorage, defaults: UserDefaults = .standard, legacy: Bool = true) -> MobileRecents {
        let found = storage.loadMigrating([MobileFavourites.Entry].self, name: "recents", defaults: defaults,
                                          legacyKey: legacy ? defaultsKey : "mobile.none") ?? []
        return MobileRecents(entries: Array(found.prefix(limit)))
    }

    public func save(to storage: MobileStorage) {
        try? storage.save(entries, name: "recents")
    }

    /// Replaying a level moves it to the front.
    public mutating func record(_ entry: MobileFavourites.Entry) {
        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }
}

public struct MobilePlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var entries: [MobileFavourites.Entry]

    public init(id: UUID = UUID(), name: String, entries: [MobileFavourites.Entry] = []) {
        self.id = id; self.name = name; self.entries = entries
    }
}

/// The order and position of a playlist being played.
///
/// A shuffled run keeps its seed and its fixed order, so a relaunch resumes the
/// same sequence and no level repeats within the run.
public struct MobilePlaylistRun: Codable, Equatable, Sendable {
    /// The playlist this run came from. A shuffle across all fan levels has none.
    public let playlist: UUID?
    public let name: String
    public let entries: [MobileFavourites.Entry]
    public var position: Int
    public let shuffled: Bool
    public let seed: UInt64
}

/// Ordered playlists and the one active run.
public struct MobilePlaylistStore: Codable, Equatable, Sendable {
    public static let defaultsKey = "mobile.playlists"
    public static let maximumPlaylists = 100
    public static let maximumEntries = 500

    public private(set) var playlists: [MobilePlaylist] = []
    public private(set) var run: MobilePlaylistRun?

    public init() {}

    public static func load(from storage: MobileStorage, defaults: UserDefaults = .standard, legacy: Bool = true) -> MobilePlaylistStore {
        storage.loadMigrating(MobilePlaylistStore.self, name: "playlists", defaults: defaults,
                              legacyKey: legacy ? defaultsKey : "mobile.none") ?? MobilePlaylistStore()
    }

    public func save(to storage: MobileStorage) {
        try? storage.save(self, name: "playlists")
    }

    public func playlist(_ id: UUID) -> MobilePlaylist? { playlists.first { $0.id == id } }

    // MARK: - Editing

    @discardableResult
    public mutating func create(name: String, entries: [MobileFavourites.Entry] = []) -> UUID? {
        guard playlists.count < Self.maximumPlaylists else { return nil }
        let playlist = MobilePlaylist(name: Self.clean(name), entries: Array(entries.prefix(Self.maximumEntries)))
        playlists.append(playlist)
        return playlist.id
    }

    public mutating func rename(_ id: UUID, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = Self.clean(name)
    }

    public mutating func delete(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        // Deleting a playlist also removes its saved run.
        if run?.playlist == id { run = nil }
    }

    /// Adds a level once. Returns false when it is already there or the list is full.
    @discardableResult
    public mutating func add(_ entry: MobileFavourites.Entry, to id: UUID) -> Bool {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              !playlists[index].entries.contains(entry),
              playlists[index].entries.count < Self.maximumEntries else { return false }
        playlists[index].entries.append(entry)
        return true
    }

    public mutating func remove(at position: Int, from id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              playlists[index].entries.indices.contains(position) else { return }
        playlists[index].entries.remove(at: position)
    }

    /// Moves an entry by `offset` places, stopping at either end.
    public mutating func move(at position: Int, by offset: Int, in id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              playlists[index].entries.indices.contains(position) else { return }
        let target = min(max(0, position + offset), playlists[index].entries.count - 1)
        guard target != position else { return }
        let entry = playlists[index].entries.remove(at: position)
        playlists[index].entries.insert(entry, at: target)
    }

    private static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Playlist" : trimmed).prefix(40))
    }

    // MARK: - Runs

    /// A repeatable shuffle: the same seed always gives the same order.
    public static func shuffled(_ entries: [MobileFavourites.Entry], seed: UInt64) -> [MobileFavourites.Entry] {
        var state = seed
        func next() -> UInt64 {
            // SplitMix64: small, fast and fully determined by the seed.
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        var result = entries
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            result.swapAt(index, Int(next() % UInt64(index + 1)))
        }
        return result
    }

    /// Up to `count` distinct levels from a pool, in a repeatable random order.
    public static func random(_ count: Int, from pool: [MobileFavourites.Entry], seed: UInt64) -> [MobileFavourites.Entry] {
        Array(shuffled(pool, seed: seed).prefix(max(0, count)))
    }

    @discardableResult
    public mutating func startRun(_ id: UUID, shuffle: Bool, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> MobilePlaylistRun? {
        guard let playlist = playlist(id), !playlist.entries.isEmpty else { return nil }
        let order = shuffle ? Self.shuffled(playlist.entries, seed: seed) : playlist.entries
        run = MobilePlaylistRun(playlist: id, name: playlist.name, entries: order, position: 0, shuffled: shuffle, seed: seed)
        return run
    }

    /// A run through a pool of levels, such as every installed fan level, each once.
    @discardableResult
    public mutating func startShuffleAll(_ pool: [MobileFavourites.Entry], name: String = "Shuffle all",
                                         seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> MobilePlaylistRun? {
        guard !pool.isEmpty else { return nil }
        run = MobilePlaylistRun(playlist: nil, name: name, entries: Self.shuffled(pool, seed: seed),
                                position: 0, shuffled: true, seed: seed)
        return run
    }

    public mutating func advance(to position: Int) {
        guard var current = run else { return }
        guard current.entries.indices.contains(position) else { run = nil; return }
        current.position = position
        run = current
    }

    public mutating func endRun() { run = nil }
}
