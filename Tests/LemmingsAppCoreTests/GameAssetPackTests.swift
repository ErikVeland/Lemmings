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

    func testColdRestoreStillRejectsChangedBytesAcrossStreamingChunks() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let base = root.appendingPathComponent("Base", isDirectory: true)
        let source = root.appendingPathComponent("Owned", isDirectory: true)
        let relative = "Music/fixture.dat"
        let file = source.appendingPathComponent(relative)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data(repeating: 0x61, count: (1 << 20) + 7)
        try original.write(to: file)
        let library = OwnedResourceLibrary(root: root.appendingPathComponent("Installed"), bundledResources: base,
                                           validator: { _ in })
        let installed = try library.install(directory: source)
        XCTAssertEqual(try library.refreshBaseIfNeeded()?.contentID, installed.contentID)
        let restored = installed.resourcesDirectory.appendingPathComponent(relative)

        var changed = original
        changed[changed.count - 1] = 0x62
        for damaged in [changed, original + Data([0x62]), Data(original.dropLast())] {
            try damaged.write(to: restored)
            XCTAssertThrowsError(try library.refreshBaseIfNeeded())
        }
        try original.write(to: restored)
        XCTAssertEqual(try library.refreshBaseIfNeeded()?.contentID, installed.contentID)
    }

    /// Set LEMMINGS_GAME_ASSET_ARCHIVE to a downloaded pack to check extraction and import end to end.
    func testDownloadedArchiveInstallsIntoResourceLibrary() throws {
        guard let path = ProcessInfo.processInfo.environment["LEMMINGS_GAME_ASSET_ARCHIVE"] else {
            throw XCTSkip("LEMMINGS_GAME_ASSET_ARCHIVE is not set.")
        }
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let base = root.appendingPathComponent("Base", isDirectory: true)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        let archive = URL(fileURLWithPath: path)
        try GameAssetPack.verifyArchive(archive)
        let library = OwnedResourceLibrary(root: root.appendingPathComponent("Installed"), bundledResources: base)
        let receipt = try GameAssetPack.installVerifiedArchive(archive) { try library.install(directory: $0) }
        XCTAssertEqual(try library.verifyInstalled()?.contentID, receipt.contentID)
        for folder in ["MacArtwork", "AmigaArtwork", "Fonts/OriginalLemmings"] {
            XCTAssertTrue(manager.fileExists(atPath: receipt.resourcesDirectory.appendingPathComponent(folder).path), folder)
        }
    }

    /// Set LEMMINGS_TEST_ASSET_DOWNLOAD=1 to download the real pack through the app's own transfer path.
    func testLiveDownloadReportsProgressAndInstalls() async throws {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_ASSET_DOWNLOAD"] == "1" else {
            throw XCTSkip("LEMMINGS_TEST_ASSET_DOWNLOAD is not set.")
        }
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let base = root.appendingPathComponent("Base", isDirectory: true)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        let library = OwnedResourceLibrary(root: root.appendingPathComponent("Installed"), bundledResources: base)
        let phases = PhaseLog()
        let receipt = try await GameAssetPack.shared.downloadAndInstall(progress: { phases.add($0) }) {
            try library.install(directory: $0)
        }
        let observed = await MainActor.run { phases.values }
        XCTAssertEqual(observed.first, .connecting)
        XCTAssertEqual(observed.last, .installing)
        let progress = observed.compactMap { phase -> Int? in
            if case .downloading(let value) = phase { return value }
            return nil
        }
        XCTAssertFalse(progress.isEmpty)
        XCTAssertTrue(progress.allSatisfy { (1...99).contains($0) })
        XCTAssertEqual(try library.verifyInstalled()?.contentID, receipt.contentID)
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

@MainActor private final class PhaseLog: @unchecked Sendable {
    var values: [GameAssetPack.Progress] = []
    nonisolated init() {}
    func add(_ phase: GameAssetPack.Progress) { values.append(phase) }
}
