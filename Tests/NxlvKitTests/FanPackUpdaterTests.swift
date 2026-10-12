import Foundation
import Testing
@testable import NxlvKit

struct FanPackUpdaterTests {
    private static let packs = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Content/LevelPacks")

    @Test func parsesCatalogueAndDownloadLinks() throws {
        let list = Data(#"<a href="/levelpack/42/Cool-Pack">x</a> <a href="/levelpack/42/Cool-Pack">dup</a> <a href="/levelpack/7/Other">y</a>"#.utf8)
        let found = try FanPackUpdater.catalogue(list)
        #expect(found.map(\.id) == [42, 7])
        #expect(found[0].filename == "0042-Cool-Pack.zip")
        let page = Data(#"<a href="/levelpack/download/42/Cool-Pack?i=3">get</a>"#.utf8)
        #expect(try FanPackUpdater.downloadURL(page, pack: found[0]).absoluteString == "https://lldb.camanis.net/levelpack/download/42/Cool-Pack?i=3")
        #expect(throws: FanPackUpdater.Failure.self) { try FanPackUpdater.catalogue(Data("nothing".utf8)) }
    }

    @Test func installsOnlyMissingValidPacks() async throws {
        let real = try #require(try FileManager.default.contentsOfDirectory(at: Self.packs, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zip" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.first)
        let archive = try Data(contentsOf: real)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("fan-updates-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let installedID = try #require(ClassicFanPack.packID(real))
        let list = Data(("""
            <a href="/levelpack/\(installedID)/Installed">a</a>
            <a href="/levelpack/90001/New-One">b</a>
            <a href="/levelpack/90002/Broken">c</a>
            """).utf8)
        let updater = FanPackUpdater(delay: 0) { url, _ in
            let path = url.absoluteString
            if path.contains("/list") { return list }
            if path.contains("download/90001") { return archive }
            if path.contains("download/90002") { return Data("not a zip".utf8) }
            if path.hasSuffix("/90001/New-One") { return Data(#"<a href="/levelpack/download/90001/New-One">get</a>"#.utf8) }
            if path.hasSuffix("/90002/Broken") { return Data(#"<a href="/levelpack/download/90002/Broken">get</a>"#.utf8) }
            throw FanPackUpdater.Failure.response
        }
        let outcome = await updater.check(existing: [real], destination: destination)
        #expect(outcome.added == 1)
        #expect(outcome.unavailable)   // the broken pack is skipped, and the check reports it
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("90001-New-One.zip").path))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("90002-Broken.zip").path))
        #expect((outcome.counts["90001-New-One.zip"] ?? 0) > 0)
        // A second check finds nothing new.
        let again = await updater.check(existing: [real, destination.appendingPathComponent("90001-New-One.zip")], destination: destination)
        #expect(again.added == 0)
    }
}
