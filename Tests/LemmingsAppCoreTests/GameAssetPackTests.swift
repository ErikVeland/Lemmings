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

    func testIncompleteDownloadDoesNotReachImporter() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Incomplete transfer".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try GameAssetPack.installArchive(file) { _ in
            XCTFail("An incomplete download reached the resource importer.")
        }) { XCTAssertEqual($0 as? GameAssetPack.Failure, .invalid) }
    }
}
