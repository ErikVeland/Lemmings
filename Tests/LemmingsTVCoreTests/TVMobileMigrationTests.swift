import Foundation
import Testing
import LemmingsMobileCore
import LemmingsTVCore

@MainActor struct TVMobileMigrationTests {
    private func checkpoint(owner: String, scope: String? = nil, date: Date = .now) -> MobileCheckpointEnvelope {
        .init(runID: UUID(), engine: "classic", engineFingerprint: "engine", levelIdentifier: "level",
              levelIndex: 2, levelFingerprint: "fingerprint", tick: 42, selectedControl: 3,
              camera: .init(origin: .init(x: 12, y: 0), zoom: 2), payload: Data([1, 2]), savedAt: date,
              scope: scope, owner: owner)
    }

    @Test func importsOwnershipProfilesSettingsAndProgressOnce() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        var old = TVLocalState()
        let addedGuest = old.profiles.add(name: "Guest", id: "guest")
        let guest = try #require(addedGuest)
        old.profiles.setPortrait(guest, to: 5)
        old.profiles.select(guest)
        var seat = try #require(MobileHotSeat(host: MobileProfiles.defaultID, players: [guest]))
        seat.pass(to: guest)
        old.seats[seat.scope] = seat
        old.activeSeatScope = seat.scope
        old.completed[old.progressKey(source: "classic", owner: guest, scope: nil)] = [1, 4]
        old.completed[old.progressKey(source: "classic", owner: guest, scope: seat.scope)] = [3]
        old.preferences.musicEnabled = false
        old.preferences.effectsEnabled = false
        old.preferences.swapSticks = true
        old.preferences.aimSensitivity = 1.5
        old.preferences.deadZone = 0.25
        old.preferences.textScale = 1.25
        defaults.set(try JSONEncoder().encode(old), forKey: "tv.localState")
        let legacy = MobileCheckpointStore(url: root.appendingPathComponent("old/current.json"))
        let destination = MobileCheckpointStore(url: root.appendingPathComponent("new/current.json"))
        let saved = checkpoint(owner: guest, scope: seat.scope)
        try await legacy.save(saved)
        let players = MobileStorage(directory: root.appendingPathComponent("players"))
        try await TVMobileMigration.migrate(defaults: defaults, players: players, legacyCheckpoint: legacy, destination: destination)
        let migrated = try #require(players.load(MobileProfiles.self, name: "players"))
        #expect(migrated.activeID == guest)
        #expect(migrated.players.first(where: { $0.id == guest })?.portrait == 5)
        #expect(MobileHotSeatStore.load(from: players).current == seat)
        #expect(try await destination.load(owner: guest, scope: seat.scope) == saved)
        #expect(try await legacy.load() == saved)
        #expect(defaults.array(forKey: "mobile.completed.release/lemmings.guest") as? [Int] == [1, 4])
        #expect(defaults.array(forKey: "mobile.completed.release/lemmings." + seat.scope) as? [Int] == [3])
        let settings = MobileSettings.load(from: defaults)
        #expect(!settings.musicEnabled && settings.classic.soundVolume == 0 && settings.classic.controllerSwapSticks)
        #expect(!settings.pauseToAssign)
        #expect(settings.classic.interfaceSize == .large)
        #expect(TVPreferences.inputPreferences(from: defaults).aimSensitivity == 1.5)
        #expect(TVPreferences.inputPreferences(from: defaults).deadZone == 0.25)
        defaults.set([9], forKey: "mobile.completed.release/lemmings.guest")
        try await TVMobileMigration.migrate(defaults: defaults, players: players, legacyCheckpoint: legacy, destination: destination)
        #expect(defaults.array(forKey: "mobile.completed.release/lemmings.guest") as? [Int] == [9])
    }

    @Test func keepsNewerRunsAndExistingProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        var old = TVLocalState()
        old.completed[old.progressKey(source: "classic", owner: "default", scope: nil)] = [1]
        defaults.set(try JSONEncoder().encode(old), forKey: "tv.localState")
        defaults.set([2], forKey: "mobile.completed.release/lemmings")
        let legacy = MobileCheckpointStore(url: root.appendingPathComponent("old.json"))
        let destination = MobileCheckpointStore(url: root.appendingPathComponent("new.json"))
        try await legacy.save(checkpoint(owner: "default", date: .distantPast))
        let recent = checkpoint(owner: "default")
        try await destination.save(recent)
        try await TVMobileMigration.migrate(defaults: defaults,
            players: MobileStorage(directory: root.appendingPathComponent("players")), legacyCheckpoint: legacy, destination: destination)
        #expect(try await destination.load() == recent)
        #expect(defaults.array(forKey: "mobile.completed.release/lemmings") as? [Int] == [1, 2])
    }

    @Test func corruptMetadataDoesNotMarkMigrationComplete() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let bytes = Data("broken".utf8)
        defaults.set(bytes, forKey: "tv.localState")
        do {
            try await TVMobileMigration.migrate(defaults: defaults, players: MobileStorage(directory: root),
                legacyCheckpoint: MobileCheckpointStore(url: root.appendingPathComponent("old")),
                destination: MobileCheckpointStore(url: root.appendingPathComponent("new")))
            Issue.record("Corrupt legacy data must report an error")
        } catch {}
        #expect(!defaults.bool(forKey: TVMobileMigration.completionKey))
        #expect(defaults.data(forKey: "tv.localState") == bytes)
    }
}
