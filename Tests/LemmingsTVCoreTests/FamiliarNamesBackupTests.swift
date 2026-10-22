import Foundation
import Testing
import LemmingsAppCore
import LemmingsTVCore

struct FamiliarNamesBackupTests {
    @Test func portableTVBackupsExcludeFamiliarNamesAndAssignments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FamiliarNamesStore(directory: root.appendingPathComponent("Private Familiar Names"))
        try store.replace(with: ["PrivateName"])
        _ = try store.names(for: "classic:level:1")
        let backup = try TVSaveBackup.capture(root: root, preferences: [:])
        #expect(backup.files.isEmpty)
        #expect(!String(decoding: try backup.encoded(), as: UTF8.self).contains("PrivateName"))
        #expect(throws: (any Error).self) {
            try TVSaveBackup(files: ["Private Familiar Names/names-v1.json": Data("{}".utf8)], preferences: [:]).validated()
        }
    }
}
