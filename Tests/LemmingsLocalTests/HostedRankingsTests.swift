import AppKit
import Foundation
import NxlvKit
import XCTest
@testable import LemmingsLocal

@MainActor private final class FakeHostedTransport: HostedRankingsTransport {
    var requests: [URLRequest] = []
    var responseCode = 200
    var board = HostedBoard(entries: [.init(rank: 1, name: "UVA", score: 12340, runID: UUID(), replay: true)], page: 0, hasMore: false, verification: "community")
    var slowFirst = false
    var counter = 0
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request); counter += 1
        let count = counter
        let snapshot = board
        if slowFirst && count == 1 { try await Task.sleep(nanoseconds: 50_000_000) }
        return (try JSONEncoder().encode(snapshot), HTTPURLResponse(url: request.url!, statusCode: responseCode, httpVersion: nil, headerFields: nil)!)
    }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { try await data(for: request) }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) { throw URLError(.notConnectedToInternet) }
}

final class HostedRankingsTests: XCTestCase {
    func conditions(game: String = "lemmings") -> TrolleyConditions {
        .init(gameID: game, packID: "pack", levelID: "1", levelFingerprint: "abc", rulesetVersion: "v1", physicsMode: "classic", population: 10, rescueRequirement: 5, startingSkills: ["builder": 10], timeLimitSeconds: 300)
    }
    @MainActor func wait(_ service: HostedRankings) async throws {
        for _ in 0..<500 where service.busy || service.syncing { try await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertFalse(service.busy); XCTAssertFalse(service.syncing)
    }
    @MainActor func testWireIdentityAcrossAllEngines() throws {
        for game in ["lemmings", "neolemmix", "lemmings2", "lemmings3"] {
            let c = conditions(game: game)
            let level = ArcadeLevel(id: "test", title: "Test", game: game, rules: "v1", total: 10, required: 5, conditions: c)
            let run = ArcadeRun(profileID: "private-local-profile", level: level, saved: 8, didWin: true, skills: ["builder": 2], seconds: 12.345, assisted: true)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: HostedRankings.payload(run)) as? [String: Any])
            XCTAssertEqual(object["milliseconds"] as? Int, 12345)
            XCTAssertEqual(object["assisted"] as? Bool, true)
            XCTAssertNil(object["profileID"]); XCTAssertNil(object["name"])
            XCTAssertEqual(try JSONDecoder().decode(TrolleyConditions.self, from: Data((object["conditionsJSON"] as! String).utf8)), c)
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = ["-c", "import sys,hashlib;sys.path.insert(0,'Tools/Rankings');from server import checked_conditions;print(checked_conditions(sys.argv[1])[1])", object["conditionsJSON"] as! String]
            let output = Pipe(); process.standardOutput = output
            try process.run(); process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0)
            XCTAssertEqual(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), c.fingerprint)
        }
    }
    @MainActor func testBrowseNeedsNoAccountAndDoesNotShare() async throws {
        let suite = UUID().uuidString; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeHostedTransport()
        let service = HostedRankings(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport, defaults: defaults, credentials: { _ in XCTFail("Browse requested a credential"); return "" })
        service.networkEnabled = true
        XCTAssertFalse(service.sharing("a"))
        service.completed(profileID: "a")
        service.refresh(conditions: conditions(), category: .fastestAllSaved, assisted: true, page: 2)
        try await wait(service)
        XCTAssertEqual(service.board, transport.board)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertNil(transport.requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(transport.requests[0].url!.query!.contains("assisted=1&page=2"))
    }
    @MainActor func testStaleResponseCannotReplaceSelectedBoard() async throws {
        let transport = FakeHostedTransport(); transport.slowFirst = true
        let service = HostedRankings(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport)
        service.networkEnabled = true
        service.refresh(conditions: conditions(), category: .mostSaved, assisted: false)
        try await Task.sleep(nanoseconds: 5_000_000)
        transport.board = .init(entries: [], page: 1, hasMore: false, verification: "community")
        service.refresh(conditions: conditions(), category: .fastestClear, assisted: true, page: 1)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(service.board?.page, 1); XCTAssertTrue(service.board?.entries.isEmpty == true)
        transport.responseCode = 503
        service.refresh(conditions: conditions(), category: .mostSaved, assisted: false)
        try await wait(service)
        XCTAssertNil(service.board); XCTAssertTrue(service.status.contains("Offline"))
    }
    @MainActor func testSyncUsesLocalPlayerCredentialAndRemovalStopsSharing() async throws {
        let suite = UUID().uuidString; let defaults = UserDefaults(suiteName: suite)!
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let previousStore = ArcadeStore.shared
        defer { ArcadeStore.shared = previousStore; defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: file) }
        ArcadeStore.shared = ArcadeStore(file: file, defaults: defaults)
        let transport = FakeHostedTransport()
        var accounts: [String] = []
        let service = HostedRankings(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport, defaults: defaults, credentials: { profile in accounts.append(profile); return String(repeating: "a", count: 64) })
        service.networkEnabled = true
        service.setSharing(true, profile: ArcadeProfile.legacyID)
        try await wait(service)
        XCTAssertTrue(service.hasShared(ArcadeProfile.legacyID))
        XCTAssertEqual(accounts, [ArcadeProfile.legacyID])
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
        XCTAssertEqual(transport.requests.first?.url?.path, "/rankings/v1/players")
        service.remove(profile: ArcadeProfile.legacyID)
        try await wait(service)
        XCTAssertFalse(service.sharing(ArcadeProfile.legacyID)); XCTAssertFalse(service.hasShared(ArcadeProfile.legacyID))
        XCTAssertEqual(transport.requests.last?.httpMethod, "DELETE")
    }
}
