import Foundation
import XCTest
@testable import LemmingsAppCore

final class GameAssetPackTests: XCTestCase {
    func testLicenceIdentifiesTheOriginalGameBeforeRestoration() {
        for title in ["“Lemmings”", "„Lemmings“", "«Lemmings»", "\"LEMMINGS\""] {
            XCTAssertEqual(GamePresentationText.display("Ultimate Lemmings: " + title, usesLemmixNames: true),
                           "Ultimate Lemmix: " + title)
        }
    }

    func testMirrorOrderAfterVerificationFails() async throws {
        var hosts: [String] = []
        let result = try await GameAssetPack.withDownloadFallback { source in
            hosts.append(source.host ?? "")
            if hosts.count == 1 { throw GameAssetPack.Failure.invalid }
            return source
        }
        XCTAssertEqual(hosts, ["archive.org", "github.com"])
        XCTAssertEqual(result.lastPathComponent, "Ultimate-Lemmix-Restoration-Game-Assets.zip")
    }

    func testCancellationSkipsFallback() async {
        let task = Task {
            var attempts = 0
            do {
                _ = try await GameAssetPack.withDownloadFallback { _ in
                    attempts += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    throw URLError(.cancelled)
                }
                XCTFail("The cancelled download succeeded.")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            return attempts
        }
        let attempts = await task.value
        XCTAssertEqual(attempts, 1)
    }

    #if os(iOS) || os(tvOS)
    func testRestoreKeepsBundledFanRuntime() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let base = root.appendingPathComponent("Base", isDirectory: true)
        let source = root.appendingPathComponent("Import", isDirectory: true)
        let runtime = "FanRuntime/holiday_native_1994/GROUND2O.DAT"
        let file = base.appendingPathComponent(runtime)
        try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("abc".utf8)
        try data.write(to: file)
        let inventory = """
        {"schemaVersion":1,"kind":"ultimate-lemmix-trusted-base-data","files":[
          {"path":"\(runtime)","bytes":3,"sha256":"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"}]}
        """
        try Data(inventory.utf8).write(to: base.appendingPathComponent(OwnedResourceLibrary.trustedBaseInventoryName))
        let music = source.appendingPathComponent("Music/example.dat")
        try manager.createDirectory(at: music.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: music)

        let library = OwnedResourceLibrary(root: root.appendingPathComponent("Installed"), bundledResources: base)
        let receipt = try library.install(directory: source)
        XCTAssertEqual(try Data(contentsOf: receipt.resourcesDirectory.appendingPathComponent(runtime)), data)
        XCTAssertEqual(try library.verifyInstalled()?.contentID, receipt.contentID)
    }
    #endif

    func testIncompleteDownloadDoesNotReachImporter() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Incomplete transfer".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try GameAssetPack.verifyArchive(file)) { XCTAssertEqual($0 as? GameAssetPack.Failure, .invalid) }
    }
}
