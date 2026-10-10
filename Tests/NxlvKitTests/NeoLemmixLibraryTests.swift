import Foundation
import Testing

@testable import NxlvKit

@Suite("NeoLemmix bundled and player libraries")
struct NeoLemmixLibraryTests {
    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("NeoLibraryTests-\(UUID().uuidString)")

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// A style with one terrain piece, enough for a complete resolution.
    private func style(_ name: String, in styles: URL) throws {
        let folder = styles.appendingPathComponent(name)
        try write("", to: folder.appendingPathComponent("terrain/block.png"))
    }

    private func pack(_ folder: String, title: String, levels: [(id: String, style: String)],
                      in levelsRoot: URL) throws {
        let pack = levelsRoot.appendingPathComponent(folder)
        try write("TITLE \(title)\n", to: pack.appendingPathComponent("info.nxmi"))
        for level in levels {
            try write("""
            TITLE Level \(level.id)
            ID \(level.id)
            WIDTH 160
            HEIGHT 80
            LEMMINGS 1
            SAVE_REQUIREMENT 1
            $TERRAIN
              STYLE \(level.style)
              PIECE block
              X 0
              Y 0
            $END
            """, to: pack.appendingPathComponent("\(level.id).nxlv"))
        }
    }

    @Test("Bundled packs win, and each level uses a styles root that resolves it")
    func bundledFirst() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = NeoLemmixLibrary.Source(
            levelsRoot: root.appendingPathComponent("bundle/levels"),
            stylesRoot: root.appendingPathComponent("bundle/styles"))
        let player = NeoLemmixLibrary.Source(
            levelsRoot: root.appendingPathComponent("player/levels"),
            stylesRoot: root.appendingPathComponent("player/styles"))
        try style("orig_dirt", in: bundled.stylesRoot!)
        try style("orig_dirt", in: player.stylesRoot!)
        try style("community", in: player.stylesRoot!)
        try pack("Redux", title: "Redux",
                 levels: [("x0000000000000001", "orig_dirt"), ("x0000000000000002", "community")],
                 in: bundled.levelsRoot)
        try pack("Redux", title: "Redux", levels: [("x0000000000000009", "orig_dirt")],
                 in: player.levelsRoot)
        try pack("Mine", title: "Mine", levels: [("x0000000000000003", "orig_dirt")],
                 in: player.levelsRoot)

        let bundleOnly = NeoLemmixLibrary.discover([bundled])
        #expect(bundleOnly.count == 1)
        let redux = try #require(bundleOnly.first)
        #expect(redux.stylesRoot(for: redux.pack.levels[0]) == bundled.stylesRoot)
        #expect(redux.stylesRoot(for: redux.pack.levels[1]) == nil)

        let combined = NeoLemmixLibrary.discover([bundled, player])
        #expect(combined.map(\.pack.title) == ["Redux", "Mine"])
        #expect(combined[0].pack.levels.count == 2, "The player copy must not replace the bundled pack")
        #expect(combined[0].stylesRoot(for: combined[0].pack.levels[1]) == player.stylesRoot)
        #expect(combined[1].stylesRoot(for: combined[1].pack.levels[0]) == player.stylesRoot)
    }

    @Test("A saved run finds its level by IDs after its old path is gone")
    func locateByIDs() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = NeoLemmixLibrary.Source(
            levelsRoot: root.appendingPathComponent("levels"),
            stylesRoot: root.appendingPathComponent("styles"))
        try style("orig_dirt", in: bundled.stylesRoot!)
        try pack("Redux", title: "Redux", levels: [("x0000000000000001", "orig_dirt")],
                 in: bundled.levelsRoot)
        let packID = try #require(NeoLemmixLibrary.discover([bundled]).first).pack.id

        let found = try #require(NeoLemmixLibrary.locate(
            packID: packID, levelID: "x0000000000000001", in: [bundled]))
        #expect(found.level.url.lastPathComponent == "x0000000000000001.nxlv")
        #expect(found.stylesRoot == bundled.stylesRoot)
        #expect(NeoLemmixLibrary.locate(packID: packID, levelID: "x0000000000000002", in: [bundled]) == nil)
        #expect(NeoLemmixLibrary.locate(packID: "other", levelID: "x0000000000000001", in: [bundled]) == nil)
    }
}
