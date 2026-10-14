import Foundation
import LemmingsMobileCore

/// A portable off-device copy of TV saves; commercial content and credentials are excluded.
public struct TVSaveBackup: Codable, Sendable {
    public static let maximumBytes = 64 * 1_024 * 1_024
    private static let namespaces = ["Mobile", "Playlists", "Arcade", "Arcade Preview", "iOS/Checkpoints"]
    public var version = 1
    public let files: [String: Data]
    public let preferences: [String: Data]

    public init(files: [String: Data], preferences: [String: Data]) {
        self.files = files; self.preferences = preferences
    }

    private static func allowedFile(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.count <= 20 && parts.allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains(":") && !$0.contains("\0")
        } && namespaces.contains { path.hasPrefix($0 + "/") }
            && ["json", "backup", "bak"].contains(URL(fileURLWithPath: path).pathExtension)
    }

    private static func allowedPreference(_ key: String) -> Bool {
        key.hasPrefix("mobile.completed.") || [MobileSettings.defaultsKey, TVPreferences.inputDefaultsKey,
            "tv.mobile.players.players", "tv.mobile.players.hotseat", "tv.localState",
            TVFrontendMigration.metadataKey, TVFrontendMigration.checkpointKey,
            TVMobileMigration.completionKey].contains(key)
    }

    public func validated() throws -> Self {
        guard version == 1, files.count <= 2_000, preferences.count <= 10_000,
              files.keys.allSatisfy(Self.allowedFile), preferences.keys.allSatisfy(Self.allowedPreference),
              files.values.reduce(0, { $0 + $1.count }) + preferences.values.reduce(0, { $0 + $1.count }) <= Self.maximumBytes else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for (key, data) in preferences {
            guard let wrapper = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let value = wrapper["value"] else { throw CocoaError(.fileReadCorruptFile) }
            if key == "tv.mobile.players.players" {
                guard let profileData = value as? Data else { throw CocoaError(.fileReadCorruptFile) }
                try Self.validateProfiles(profileData)
            }
        }
        for path in ["Mobile/_players/players.json", "Mobile/_players/players.json.bak"] {
            if let data = files[path] { try Self.validateProfiles(data) }
        }
        return self
    }

    private static func validateProfiles(_ data: Data) throws {
        let profiles = try JSONDecoder().decode(MobileProfiles.self, from: data)
        let ids = Set(profiles.players.map(\.id))
        guard !ids.isEmpty, ids.count == profiles.players.count, ids.count <= MobileProfiles.maximum,
              ids.contains(profiles.activeID) else { throw CocoaError(.fileReadCorruptFile) }
    }

    public func encoded() throws -> Data {
        let data = try JSONEncoder().encode(validated())
        guard data.count <= Self.maximumBytes else { throw MobileCheckpointError.tooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw MobileCheckpointError.tooLarge }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }

    @MainActor public static func capture(root: URL, defaults: UserDefaults) throws -> Self {
        try capture(root: root, preferences: capturePreferences(defaults: defaults))
    }

    @MainActor public static func capturePreferences(defaults: UserDefaults) throws -> [String: Data] {
        var preferences: [String: Data] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where allowedPreference(key) {
            preferences[key] = try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
        }
        return preferences
    }

    public static func capture(root: URL, preferences: [String: Data]) throws -> Self {
        let root = root.resolvingSymlinksInPath()
        var files: [String: Data] = [:]
        let manager = FileManager.default
        for namespace in namespaces {
            let folder = root.appendingPathComponent(namespace)
            guard let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else { continue }
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
                guard values.isRegularFile == true else { continue }
                // Foundation may enumerate /private/var for a root expressed as /var.
                let path = namespace + "/" + url.pathComponents.suffix(enumerator.level).joined(separator: "/")
                guard allowedFile(path) else { continue }
                guard (values.fileSize ?? maximumBytes + 1) <= maximumBytes else { throw MobileCheckpointError.tooLarge }
                files[path] = try Data(contentsOf: url)
                guard files.count <= 2_000, files.values.reduce(0, { $0 + $1.count }) <= maximumBytes else { throw MobileCheckpointError.tooLarge }
            }
        }
        return try Self(files: files, preferences: preferences).validated()
    }

    /// Stages all files before replacing save folders, and retains the previous folders.
    @MainActor public func restore(root: URL, defaults: UserDefaults) throws {
        let archive = try validated()
        let manager = FileManager.default
        let staging = root.deletingLastPathComponent().appendingPathComponent("TVRestore-" + UUID().uuidString)
        let previous = root.deletingLastPathComponent().appendingPathComponent("TVBeforeRestore-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        var decoded: [String: Any] = [:]
        for (key, data) in archive.preferences {
            guard let wrapper = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let value = wrapper["value"] else { throw CocoaError(.fileReadCorruptFile) }
            decoded[key] = value
        }
        for (path, data) in archive.files {
            let target = staging.appendingPathComponent(path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        }
        var replaced: [String] = []
        var saved: [String] = []
        do {
            for namespace in Self.namespaces {
                let incoming = staging.appendingPathComponent(namespace)
                guard manager.fileExists(atPath: incoming.path) else { continue }
                let destination = root.appendingPathComponent(namespace)
                let old = previous.appendingPathComponent(namespace)
                if manager.fileExists(atPath: destination.path) {
                    let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey])
                    guard values.isSymbolicLink != true else { throw CocoaError(.fileReadCorruptFile) }
                    try manager.createDirectory(at: old.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try manager.moveItem(at: destination, to: old)
                    saved.append(namespace)
                }
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try manager.moveItem(at: incoming, to: destination)
                replaced.append(namespace)
            }
        } catch {
            for namespace in replaced { try? manager.removeItem(at: root.appendingPathComponent(namespace)) }
            for namespace in saved { try? manager.moveItem(at: previous.appendingPathComponent(namespace), to: root.appendingPathComponent(namespace)) }
            throw error
        }
        for (key, value) in decoded { defaults.set(value, forKey: key) }
    }
}
