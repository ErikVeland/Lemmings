import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileContentFingerprintTests {
    @Test func fingerprintIsStableAndChangesWhenAnImportedAssetChanges() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileContentFingerprint-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = root.appendingPathComponent("STYLES", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("terrain-a".utf8).write(to: nested.appendingPathComponent("BEACH.DAT"))
        try Data("sprites".utf8).write(to: root.appendingPathComponent("VLEMMS.DAT"))

        let initial = try MobileContentFingerprint.digest(directory: root)
        #expect(try MobileContentFingerprint.digest(directory: root) == initial)

        try Data("terrain-b".utf8).write(to: nested.appendingPathComponent("BEACH.DAT"))
        #expect(try MobileContentFingerprint.digest(directory: root) != initial)
    }

    @Test func fingerprintRejectsSymbolicLinks() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory
            .appendingPathComponent("MobileContentFingerprintLink-\(UUID().uuidString)", isDirectory: true)
        let outside = manager.temporaryDirectory
            .appendingPathComponent("MobileContentFingerprintOutside-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? manager.removeItem(at: root)
            try? manager.removeItem(at: outside)
        }
        try Data("outside".utf8).write(to: outside)
        try manager.createSymbolicLink(at: root.appendingPathComponent("linked.dat"), withDestinationURL: outside)

        #expect(throws: MobileContentStoreError.symbolicLink) {
            try MobileContentFingerprint.digest(directory: root)
        }
    }

    @Test func checkpointFingerprintBindsTheLevelToItsImportedContent() {
        let original = MobileContentFingerprint.levelFingerprint(content: "assets-a", level: "level-a")
        #expect(MobileContentFingerprint.levelFingerprint(content: "assets-a", level: "level-a") == original)
        #expect(MobileContentFingerprint.levelFingerprint(content: "assets-b", level: "level-a") != original)
        #expect(MobileContentFingerprint.levelFingerprint(content: "assets-a", level: "level-b") != original)
    }
}
