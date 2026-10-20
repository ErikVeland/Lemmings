import Foundation

/// The levels a player has starred, across every pack.
public struct MobileFavourites: Equatable, Sendable {
    public struct Entry: Codable, Equatable, Hashable, Sendable {
        public let pack: String
        public let level: String
        /// The level's name, kept so a long list can show without opening every pack.
        public var title: String?
        /// Curated copies retain the exact installed content across saved runs and shared storage.
        public let sourceFingerprint: String?
        public init(pack: String, level: String, title: String? = nil, sourceFingerprint: String? = nil) {
            self.pack = pack; self.level = level; self.title = title; self.sourceFingerprint = sourceFingerprint
        }

        public static func == (a: Entry, b: Entry) -> Bool { a.pack == b.pack && a.level == b.level }
        public func hash(into hasher: inout Hasher) { hasher.combine(pack); hasher.combine(level) }
    }

    public static let defaultsKey = "mobile.favourites"

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) { self.entries = entries }

    /// Reads a player's favourites, importing the older copy from app defaults once.
    public static func load(from storage: MobileStorage, defaults: UserDefaults = .standard, legacy: Bool = true) -> MobileFavourites {
        MobileFavourites(entries: storage.loadMigrating([Entry].self, name: "favourites", defaults: defaults,
                                                         legacyKey: legacy ? defaultsKey : "mobile.none") ?? [])
    }

    public func save(to storage: MobileStorage) {
        try? storage.save(entries, name: "favourites")
    }

    public func contains(pack: String, level: String) -> Bool {
        entries.contains(Entry(pack: pack, level: level))
    }

    /// Adds the level, or removes it when it is already starred. Returns the new state.
    @discardableResult
    public mutating func toggle(pack: String, level: String) -> Bool {
        let entry = Entry(pack: pack, level: level)
        if let index = entries.firstIndex(of: entry) { entries.remove(at: index); return false }
        entries.append(entry)
        return true
    }
}

/// A list of levels from any packs, played as one library.
///
/// Favourites, Recently Played, playlists and shuffled runs all use it. Each level
/// keeps its own pack's session, so a saved run reopens in that pack. An entry whose
/// pack or level is gone is skipped.
///
/// A long list can open `lazily`: titles come from the entries, and a pack opens only
/// when one of its levels is played.
public final class MobileListLibrary: MobileGameLibrary {
    public let levels: [MobileLevelSummary]
    public let displayName: String
    /// For each level shown, its position in the entry list this library was built from.
    public let entryIndices: [Int]

    private var resolved: [(pack: String, index: Int)]
    private var libraries: [String: any MobileGameLibrary]
    private let entries: [MobileFavourites.Entry]
    private let catalogue: MobileCatalogue
    private let lazy: Bool

    public init(entries: [MobileFavourites.Entry], name: String, catalogue: MobileCatalogue, lazy: Bool = false) {
        displayName = name
        self.entries = entries
        self.catalogue = catalogue
        self.lazy = lazy
        var opened: [String: any MobileGameLibrary] = [:]
        var found: [(pack: String, index: Int)] = []
        var summaries: [MobileLevelSummary] = []
        var sources: [Int] = []
        // Looking a pack up scans its folder, so each pack is looked up once.
        var packs: [String: MobileContentPack?] = [:]
        var fanScanned = false
        func pack(_ id: String) -> MobileContentPack? {
            if let known = packs[id] { return known }
            if !id.hasPrefix("release/") {
                // One folder scan covers every fan pack in the list.
                if !fanScanned {
                    fanScanned = true
                    for fan in catalogue.packs(in: .fan) { packs[fan.id] = .some(fan) }
                }
                if let known = packs[id] { return known }
                packs[id] = .some(nil)
                return nil
            }
            let looked = catalogue.pack(id: id)
            packs[id] = .some(looked)
            return looked
        }
        for (entryIndex, entry) in entries.enumerated() {
            if Task.isCancelled { break }
            if lazy {
                found.append((entry.pack, -1))
                sources.append(entryIndex)
                summaries.append(MobileLevelSummary(index: summaries.count, rank: pack(entry.pack)?.title ?? entry.pack,
                                                    number: summaries.count + 1, title: entry.title ?? "Level",
                                                    origin: pack(entry.pack).map { $0.family == .fan ? .fanMade : .official } ?? .unspecified,
                                                    packName: pack(entry.pack)?.title ?? ""))
                continue
            }
            if opened[entry.pack] == nil, let pack = pack(entry.pack),
               let library = try? catalogue.library(for: pack) { opened[entry.pack] = library }
            guard let library = opened[entry.pack],
                  Self.matchesSource(entry, library: library),
                  let index = library.levels.indices.first(where: { library.levelKey(at: $0) == entry.level }),
                  let title = pack(entry.pack)?.title else { continue }
            found.append((entry.pack, index))
            sources.append(entryIndex)
            summaries.append(MobileLevelSummary(index: summaries.count, rank: title,
                                                number: summaries.count + 1, title: library.levels[index].title,
                                                origin: library.levels[index].origin, packName: title))
        }
        resolved = found
        entryIndices = sources
        libraries = opened
        levels = summaries
    }

    public convenience init(favourites: MobileFavourites, catalogue: MobileCatalogue) {
        self.init(entries: favourites.entries, name: "Favourites", catalogue: catalogue)
    }

    /// Opens the entry's pack and finds its level, once.
    private func resolve(_ index: Int) -> (pack: String, index: Int, library: any MobileGameLibrary)? {
        guard resolved.indices.contains(index) else { return nil }
        let entry = entries[entryIndices[index]]
        if libraries[entry.pack] == nil, let pack = catalogue.pack(id: entry.pack), let opened = try? catalogue.library(for: pack) {
            libraries[entry.pack] = opened
        }
        guard let library = libraries[entry.pack] else { return nil }
        guard Self.matchesSource(entry, library: library) else { return nil }
        if resolved[index].index < 0 {
            guard let found = library.levels.indices.first(where: { library.levelKey(at: $0) == entry.level }) else { return nil }
            resolved[index] = (entry.pack, found)
        }
        return (entry.pack, resolved[index].index, library)
    }

    static func matchesSourceFingerprint(_ expected: String?, directory: URL) -> Bool {
        guard let expected else { return true }
        return (try? MobileContentFingerprint.digest(directory: directory)) == expected
    }

    private static func matchesSource(_ entry: MobileFavourites.Entry, library: any MobileGameLibrary) -> Bool {
        guard entry.sourceFingerprint != nil else { return true }
        guard let classic = library as? ClassicMobileLibrary else { return false }
        return matchesSourceFingerprint(entry.sourceFingerprint, directory: classic.directory)
    }

    public func levelKey(at index: Int) -> String {
        guard resolved.indices.contains(index) else { return "" }
        return entries[entryIndices[index]].pack + "|" + entries[entryIndices[index]].level
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard let target = resolve(index) else { throw MobileSessionError.changedLevel }
        return try target.library.checkpointLevelIdentifier(at: target.index)
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard let target = resolve(index) else { throw MobileSessionError.changedLevel }
        let content = try target.library.loadLevel(at: target.index)
        return MobileLevelContent(summary: levels[index], session: content.session)
    }

    /// Where a level of this list really lives.
    public func origin(of index: Int) -> (pack: String, index: Int)? {
        resolve(index).map { ($0.pack, $0.index) }
    }

    /// Completion records use the same source instance that loaded the level.
    public func resolvedOrigin(of index: Int) -> (pack: String, index: Int, library: any MobileGameLibrary)? {
        resolve(index)
    }
}

public typealias MobileFavouritesLibrary = MobileListLibrary
