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
        // ArcadeStore.swift:179, RunRecovery.swift:242 and LevelPlaylistStore.swift:175 before the move.
        for relative in ["Arcade/records-v1.json", "Checkpoints", "Playlists"] {
            #expect(storage.applicationSupport.appendingPathComponent(relative).path
                == legacy.appendingPathComponent("Ultimate Lemmings/" + relative).path)
        }
    }
    #endif

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
