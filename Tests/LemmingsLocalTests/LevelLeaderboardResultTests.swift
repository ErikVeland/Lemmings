import AppKit
import Foundation
@testable import LemmingsAppCore
import NxlvKit
import XCTest
@testable import LemmingsLocal
import LemmingsGameArt

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

final class LocalLeaderboardPageTests: XCTestCase {
    /// Progress ranks players across all levels; a level page ranks players on that level, Fastest 100% first.
    @MainActor func testProgressRanksPlayersAndLevelOpensOnFastestFullRescue() throws {
        let storage = try AppStorage.temporary(named: "local-leaderboards")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let host = store.records.mainProfileID
        let guest = try XCTUnwrap(store.addProfile(initials: "GU", portrait: 1, select: false))
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "pack", levelID: "level-0",
            levelFingerprint: String(repeating: "c", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let level = ArcadeLevel(id: "level", title: "Test", game: "Classic", rules: "classic-dos-v1", total: 10, required: 5, conditions: conditions)
        XCTAssertNotNil(store.record(ArcadeRun(profileID: host, level: level, saved: 10, didWin: true, skills: ["digger": 1], seconds: 30, telemetry: .init(released: 10))))
        XCTAssertNotNil(store.record(ArcadeRun(profileID: guest.id, level: level, saved: 10, didWin: true, skills: ["digger": 1], seconds: 20, telemetry: .init(released: 10))))
        XCTAssertNotNil(store.record(ArcadeRun(profileID: guest.id, level: level, saved: 6, didWin: true, skills: [:], seconds: 10, telemetry: .init(released: 10))))
        let records = store.records
        let local = MobileCareerArt.localLeaderboardRows(records: records, category: .stars, activeID: host)
        XCTAssertTrue(local.allSatisfy { $0.id.hasPrefix("progress.player.") })
        XCTAssertEqual(Set(local.map(\.id)).count, 2)
        XCTAssertEqual(local.filter(\.selected).map(\.id), ["progress.player.\(host)"])
        let board = MobileCareerArt.leaderboards(world: false, category: .clears, rows: local, busy: false, status: "",
                                                 sharing: true, gameCenter: true)
        XCTAssertEqual(board.listTools.map(\.id), ["rankScope.world", "rankScope.local",
            "rankCategory.stars", "rankCategory.clears", "rankCategory.perfect"])
        XCTAssertEqual(board.listTools.filter(\.selected).map(\.id), ["rankScope.local", "rankCategory.clears"])
        XCTAssertEqual(board.footer.map(\.id), ["home", "rankGameCenter"])
        let progress = MobileCareerArt.progressPage(records: records, profileID: host, profileName: "Host", subtitle: "")
        XCTAssertEqual(progress.rows.map(\.id), ["recordList", "achievements", "playInsights"])
        XCTAssertEqual(progress.footer.map(\.id), ["home"])
        XCTAssertTrue(progress.listTools.isEmpty)
        let hotSeatProgress = MobileCareerArt.progressPage(records: records, profileID: guest.id,
            profileName: "GU", subtitle: "", selectablePlayers: [
                .init(id: host, name: "Host", portrait: 0),
                .init(id: guest.id, name: "GU", portrait: 1)
            ])
        XCTAssertEqual(hotSeatProgress.listTools.map(\.id), ["progress.profile.\(host)", "progress.profile.\(guest.id)"])
        XCTAssertEqual(hotSeatProgress.listTools.filter(\.selected).map(\.id), ["progress.profile.\(guest.id)"])
        XCTAssertEqual(hotSeatProgress.listTools.compactMap(\.portrait), [0, 1])
        for (width, scale) in [(CGFloat(390), CGFloat(1)), (CGFloat(960), CGFloat(2))] {
            let tools = GameListToolsArt.layout(width: width, actions: hotSeatProgress.listTools, scale: scale)
            XCTAssertEqual(tools.targets.map { $0.action.id }, hotSeatProgress.listTools.map(\.id))
            for target in tools.targets {
                XCTAssertEqual(tools.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
                XCTAssertGreaterThanOrEqual(target.frame.width * scale, 44)
                XCTAssertGreaterThanOrEqual(target.frame.height * scale, 44)
            }
        }
        let crowdedPlayers = (1...8).map {
            GameFrontEnd.Action("progress.profile.player-\($0)", "PLAYER \($0)", portrait: $0 % 8)
        }
        for (width, scale) in [(CGFloat(390), CGFloat(1)), (CGFloat(960), CGFloat(2))] {
            let tools = GameListToolsArt.layout(width: width, actions: crowdedPlayers, scale: scale)
            XCTAssertEqual(tools.targets.count, crowdedPlayers.count)
            XCTAssertEqual(Set(tools.targets.map { $0.action.id }), Set(crowdedPlayers.map(\.id)))
            for target in tools.targets {
                XCTAssertEqual(tools.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
            }
        }
        let key = "direct|" + level.boardID
        let full = MobileCareerArt.progressLevelPage(records: records, key: key, metric: "unknown")
        XCTAssertEqual(full.listTools.first { $0.selected }?.id, "progress.levelMetric.full")
        XCTAssertEqual(full.details, ["1. GU   0:20.00", "2. \(records.profile(host)!.initials)   0:30.00"])
        let clear = MobileCareerArt.progressLevelPage(records: records, key: key, metric: "clear")
        XCTAssertEqual(clear.details.first, "1. GU   0:10.00")
        XCTAssertEqual(clear.details.count, 2)
    }

    func testMainMenuLogoStaysCenteredWhenHeaderHasStatusAndSideControls() {
        let page = MobileHomeArt.page(journey: nil, families: [.init("classic", "Classic Lemmings")],
                                      initials: "ERI v UVA", subtitle: "Connected")
        let phone = GameFrontEnd.layout(page, width: 390, minimumHeight: 763)
        XCTAssertEqual(phone.heading.midX, 195, accuracy: 0.01)

        let desktop = GameFrontEnd.layout(page, width: 1280, minimumHeight: 800)
        XCTAssertEqual(desktop.heading.midX, 640, accuracy: 0.01)

        let panes = [CGRect(x: 0, y: 0, width: 420, height: 900),
                     CGRect(x: 420, y: 0, width: 420, height: 900)]
        let duo = GameFrontEnd.layout(page, width: 840, minimumHeight: 900, bookHomePanes: panes)
        XCTAssertEqual(duo.heading.midX, panes[0].midX, accuracy: 0.01)

        let tv = TVMenuPresentation.homeLayout(page, width: 1920, height: 1080)
        let inner = tv.board.width - 32
        let leading = floor(inner * 0.30)
        let tvLogoCenter = tv.board.minX + 16 + leading / 2
        XCTAssertEqual(tv.heading.midX, tvLogoCenter, accuracy: 0.01)
    }
}
