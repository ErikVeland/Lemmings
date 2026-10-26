import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

@MainActor private final class BoardTransport: HostedRankingsTransport {
    var board = HostedBoard(entries: [], page: 0, hasMore: false, verification: "test")
    var paths: [String] = []
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        paths.append(request.url?.absoluteString ?? "")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (try JSONEncoder().encode(board), response)
    }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { throw URLError(.unsupportedURL) }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) { throw URLError(.unsupportedURL) }
}

@MainActor struct HostedLeaderboardTests {
    @Test func metricsSplitIntoWorldwideAndLevelListsAndWrap() {
        let worldwide = HostedCategory.worldwide.filter(\.career), level = HostedCategory.level.filter { !$0.career }
        #expect(worldwide.count == 3 && level.count == 4)
        #expect(Set(HostedCategory.worldwide + HostedCategory.level) == Set(HostedCategory.allCases))
        #expect(HostedCategory.perfect.next() == .stars)
        #expect(HostedCategory.fastestAllSaved.next(-1) == .mostSaved)
    }

    @Test func tiedFirstPlacesAreAllLeaders() {
        let board = HostedBoard(entries: [.init(rank: 1, name: "AB", score: 9, runID: nil, replay: false),
                                          .init(rank: 1, name: "CD", score: 9, runID: nil, replay: false),
                                          .init(rank: 3, name: "EF", score: 7, runID: nil, replay: false)],
                                page: 0, hasMore: false, verification: "test")
        #expect(board.leaders.map(\.name) == ["AB", "CD"])
        #expect(HostedLeaderboardText.leaders(board, category: .mostSaved)?.contains("AB, CD") == true)
        #expect(HostedLeaderboardText.leaders(nil, category: .mostSaved) == nil)
        let later = HostedBoard(entries: board.entries, page: 1, hasMore: false, verification: "test")
        #expect(later.leaders.isEmpty)
    }

    @Test func levelBoardLoadsBesideWorldwideDirectOnly() async throws {
        let storage = try AppStorage.temporary(named: "level-board")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let transport = BoardTransport()
        transport.board = HostedBoard(entries: [.init(rank: 1, name: "AB", score: 10, runID: nil, replay: false)],
                                      page: 0, hasMore: false, verification: "test")
        let service = HostedRankingsService(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport,
            defaults: storage.defaults, credentials: { _ in "" }, recordsStoreProvider: { store })
        service.networkEnabled = true
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "pack", levelID: "level-0",
            levelFingerprint: String(repeating: "a", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        service.refreshLevel(conditions: conditions, category: .stars)
        #expect(service.levelCategory == .fastestAllSaved)
        for _ in 0..<100 where service.levelBusy { await Task.yield() }
        #expect(service.levelBoard?.leaders.map(\.name) == ["AB"])
        #expect(service.board == nil)
        let path = try #require(transport.paths.last)
        #expect(path.contains("board=fastestAllSaved") && path.contains("assisted=0") && path.contains(conditions.fingerprint))
        service.refreshLevel(conditions: conditions, category: .fastestClear)
        for _ in 0..<100 where service.levelBusy { await Task.yield() }
        #expect(transport.paths.last?.contains("board=fastestClear") == true)
    }
}
