#if os(macOS)
import AppKit
@preconcurrency import GameKit
import LemmingsAppCore
import NxlvKit

@MainActor protocol GameCenterTransport {
    var account: GameCenterAccount? { get }
    func authenticate(window: NSWindow?, completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void)
    func submit(_ score: Int, boardID: String) async throws
    func load(_ boardID: String) async throws -> WorldwideBoard
}
@MainActor final class AppleGameCenterTransport: GameCenterTransport {
    private var authenticationSheet: NSWindow?
    var account: GameCenterAccount? {
        let player = GKLocalPlayer.local
        return player.isAuthenticated ? .init(id: player.gamePlayerID, name: player.displayName) : nil
    }
    func authenticate(window: NSWindow?, completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void) {
        GKLocalPlayer.local.authenticateHandler = { controller, error in
            Task { @MainActor in
                if let controller {
                    GKDialogController.shared().parentWindow = window
                    if let dialog = controller as? (NSViewController & GKViewController) {
                        if !GKDialogController.shared().present(dialog) {
                            completion(.failure(NSError(domain: "GameCenter", code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "Game Center sign-in could not open. Try again."])))
                        }
                    } else if let window {
                        let sheet = NSWindow(contentViewController: controller)
                        self.authenticationSheet = sheet; window.beginSheet(sheet)
                    } else {
                        completion(.failure(NSError(domain: "GameCenter", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Open Game Center from the game window to sign in."])))
                    }
                } else {
                    if let sheet = self.authenticationSheet {
                        sheet.sheetParent?.endSheet(sheet); sheet.close(); self.authenticationSheet = nil
                    }
                    if let account = self.account { completion(.success(account)) }
                    else { completion(.failure(error ?? NSError(domain: "GameCenter", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Sign in to Game Center to view worldwide scores."]))) }
                }
            }
        }
    }
    func submit(_ score: Int, boardID: String) async throws {
        try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [boardID])
    }
    func load(_ boardID: String) async throws -> WorldwideBoard {
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [boardID])
        guard let board = boards.first else { throw NSError(domain: "GameCenter", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "This worldwide board is not available yet."]) }
        let (personal, entries, count) = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 5))
        func entry(_ e: GKLeaderboard.Entry) -> WorldwideEntry { .init(rank: e.rank, name: e.player.displayName, score: e.score) }
        return .init(entries: entries.map(entry), personal: personal.map(entry), players: count)
    }
}

@MainActor final class GameCenterDashboard: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDashboard()
    func show(boardID: String, window: NSWindow?) {
        let controller = GKGameCenterViewController(leaderboardID: boardID, playerScope: .global, timeScope: .allTime)
        controller.gameCenterDelegate = self
        GKDialogController.shared().parentWindow = window
        GKDialogController.shared().present(controller)
    }
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in GKDialogController.shared().dismiss(self) }
    }
}

/// History is the retry queue. Failed submissions remain local and retry on the next connection.
@MainActor private final class MacGameCenterTransport: GameCenterServiceTransport {
    let underlying: any GameCenterTransport
    weak var window: NSWindow?
    init(_ transport: any GameCenterTransport) { underlying = transport }
    var account: GameCenterAccount? { underlying.account }
    func authenticate(completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void) {
        underlying.authenticate(window: window, completion: completion)
    }
    func submit(_ score: Int, boardID: String) async throws { try await underlying.submit(score, boardID: boardID) }
    func load(_ boardID: String) async throws -> WorldwideBoard { try await underlying.load(boardID) }
}

@MainActor final class GameCenterScores: GameCenterService {
    static let shared = GameCenterScores()
    private let adapter: MacGameCenterTransport
    init(configuration: TrolleyOnlineConfiguration? = nil, transport: (any GameCenterTransport)? = nil,
         defaults: UserDefaults = .standard) {
        adapter = MacGameCenterTransport(transport ?? AppleGameCenterTransport())
        super.init(configuration: configuration, transport: adapter, defaults: defaults, recordsStoreProvider: { ArcadeStore.shared })
    }
    func connect(profileID: String, window: NSWindow?, boardID: String, history: TrolleyHistory) {
        adapter.window = window
        super.connect(profileID: profileID, boardID: boardID, history: history)
    }
}

