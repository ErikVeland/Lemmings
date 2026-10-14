import Foundation
import LemmingsMobileCore

/// Imports the original TV shell's state without deleting its downgrade copy.
@MainActor public enum TVFrontendMigration {
    nonisolated public static let metadataKey = "tv.sharedFrontend.metadata.v1"
    nonisolated public static let checkpointKey = "tv.sharedFrontend.checkpoint.v1"

    public static func migrateMetadata(defaults: UserDefaults, storage: MobileStorage) throws {
        guard !defaults.bool(forKey: metadataKey),
              let bytes = defaults.data(forKey: "tv.localState") else { return }
        let old = try JSONDecoder().decode(TVLocalState.self, from: bytes)
        let identifiers = Set(old.profiles.players.map(\.id))
        guard !identifiers.isEmpty, identifiers.count == old.profiles.players.count,
              identifiers.contains(old.profiles.activeID), old.seats.values.allSatisfy({
                  $0.players.count >= 2 && Set($0.players).count == $0.players.count
                      && $0.players.contains($0.host) && $0.players.contains($0.turn)
                      && $0.players.allSatisfy(identifiers.contains)
              }) else { throw CocoaError(.fileReadCorruptFile) }
        var profiles = storage.load(MobileProfiles.self, name: "players") ?? old.profiles
        for player in old.profiles.players where !profiles.players.contains(where: { $0.id == player.id }) {
            guard profiles.add(name: player.name, id: player.id) != nil else {
                throw CocoaError(.fileWriteOutOfSpace)
            }
            profiles.setPortrait(player.id, to: player.portrait)
        }
        var seats = MobileHotSeatStore.load(from: storage)
        seats.importLegacySessions(Array(old.seats.values), activeScope: old.activeSeatScope)
        // Both writes must succeed before the migration marker advances.
        try storage.save(profiles, name: "players")
        try seats.save(to: storage)
        for (key, completed) in old.completed {
            guard key.hasPrefix("classic:") else { continue }
            let scope = String(key.dropFirst("classic:".count))
            let suffix: String
            if scope.hasPrefix("solo.") { suffix = MobileProfiles.suffix(for: String(scope.dropFirst(5))) }
            else if scope.hasPrefix("hotseat.") { suffix = "." + scope }
            else { continue }
            let destination = "mobile.completed.release/lemmings" + suffix
            let existing = Set(defaults.array(forKey: destination) as? [Int] ?? [])
            defaults.set(Array(existing.union(completed.filter { (0..<120).contains($0) })).sorted(), forKey: destination)
        }
        if defaults.data(forKey: MobileSettings.defaultsKey) == nil {
            var settings = MobileSettings(pauseToAssign: old.preferences.planningOnSkillChange,
                                          musicEnabled: old.preferences.musicEnabled)
            settings.classic.controllerSwapSticks = old.preferences.swapSticks
            settings.classic.controllerMappings = old.preferences.validated.mappings
            settings.classic.interfaceSize = old.preferences.validated.textScale > 1 ? .large : .standard
            if !old.preferences.effectsEnabled { settings.classic.soundVolume = 0 }
            settings.save(to: defaults)
        }
        if defaults.data(forKey: TVPreferences.inputDefaultsKey) == nil {
            old.preferences.saveInputPreferences(to: defaults)
        }
        defaults.set(true, forKey: metadataKey)
    }

    public static func migrateCheckpoint(defaults: UserDefaults, source: MobileCheckpointStore,
                                         destination: MobileCheckpointStore) async throws {
        guard !defaults.bool(forKey: checkpointKey) else { return }
        if let old = try await source.load() {
            // Never replace a run already created by the shared frontend.
            if try await destination.load(owner: old.owner ?? MobileProfiles.defaultID, scope: old.scope) == nil {
                try await destination.save(old)
            }
        }
        defaults.set(true, forKey: checkpointKey)
    }
}
