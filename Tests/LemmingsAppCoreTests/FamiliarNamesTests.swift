import Foundation
import Darwin
import Testing
@testable import LemmingsAppCore

struct FamiliarNamesTests {
    @Test func normalisesGivenNamesWithoutGuessingSurnames() {
        #expect(FamiliarNamesStore.typed("  Sarah, sarah; Émile\nE\u{301}mile, Anne Marie, Anne-Marie, , 李")
            == ["Sarah", "Émile", "Anne Marie", "Anne-Marie", "李"])
        #expect(FamiliarNamesStore.unique(["Jean\t Luc", "Jean Luc", "\0"]) == ["Jean Luc"])
    }
    @Test func frozenCohortsSurviveEditsRelaunchAndForget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = FamiliarNamesStore(directory: root)
        #expect(try first.names(for: "unseen") == [])
        #expect(!FileManager.default.fileExists(atPath: root.path))
        try first.replace(with: ["Sarah", "Alex", "SARAH"])
        #expect(try first.names(for: "classic") == ["Sarah", "Alex"])
        try first.replace(with: ["Morgan"])
        #expect(try first.names(for: "classic") == ["Sarah", "Alex"])
        #expect(try first.names(for: "lemmings2") == ["Morgan"])
        let reloaded = FamiliarNamesStore(directory: root)
        #expect(try reloaded.names(for: "classic") == ["Sarah", "Alex"])
        #expect(try reloaded.names() == ["Morgan"])
        #if os(macOS)
        // Foundation's readback returns false on this SDK despite the Time Machine
        // exclusion being present. Verify the persisted exclusion attribute itself.
        let excluded = root.path.withCString { getxattr($0, "com.apple.metadata:com_apple_backup_excludeItem", nil, 0, 0, 0) }
        #expect(excluded > 0)
        #else
        #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #endif
        try reloaded.forget()
        #expect(!FileManager.default.fileExists(atPath: root.path))
        #expect(try reloaded.names(for: "classic") == [])
        #expect(try FamiliarNamesStore(directory: root).names() == [])
        try reloaded.replace(with: ["Jo"])
        #expect(try reloaded.names(for: "classic") == ["Jo"])
    }
    @Test func corruptDataIsNotSilentlyOverwrittenAndCanBeForgotten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("names-v1.json")
        try Data("damaged".utf8).write(to: file)
        let store = FamiliarNamesStore(directory: root)
        #expect(throws: (any Error).self) { try store.replace(with: ["Alex"]) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "damaged")
        try store.forget()
        #expect(try store.names() == [])
    }
}