@MainActor extension ArcadeView {
    func openGameCenterBoard() {
        boardScope = .worldwide; page(.records)
        let service = GameCenterScores.shared
        service.onChange = { [weak self] in self?.needsDisplay = true }
        if let config = service.configuration {
            service.refresh(profileID: player.id, boardID: service.boardID ?? config.starsID, history: ArcadeStore.shared.records.trolley)
        }
    }
    func drawGameCenterBoard() {
        header("Worldwide leaderboard"); tabs(); boardScopeLinks()
        let service = GameCenterScores.shared, config = service.configuration
        let selected = service.boardID ?? config?.starsID
        let rankedLevel = config?.levels.first { $0.conditions == level?.conditions }
        let levelID = rankedLevel?.leaderboardID
        let choices = [("Career stars", config?.starsID), ("Cleared", config?.clearsID), ("Three-star", config?.perfectID), ("This level", levelID), ("Fastest clear", rankedLevel?.fastestClearID), ("Fastest 100%", rankedLevel?.fastestAllSavedID)]
        for (index, item) in choices.enumerated() {
            button(item.0, CGRect(x: 80 + (index % 3) * 326, y: 201 + (index / 3) * 46, width: 308, height: 40), selected: item.1 == selected, enabled: item.1 != nil && service.available && !service.busy) { [weak self] in
                guard let self, let id = item.1 else { return }
                if service.account == nil { service.connect(profileID: self.player.id, window: self.window, boardID: id, history: ArcadeStore.shared.records.trolley) }
                else { service.refresh(profileID: self.player.id, boardID: id, history: ArcadeStore.shared.records.trolley) }
            }
        }
        let speedBoard = selected != nil && (selected == rankedLevel?.fastestClearID || selected == rankedLevel?.fastestAllSavedID)
        func scoreLabel(_ score: Int) -> String { speedBoard ? Self.time(Double(score) / 1000) : "\(score)" }
        if let board = service.board {
            for (index, entry) in board.entries.enumerated() {
                let y = CGFloat(298 + index * 43)
                text("#\(entry.rank)", 80, y, 100); text(entry.name, 216, y, 594)
                text(scoreLabel(entry.score), 856, y, 184, alignment: .right)
            }
            if board.entries.isEmpty { text("Be the first to set a score.", 80, 308, 960) }
            let personal = board.personal.map { "Your rank: #\($0.rank) of \(board.players) - \(scoreLabel($0.score))" } ?? "No worldwide score yet."
            text(personal, 80, 521, 960, palette: .green)
        } else {
            paragraph(service.status, CGRect(x: 80, y: 310, width: 960, height: 72))
        }
        if service.board != nil { text(service.status, 80, 564, 960, height: 30, alpha: 0.8) }
        text("Ranked catalogue: \(config?.levels.count ?? 0) configurations. Rewinds excluded.", 80, 604, 960, height: 24, alpha: 0.7)
        if service.available, let config {
            if service.account != nil {
                button("Open Game Center", CGRect(x: 332, y: 634, width: 316, height: 48)) { [weak self] in
                    GameCenterDashboard.shared.show(boardID: selected ?? config.starsID, window: self?.window)
                }
            }
            button(service.busy ? "Connecting..." : service.account == nil ? "Connect Game Center" : "Retry sync", CGRect(x: 672, y: 634, width: 368, height: 48), enabled: !service.busy) { [weak self] in
                guard let self else { return }
                service.connect(profileID: self.player.id, window: self.window, boardID: selected ?? config.starsID, history: ArcadeStore.shared.records.trolley)
            }
        }
        pageFooter()
        let entries = service.board?.entries.map { "Rank \($0.rank). \($0.name). \($0.score)." }.joined(separator: " ") ?? ""
        let personal = service.board?.personal.map { " Your rank: \($0.rank). Your score: \($0.score)." } ?? ""
        let summary = "Worldwide Game Center leaderboard. \(service.status) " + entries + personal
        setAccessibilityLabel(summary + " Ranked catalogue only, without rewinds.")
    }
}
#endif
