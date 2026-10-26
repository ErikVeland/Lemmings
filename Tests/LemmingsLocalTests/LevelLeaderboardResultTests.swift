import AppKit
import Foundation
@testable import LemmingsAppCore
import NxlvKit
import XCTest
@testable import LemmingsLocal

@MainActor private final class FixedBoardTransport: HostedRankingsTransport {
    var board: HostedBoard?
    var paths: [String] = []
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        paths.append(request.url?.absoluteString ?? "")
        guard let board else { throw URLError(.notConnectedToInternet) }
        return (try JSONEncoder().encode(board), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { throw URLError(.unsupportedURL) }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) { throw URLError(.unsupportedURL) }
}

final class LevelLeaderboardResultTests: XCTestCase {
    /// The result screen shows this level's ranking and every tied leader for each engine, loaded or offline.
    @MainActor func testResultShowsLevelLeaderboardAndLeadersAcrossAllGames() async throws {
        _ = NSApplication.shared
        let storage = try AppStorage.temporary(named: "level-leaderboard-result")
        let previous = ArcadeStore.shared, previousRankings = HostedRankings.shared
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        ArcadeStore.shared = store
        defer { ArcadeStore.shared = previous; HostedRankings.shared = previousRankings; storage.removeTemporaryFiles() }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let font = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: artwork)))
        let output = root.appendingPathComponent(".build/level-leaderboard-results")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let host = store.records.activeProfileID
        for (game, gameID) in [("Classic", "lemmings"), ("Lemmings 2", "lemmings2"), ("Lemmings 3", "lemmings3")] {
            for loaded in [true, false] {
                let transport = FixedBoardTransport()
                if loaded {
                    transport.board = HostedBoard(entries: [.init(rank: 1, name: "AB", score: 41000, runID: nil, replay: false),
                        .init(rank: 1, name: "CD", score: 41000, runID: nil, replay: false),
                        .init(rank: 3, name: "EF", score: 52500, runID: nil, replay: false)], page: 0, hasMore: false, verification: "test")
                }
                let rankings = HostedRankings(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport,
                                              defaults: storage.defaults, credentials: { _ in "" })
                rankings.networkEnabled = true
                HostedRankings.shared = rankings
                let conditions = TrolleyConditions(gameID: gameID, packID: "pack", levelID: "1",
                    levelFingerprint: String(repeating: "b", count: 64), rulesetVersion: "fixture", physicsMode: "fixture",
                    population: 10, rescueRequirement: 5, startingSkills: [:], timeLimitSeconds: 300)
                let level = ArcadeLevel(id: game, title: "Leaderboard fixture", game: game, rules: "fixture", total: 10,
                                        required: 5, conditions: conditions)
                let report = try XCTUnwrap(store.previewReport(for: .init(profileID: host, level: level, saved: 8, didWin: true,
                                                                          skills: [:], seconds: 20)))
                let view = ArcadeView(frame: CGRect(x: 0, y: 0, width: 1120, height: 720))
                let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = view
                defer { window.close() }
                view.mode = .result; view.report = report; view.level = level; view.font = font
                view.onClose = {}; view.onMenu = {}; view.onRetry = {}
                func render(_ name: String) throws {
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name))
                }
                try render("\(game)-\(loaded)-loading.png")
                for _ in 0..<200 where rankings.levelBusy { await Task.yield() }
                try render("\(game)-\(loaded).png")
                let label = view.accessibilityLabel() ?? ""
                XCTAssertTrue(label.contains("Level leaderboard, Fastest 100%."), label)
                XCTAssertTrue(transport.paths.last?.contains("assisted=0") == true)
                if loaded {
                    XCTAssertTrue(label.contains("Leaders: AB, CD  0:41.00"), label)
                    XCTAssertTrue(label.contains("#3  EF  0:52.50"), label)
                } else {
                    XCTAssertTrue(label.contains("Offline"), label)
                }
                let buttons = (view.accessibilityChildren() ?? []).compactMap { $0 as? GameAccessibleElement }
                    .filter { $0.accessibilityRole() == .button }
                let nextMetric = try XCTUnwrap(buttons.first { $0.accessibilityLabel() == "›" })
                XCTAssertTrue(view.bounds.contains(nextMetric.localFrame))
                XCTAssertFalse(buttons.contains { $0 !== nextMetric && $0.localFrame.intersects(nextMetric.localFrame) })
                XCTAssertTrue(nextMetric.accessibilityPerformPress())
                for _ in 0..<200 where rankings.levelBusy { await Task.yield() }
                XCTAssertEqual(rankings.levelCategory, .fastestClear)
                XCTAssertTrue(transport.paths.last?.contains("board=fastestClear") == true)
            }
        }
    }
}
