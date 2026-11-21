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

    func testIncompleteDownloadDoesNotReachImporter() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Incomplete transfer".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try GameAssetPack.verifyArchive(file)) { XCTAssertEqual($0 as? GameAssetPack.Failure, .invalid) }
    }
}
