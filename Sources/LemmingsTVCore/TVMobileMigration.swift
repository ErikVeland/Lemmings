import Foundation
import LemmingsMobileCore

/// Imports the original TV shell before the shared library can create new saves.
@MainActor public enum TVMobileMigration {
    nonisolated public static let completionKey = "tv.sharedInterfaceMigration.v1"
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
