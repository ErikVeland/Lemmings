import CryptoKit
import Foundation
import Testing
@testable import LemmingsAppCore

/// The Mac must read the same files at the same paths after the move.
struct AppStorageTests {
    /// The Application Support folder that the Mac stores used before the move.
    private static var legacySupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    #if os(macOS)
    @Test func testMacPathsAreUnchanged() {
        let storage = AppStorage.current()
        let legacy = Self.legacySupport
        #expect(storage.applicationSupport == legacy.appendingPathComponent("Ultimate Lemmings"))
        #expect(storage.resources == Bundle.main.resourceURL)
        #expect(storage.defaults == UserDefaults.standard)
        #expect(storage.isPreviewBuild == (Bundle.main.bundleIdentifier?.contains("preview") == true))
        #expect(storage.isIntegrationTestBuild
            == (Bundle.main.bundleIdentifier?.contains("integration-tests") == true))

        // ArcadeStore.swift:179 before the move.
        let preview = Bundle.main.bundleIdentifier?.contains("preview") == true ? "Arcade Preview" : "Arcade"
        #expect(ArcadeStore.recordsFile(storage: storage).path
            == legacy.appendingPathComponent("Ultimate Lemmings/\(preview)/records-v1.json").path)
        // RunRecovery.swift:242 before the move.
        #expect(RunRecoveryStore(storage: storage).directory.path
            == legacy.appendingPathComponent("Ultimate Lemmings/Checkpoints").path)
        // LevelPlaylistStore.swift:175 before the move.
        let identity = SHA256.hash(data: Data("player".utf8)).map { String(format: "%02x", $0) }.joined()
        #expect(LevelPlaylistStore.fileURL(profileID: "player", storage: storage).path
            == legacy.appendingPathComponent("Ultimate Lemmings/Playlists", isDirectory: true)
                .appendingPathComponent(identity + ".json").path)
        #expect(DifficultyLibrary.directory(storage: storage).path
            == legacy.appendingPathComponent("Ultimate Lemmings/Difficulty", isDirectory: true).path)
        #expect(ClassicRouteRecorder.folder(storage: storage).path
            == legacy.appendingPathComponent("Ultimate Lemmings/ClassicRoutes", isDirectory: true).path)
    }
    #endif

    @Test func previewBuildKeepsItsOwnRecords() throws {
        let storage = try AppStorage.temporary(named: "preview")
        defer { storage.removeTemporaryFiles() }
        let preview = AppStorage(applicationSupport: storage.applicationSupport, resources: storage.resources,
                                 defaults: storage.defaults, isPreviewBuild: true)
        #expect(ArcadeStore.recordsFile(storage: storage)
            == storage.applicationSupport.appendingPathComponent("Arcade/records-v1.json"))
        #expect(ArcadeStore.recordsFile(storage: preview)
            == storage.applicationSupport.appendingPathComponent("Arcade Preview/records-v1.json"))
    }

    @Test func integrationTestBuildsUseTemporaryFolders() throws {
        let storage = try AppStorage.temporary(named: "integration")
        defer { storage.removeTemporaryFiles() }
        let integration = AppStorage(applicationSupport: storage.applicationSupport, resources: storage.resources,
                                     defaults: storage.defaults, isIntegrationTestBuild: true)
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let checkpoints = RunRecoveryStore(storage: integration).directory
        #expect(checkpoints.standardizedFileURL.path.hasPrefix(temporary))
        #expect(checkpoints.lastPathComponent.hasPrefix("RunRecovery-"))
        #expect(ClassicRouteRecorder.folder(storage: integration)
            == FileManager.default.temporaryDirectory.appendingPathComponent("LemmingsIntegrationClassicRoutes"))
        #expect(RunRecoveryStore(storage: storage).directory
            == storage.applicationSupport.appendingPathComponent("Checkpoints"))
    }

    @Test func temporaryStorageIsIsolated() throws {
        let first = try AppStorage.temporary(named: "first")
        let second = try AppStorage.temporary(named: "first")
        defer { first.removeTemporaryFiles(); second.removeTemporaryFiles() }
        #expect(first.applicationSupport != second.applicationSupport)
        #expect(FileManager.default.fileExists(atPath: first.applicationSupport.path))
        #expect(FileManager.default.fileExists(atPath: first.resources.path))
        #expect(!first.applicationSupport.path.hasPrefix(Self.legacySupport.path))
        first.defaults.set("value", forKey: "AppStorageTests.key")
        #expect(second.defaults.string(forKey: "AppStorageTests.key") == nil)
        #expect(UserDefaults.standard.string(forKey: "AppStorageTests.key") == nil)
        #expect(!first.isPreviewBuild)
        #expect(!first.isIntegrationTestBuild)
    }
}
