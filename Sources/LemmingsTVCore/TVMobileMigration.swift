import Foundation
import LemmingsMobileCore

/// Imports the original TV shell before the shared library can create new saves.
@MainActor public enum TVMobileMigration {
    nonisolated public static let completionKey = "tv.sharedInterfaceMigration.v1"
    public static var legacyCheckpointURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UltimateLemmings/TV/Checkpoints/current.json")
    }

    /// Empty installations also finish migration. Only player data identifies a returning player.
    public static func hasLegacyPlayer(in defaults: UserDefaults, checkpointURL: URL = legacyCheckpointURL) -> Bool {
        defaults.data(forKey: "tv.localState") != nil ||
            defaults.bool(forKey: TVFrontendMigration.metadataKey) ||
            defaults.string(forKey: MobileBuildInfo.seenKey) != nil ||
            FileManager.default.fileExists(atPath: checkpointURL.path) ||
            FileManager.default.fileExists(atPath: checkpointURL.appendingPathExtension("backup").path)
    }

    public static func migrate(defaults: UserDefaults, players: MobileStorage,
                               legacyCheckpoint: MobileCheckpointStore,
                               destination: MobileCheckpointStore) async throws {
        guard !defaults.bool(forKey: completionKey) else { return }
        try TVFrontendMigration.migrateMetadata(defaults: defaults, storage: players)
        try await TVFrontendMigration.migrateCheckpoint(defaults: defaults, source: legacyCheckpoint,
                                                        destination: destination)
        defaults.set(true, forKey: completionKey)
    }
}
