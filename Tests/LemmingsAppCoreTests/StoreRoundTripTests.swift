import CryptoKit
import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

/// Each store reads a file in the Mac format, changes it and writes the same bytes as the Mac encoder.
@MainActor struct StoreRoundTripTests {
    private static func sortedEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    @Test func arcadeRecordsRoundTripInMacFormat() throws {
        let storage = try AppStorage.temporary(named: "arcade")
        defer { storage.removeTemporaryFiles() }
        var fixture = ArcadeRecords()
        let seeded = fixture.addProfile(initials: "AAA", portrait: 1, select: true)
        let first = try #require(seeded)
        let file = ArcadeStore.recordsFile(storage: storage)
        #expect(file == storage.applicationSupport.appendingPathComponent("Arcade/records-v1.json"))
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.sortedEncoder().encode(fixture.validated()).write(to: file)

        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(store.storageError == nil)
        #expect(store.records.activeProfileID == first.id)
        let added = try #require(store.addProfile(initials: "BBB", portrait: 2, select: false))
        #expect(try Data(contentsOf: file) == Self.sortedEncoder().encode(store.records.validated()))
        #expect(FileManager.default.fileExists(atPath: file.appendingPathExtension("backup").path))

        let reopened = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(reopened.records.profile(added.id)?.initials == "BBB")
        store.turnPolicy = .atFirstFail
        #expect(storage.defaults.string(forKey: "HotSeat.turnPolicy") == "At first fail")
    }

    /// The checkpoint envelope of the Mac `RunRecoveryFile.Document`.
    private struct CheckpointEnvelope: Codable {
        var version = 1
        let payload: Data?
        let checksum: String
    }

    private static func checkpoint(runID: UUID, tick: Int) -> RunRecovery {
        RunRecovery(engine: "test", profileID: "player", runID: runID, dataSetID: "lemmings", levelIndex: 0,
                    levelFingerprint: "level", initialStateHash: "initial", tick: tick, events: [],
                    stateHash: "state-\(tick)", usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0,
                    selectedSkill: 0, scrollX: 0, scrollY: 0)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The bytes that the Mac wrote before the move.
    private static func macBytes(_ recovery: RunRecovery) throws -> Data {
        let payload = try JSONEncoder().encode(recovery)
        return try JSONEncoder().encode(CheckpointEnvelope(payload: payload, checksum: sha256(payload)))
    }

    /// The Mac encoder does not sort keys, so equal checkpoints can have different key order.
    /// Compare the decoded JSON objects and check the checksum against the written payload bytes.
    private static func expectMacFormat(_ written: Data, equals recovery: RunRecovery) throws {
        let object = try #require(try JSONSerialization.jsonObject(with: written) as? [String: Any])
        #expect(Set(object.keys) == ["version", "payload", "checksum"])
        let envelope = try JSONDecoder().decode(CheckpointEnvelope.self, from: written)
        let payload = try #require(envelope.payload)
        #expect(envelope.version == 1)
        #expect(envelope.checksum == sha256(payload))
        let expected = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recovery)) as? NSDictionary
        #expect(try JSONSerialization.jsonObject(with: payload) as? NSDictionary == expected)
    }

    @Test func checkpointsRoundTripInMacFormat() throws {
        let storage = try AppStorage.temporary(named: "checkpoints")
        defer { storage.removeTemporaryFiles() }
        let store = RunRecoveryStore(storage: storage)
        #expect(store.directory == storage.applicationSupport.appendingPathComponent("Checkpoints"))
        let runID = UUID()
        let file = store.directory.appendingPathComponent(runID.uuidString + ".json")
        let saved = Self.checkpoint(runID: runID, tick: 10)
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Self.macBytes(saved).write(to: file)

        let loaded = try #require(try store.latest(profileID: "player"))
        #expect(loaded.runID == runID && loaded.tick == 10 && loaded.stateHash == "state-10")
        let changed = Self.checkpoint(runID: runID, tick: 20)
        store.save(changed, immediately: true) { _ in }
        try store.checkSaveSucceeded()
        try Self.expectMacFormat(try Data(contentsOf: file), equals: changed)
        #expect(try RunRecoveryStore(storage: storage).latest(profileID: "player")?.tick == 20)
    }

    /// The playlist document, in the key names of the Mac `LevelPlaylistStore.Document`.
    private struct PlaylistDocument: Encodable {
        let version: Int
        let playlists: [LevelPlaylist]
        let favourites: [LevelPlaylistEntry]?
    }

    @Test func playlistsRoundTripInMacFormat() throws {
        let storage = try AppStorage.temporary(named: "playlists")
        defer { storage.removeTemporaryFiles() }
        func entry(_ number: Int) throws -> LevelPlaylistEntry {
            try LevelPlaylistEntry(identity: LevelCatalogueIdentity(engine: .classic, packID: "pack", levelID: "level-\(number)"),
                                   catalogueRevision: "catalogue", sourceRevision: "source",
                                   packNameSnapshot: "Pack", levelNameSnapshot: "Level \(number)",
                                   levelNumberSnapshot: number)
        }
        let first = try entry(1), second = try entry(2)
        let file = LevelPlaylistStore.fileURL(profileID: "player", storage: storage)
        #expect(file.deletingLastPathComponent().path == storage.applicationSupport.appendingPathComponent("Playlists").path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.sortedEncoder().encode(PlaylistDocument(version: 3, playlists: [], favourites: [first])).write(to: file)

        let store = try LevelPlaylistStore(profileID: "player", storage: storage)
        #expect(store.favourites == [first])
        try store.toggleFavourite(second)
        #expect(try Data(contentsOf: file)
            == Self.sortedEncoder().encode(PlaylistDocument(version: 3, playlists: [], favourites: [second, first])))
        #expect(try LevelPlaylistStore(profileID: "player", storage: storage).favourites == [second, first])
    }

    @Test func bundledDataLoadsFromInjectedResources() throws {
        let storage = try AppStorage.temporary(named: "resources")
        defer { storage.removeTemporaryFiles() }
        let manager = FileManager.default
        for folder in ["Hints", "Trolley"] {
            try manager.createDirectory(at: storage.resources.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try Data("engine-1\n".utf8).write(to: storage.resources.appendingPathComponent("Trolley/engine-fingerprint.txt"))
        try Data(#"{"schemaVersion":1,"engineFingerprint":"engine-1","levels":[]}"#.utf8)
            .write(to: storage.resources.appendingPathComponent("Hints/classic.json"))

        let (catalogue, engine) = try #require(LevelHintCatalogue.load(storage: storage))
        #expect(engine == "engine-1")
        #expect(catalogue.levels.isEmpty)
        #expect(RunRecovery.engineFingerprint(resources: storage.resources) == "engine-1")
        #expect(TrolleyBundledProofs.load(storage: storage) == nil)
        #expect(DifficultyLibrary.cachedProfiles(storage: storage).isEmpty)
    }

    @Test func telemetryUsesInjectedDefaults() throws {
        let storage = try AppStorage.temporary(named: "telemetry")
        defer { storage.removeTemporaryFiles() }
        let telemetry = AnonymousTelemetry(storage: storage)
        #expect(telemetry.endpoint == nil)
        telemetry.setSharing(false)
        #expect(storage.defaults.bool(forKey: AnonymousTelemetry.decidedKey))
        #expect(telemetry.consentDecided)
    }
}
