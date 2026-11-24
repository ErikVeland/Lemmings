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

    func testWaitingIsNotZeroAndAllPreImportStatesCancel() {
        XCTAssertEqual(GameAssetPack.Progress.transfer(0), .connecting)
        XCTAssertEqual(GameAssetPack.Progress.transfer(1), .downloading(1))
        XCTAssertEqual(GameAssetPack.Progress.transfer(GameAssetPack.bytes), .downloading(99))
        XCTAssertTrue(GameAssetPack.Progress.connecting.canCancel)
        XCTAssertTrue(GameAssetPack.Progress.alternateMirror.canCancel)
        XCTAssertFalse(GameAssetPack.Progress.installing.canCancel)
    }

    func testNetworkPolicyAllows5GAndLowDataModeAfterConsent() {
        let configuration = GameAssetPack.configuration()
        XCTAssertTrue(configuration.allowsCellularAccess)
        XCTAssertTrue(configuration.allowsExpensiveNetworkAccess)
        XCTAssertTrue(configuration.allowsConstrainedNetworkAccess)
        XCTAssertFalse(configuration.isDiscretionary)
        XCTAssertGreaterThan(configuration.timeoutIntervalForResource, configuration.timeoutIntervalForRequest)
    }

    func testConnectionErrorsAreActionable() {
        XCTAssertEqual(GameAssetPack.explained(URLError(.notConnectedToInternet)) as? GameAssetPack.Failure, .offline)
        XCTAssertEqual(GameAssetPack.explained(URLError(.networkConnectionLost)) as? GameAssetPack.Failure, .interrupted)
        XCTAssertEqual(GameAssetPack.explained(URLError(.dataNotAllowed)) as? GameAssetPack.Failure, .prohibited)
        XCTAssertEqual(GameAssetPack.explained(URLError(.timedOut)) as? GameAssetPack.Failure, .timedOut)
        XCTAssertEqual(GameAssetPack.explained(CocoaError(.fileWriteOutOfSpace)) as? GameAssetPack.Failure, .storage)
    }

    func testRecoveredFallbackDoesNotStartAnotherFullTransfer() async throws {
        let mirror = try await GameAssetPack.withDownloadFallback { url in
            if url.host == "archive.org" { throw GameAssetPack.Failure.unavailable }
            return url
        }
        var attempts: [URL] = []
        do {
            _ = try await GameAssetPack.withDownloadFallback(startingAt: mirror) { source in
                attempts.append(source)
                throw URLError(.timedOut)
            }
            XCTFail("The timed out transfer succeeded.")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(attempts, [mirror])
    }

    func testTimeoutTriesAlternateMirrorOnceAndReportsFinalTimeout() async {
        var attempts: [String] = []
        var alternateNotices = 0
        do {
            _ = try await GameAssetPack.withDownloadFallback(fallbackProgress: { alternateNotices += 1 }) { source in
                attempts.append(source.host ?? "")
                throw URLError(.timedOut)
            }
            XCTFail("Timed out downloads must not reach the importer.")
        } catch {
            let failure = GameAssetPack.explained(error) as? GameAssetPack.Failure
            XCTAssertEqual(failure, .timedOut)
            XCTAssertTrue(failure?.localizedDescription.contains("timed out") == true)
        }
        XCTAssertEqual(attempts, ["archive.org", "github.com"])
        XCTAssertEqual(alternateNotices, 1)
    }

    func testMissingRestoredTaskDoesNotRestartOnAnotherMirror() async {
        var attempts = 0
        do {
            _ = try await GameAssetPack.withDownloadFallback { _ in
                attempts += 1
                throw GameAssetPack.Failure.resumeUnavailable
            }
            XCTFail("Missing OS task must not reach the importer.")
        } catch {
            XCTAssertEqual(error as? GameAssetPack.Failure, .resumeUnavailable)
        }
        XCTAssertEqual(attempts, 1)
    }

    func testDiskFullDoesNotRetryMirror() async {
        var attempts = 0
        do {
            _ = try await GameAssetPack.withDownloadFallback { _ in
                attempts += 1
                throw CocoaError(.fileWriteOutOfSpace)
            }
            XCTFail("The failed transfer succeeded.")
        } catch {
            XCTAssertEqual(GameAssetPack.explained(error) as? GameAssetPack.Failure, .storage)
        }
        XCTAssertEqual(attempts, 1)
    }

    func testHTTPErrorAndOversizedContentAreRejected() throws {
        let url = try XCTUnwrap(URL(string: "https://example.invalid/pack"))
        let failure = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)
        XCTAssertThrowsError(try GameAssetPack.validateResponse(failure)) {
            XCTAssertEqual($0 as? GameAssetPack.Failure, .unavailable)
        }
        let oversized = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                        headerFields: ["Content-Length": String(GameAssetPack.bytes + 1)])
        XCTAssertThrowsError(try GameAssetPack.validateResponse(oversized)) {
            XCTAssertEqual($0 as? GameAssetPack.Failure, .invalid)
        }
    }

    func testZeroByteOfferRequiresContinuousForegroundOnlineWait() {
        var offer = GameAssetPack.StallOffer()
        XCTAssertFalse(offer.observe(now: 0, online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.observe(now: 19, online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.observe(now: 20, online: false, foreground: true, bytes: 0))
        XCTAssertFalse(offer.observe(now: 80, online: true, foreground: false, bytes: 0))
        XCTAssertFalse(offer.observe(now: 100, online: true, foreground: true, bytes: 0))
        XCTAssertTrue(offer.observe(now: 120, online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.requestSwitch(online: false, foreground: true, bytes: 0))
        XCTAssertFalse(offer.requestSwitch(online: true, foreground: false, bytes: 0))
        XCTAssertFalse(offer.requestSwitch(online: true, foreground: true, bytes: 1))
        XCTAssertTrue(offer.requestSwitch(online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.requestSwitch(online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.mayStartAlternate(primaryCompleted: false))
        XCTAssertTrue(offer.mayStartAlternate(primaryCompleted: true))
    }

    func testAnyProgressPreventsZeroByteOfferAfterCounterReset() {
        var offer = GameAssetPack.StallOffer()
        XCTAssertFalse(offer.observe(now: 0, online: true, foreground: true, bytes: 1))
        XCTAssertFalse(offer.observe(now: 40, online: true, foreground: true, bytes: 0))
        XCTAssertFalse(offer.observe(now: 80, online: true, foreground: true, bytes: 0))
    }

    func testManualAlternateRequestReachesOnlyTheOtherMirror() async throws {
        var requests: [String] = []
        let completed = try await GameAssetPack.withDownloadFallback { source in
            requests.append(source.host ?? "")
            if requests.count == 1 { throw GameAssetPack.Failure.alternateRequested }
            return source
        }
        XCTAssertEqual(requests, ["archive.org", "github.com"])
        XCTAssertEqual(completed.host, "github.com")
    }

    func testIncompleteDownloadDoesNotReachImporter() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Incomplete transfer".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try GameAssetPack.verifyArchive(file)) { XCTAssertEqual($0 as? GameAssetPack.Failure, .invalid) }
    }
}
