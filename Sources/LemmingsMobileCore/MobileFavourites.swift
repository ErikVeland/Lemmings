import Foundation

/// The levels a player has starred, across every pack.
public struct MobileFavourites: Equatable, Sendable {
    public struct Entry: Codable, Equatable, Hashable, Sendable {
        public let pack: String
        public let level: String
        public init(pack: String, level: String) { self.pack = pack; self.level = level }
    }

    public static let defaultsKey = "mobile.favourites"

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) { self.entries = entries }

    public static func load(from defaults: UserDefaults = .standard) -> MobileFavourites {
        guard let data = defaults.data(forKey: defaultsKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return MobileFavourites() }
        return MobileFavourites(entries: entries)
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(entries), forKey: Self.defaultsKey)
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

/// The starred levels as one library, in the order they were starred.
///
/// Each level keeps its own pack's session, so a saved run reopens in that pack.
public final class MobileFavouritesLibrary: MobileGameLibrary {
    public let levels: [MobileLevelSummary]
    public var displayName: String { "Favourites" }

    private let resolved: [(pack: String, index: Int)]
    private let libraries: [String: any MobileGameLibrary]

    public init(favourites: MobileFavourites, catalogue: MobileCatalogue) {
        var opened: [String: any MobileGameLibrary] = [:]
        var found: [(pack: String, index: Int)] = []
        var summaries: [MobileLevelSummary] = []
        for entry in favourites.entries {
            if opened[entry.pack] == nil, let pack = catalogue.pack(id: entry.pack),
               let library = try? catalogue.library(for: pack) { opened[entry.pack] = library }
            guard let library = opened[entry.pack],
                  let index = library.levels.indices.first(where: { library.levelKey(at: $0) == entry.level }),
                  let title = catalogue.pack(id: entry.pack)?.title else { continue }
            found.append((entry.pack, index))
            summaries.append(MobileLevelSummary(index: summaries.count, rank: title,
                                                number: summaries.count + 1, title: library.levels[index].title))
        }
        resolved = found
        libraries = opened
        levels = summaries
    }

    public func levelKey(at index: Int) -> String {
        guard resolved.indices.contains(index), let library = libraries[resolved[index].pack] else { return "" }
        return resolved[index].pack + "|" + library.levelKey(at: resolved[index].index)
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard resolved.indices.contains(index), let library = libraries[resolved[index].pack] else {
            throw MobileSessionError.changedLevel
        }
        let content = try library.loadLevel(at: resolved[index].index)
        return MobileLevelContent(summary: levels[index], session: content.session)
    }

    /// Where a level of this library really lives.
    public func origin(of index: Int) -> (pack: String, index: Int)? {
        resolved.indices.contains(index) ? resolved[index] : nil
    }
}
