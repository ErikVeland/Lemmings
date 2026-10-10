import Foundation
import Testing

@testable import NxlvKit

@Suite("NeoLemmix pack library")
struct NeoLemmixPackTests {
    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func level(_ title: String, id: String? = nil) -> String {
        """
        TITLE \(title)
        \(id.map { "ID \($0)" } ?? "")
        WIDTH 160
        HEIGHT 80
        LEMMINGS 1
        SAVE_REQUIREMENT 1
        """
    }

    @Test("Manifest order, groups and stable revisions")
    func manifestPack() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoPackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let pack = temporary.appendingPathComponent("Redux")
        try write("TITLE Test Redux\nAUTHOR Test Author\n", to: pack.appendingPathComponent("info.nxmi"))
        try write("""
        $GROUP
          NAME Gentle
          FOLDER Gentle
        $END
        $GROUP
          NAME Quirky
          FOLDER Quirky
        $END
        """, to: pack.appendingPathComponent("levels.nxmi"))
        try write("LEVEL second.nxlv\nLEVEL first.nxlv\n", to: pack.appendingPathComponent("Gentle/levels.nxmi"))
        try write("LEVEL third.nxlv\n", to: pack.appendingPathComponent("Quirky/levels.nxmi"))
        try write(level("Second", id: "x0000000000000002"), to: pack.appendingPathComponent("Gentle/second.nxlv"))
        try write(level("First", id: "x0000000000000001"), to: pack.appendingPathComponent("Gentle/first.nxlv"))
        try write(level("Third", id: "x0000000000000003"), to: pack.appendingPathComponent("Quirky/third.nxlv"))

        let result = try NeoLemmixPackLibrary.discover(in: temporary)
        #expect(result.count == 1)
        #expect(result[0].title == "Test Redux")
        #expect(result[0].author == "Test Author")
        #expect(result[0].levels.map(\.title) == ["Second", "First", "Third"])
        #expect(result[0].levels.map(\.groups) == [["Gentle"], ["Gentle"], ["Quirky"]])
        #expect(result[0].levels[0].levelID == "x0000000000000002")

        let unchanged = try NeoLemmixPackLibrary.discover(in: pack)[0]
        #expect(unchanged.id == result[0].id)
        #expect(unchanged.sourceRevision == result[0].sourceRevision)
        let oldLevelRevision = unchanged.levels[0].sourceRevision
        try write(level("Second changed", id: "x0000000000000002"), to: pack.appendingPathComponent("Gentle/second.nxlv"))
        let changed = try NeoLemmixPackLibrary.discover(in: pack)[0]
        #expect(changed.id == unchanged.id)
        #expect(changed.sourceRevision != unchanged.sourceRevision)
        #expect(changed.levels[0].levelID == unchanged.levels[0].levelID)
        #expect(changed.levels[0].sourceRevision != oldLevelRevision)
    }

    @Test("Fallback order and unsafe manifests")
    func fallbackAndSafety() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoPackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try write(level("B"), to: temporary.appendingPathComponent("b.nxlv"))
        try write(level("A"), to: temporary.appendingPathComponent("a.nxlv"))
        let pack = try NeoLemmixPackLibrary.discover(in: temporary)[0]
        #expect(pack.levels.map(\.title) == ["A", "B"])
        #expect(pack.levels[0].levelID.hasPrefix("path:"))

        let unsafe = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoPackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: unsafe) }
        try write("LEVEL ../outside.nxlv\n", to: unsafe.appendingPathComponent("levels.nxmi"))
        #expect(throws: NeoLemmixPackError.self) {
            _ = try NeoLemmixPackLibrary.discover(in: unsafe)
        }

        let duplicates = FileManager.default.temporaryDirectory
            .appendingPathComponent("NeoPackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: duplicates) }
        for folder in ["One", "Two"] {
            let root = duplicates.appendingPathComponent(folder)
            try write("TITLE Same Pack\nAUTHOR Same Author\n", to: root.appendingPathComponent("info.nxmi"))
            try write(level(folder), to: root.appendingPathComponent("level.nxlv"))
        }
        #expect(throws: NeoLemmixPackError.self) {
            _ = try NeoLemmixPackLibrary.discover(in: duplicates)
        }
    }
}
