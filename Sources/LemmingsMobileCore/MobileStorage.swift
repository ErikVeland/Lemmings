import Foundation

/// Saves small JSON documents with a validated backup.
///
/// Each save keeps the last good copy beside the new one. A load that finds a
/// damaged file falls back to that copy, and it keeps the damaged file for
/// inspection instead of deleting it.
public struct MobileStorage: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    /// The folder for one player's collections.
    public static func standard(profile: String) -> MobileStorage {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/Mobile", isDirectory: true)
        return MobileStorage(directory: base.appendingPathComponent(profile, isDirectory: true))
    }

    private func main(_ name: String) -> URL { directory.appendingPathComponent(name + ".json") }
    private func backup(_ name: String) -> URL { directory.appendingPathComponent(name + ".json.bak") }

    private func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    public func load<T: Codable>(_ type: T.Type, name: String) -> T? {
        let fileManager = FileManager.default
        if let value = decode(type, at: main(name)) { return value }
        // A main file that exists but does not decode is kept for inspection.
        if fileManager.fileExists(atPath: main(name).path) {
            let stamp = String(Int(Date().timeIntervalSince1970))
            try? fileManager.moveItem(at: main(name), to: directory.appendingPathComponent(name + ".invalid-" + stamp + ".json"))
        }
        return decode(type, at: backup(name))
    }

    public func save<T: Codable>(_ value: T, name: String) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        // Keep the previous copy only when it is itself valid.
        if let previous = try? Data(contentsOf: main(name)), (try? JSONDecoder().decode(T.self, from: previous)) != nil {
            try previous.write(to: backup(name), options: .atomic)
        }
        try data.write(to: main(name), options: .atomic)
    }

    /// Reads a document, importing an older copy from app defaults the first time.
    public func loadMigrating<T: Codable>(_ type: T.Type, name: String, defaults: UserDefaults, legacyKey: String) -> T? {
        if let value = load(type, name: name) { return value }
        guard let data = defaults.data(forKey: legacyKey), let value = try? JSONDecoder().decode(type, from: data) else { return nil }
        // Retain the defaults copy for older builds, including when the file save fails.
        try? save(value, name: name)
        return value
    }
}

public struct MobileProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var portrait: Int

    public init(id: String, name: String, portrait: Int = 0) {
        self.id = id; self.name = name; self.portrait = max(0, min(7, portrait))
    }

    private enum CodingKeys: String, CodingKey { case id, name, portrait }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(String.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  portrait: try values.decodeIfPresent(Int.self, forKey: .portrait) ?? 0)
    }
}

/// The players on this device. Each keeps their own collections and progress.
public struct MobileProfiles: Codable, Equatable, Sendable {
    public static let defaultID = "default"
    public static let maximum = 8

    public private(set) var players: [MobileProfile]
    public private(set) var activeID: String

    public init() {
        players = [MobileProfile(id: Self.defaultID, name: "Player 1")]
        activeID = Self.defaultID
    }

    public var active: MobileProfile { players.first { $0.id == activeID } ?? players[0] }

    /// Appended to a storage key. The first player keeps the original keys, so existing data stays theirs.
    public static func suffix(for id: String) -> String { id == defaultID ? "" : "." + id }
    public var suffix: String { Self.suffix(for: active.id) }

    private static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Player" : trimmed).prefix(20))
    }

    @discardableResult
    public mutating func add(name: String, id: String = UUID().uuidString.lowercased()) -> String? {
        guard players.count < Self.maximum, !players.contains(where: { $0.id == id }) else { return nil }
        players.append(MobileProfile(id: id, name: Self.clean(name)))
        return id
    }

    public mutating func rename(_ id: String, to name: String) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].name = Self.clean(name)
    }

    public mutating func setPortrait(_ id: String, to portrait: Int) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].portrait = max(0, min(7, portrait))
    }

    public mutating func select(_ id: String) {
        if players.contains(where: { $0.id == id }) { activeID = id }
    }

    /// Removes a player. The last player cannot be removed.
    public mutating func delete(_ id: String) {
        guard players.count > 1, let index = players.firstIndex(where: { $0.id == id }) else { return }
        players.remove(at: index)
        if activeID == id { activeID = players[0].id }
    }
}
