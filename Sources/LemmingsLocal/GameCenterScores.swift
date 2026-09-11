import AppKit
@preconcurrency import GameKit
import NxlvKit

struct WorldwideEntry: Equatable, Sendable {
    let rank: Int
    let name: String
    let score: Int
}
struct WorldwideBoard: Equatable, Sendable {
    let entries: [WorldwideEntry]
    let personal: WorldwideEntry?
    let players: Int
}
struct GameCenterAccount: Equatable, Sendable {
    let id: String
    let name: String
}
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
@MainActor final class GameCenterScores {
    static let shared = GameCenterScores()
    let configuration: TrolleyOnlineConfiguration?
    private let transport: any GameCenterTransport
    private let defaults: UserDefaults
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var authenticationRequest: UUID?
    private var submitted: [String: Int] = [:]
    private(set) var board: WorldwideBoard?
    private(set) var boardID: String?
    private(set) var previousRank: Int?
    private(set) var status = "Connect Game Center to compare worldwide."
    private(set) var busy = false
    var onChange: (() -> Void)?
    var available: Bool { configuration?.enabled == true && configuration?.isValid == true }
    var account: GameCenterAccount? { transport.account }
    var linkedProfileID: String? { account.flatMap { defaults.string(forKey: "GameCenter.profile." + $0.id) } }
    init(configuration: TrolleyOnlineConfiguration? = nil, transport: (any GameCenterTransport)? = nil, defaults: UserDefaults = .standard) {
        self.configuration = configuration ?? Bundle.main.url(forResource: "leaderboards", withExtension: "json", subdirectory: "GameCenter")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(TrolleyOnlineConfiguration.self, from: $0) }
        self.transport = transport ?? AppleGameCenterTransport(); self.defaults = defaults
        if !available { status = "Worldwide rankings are not enabled in this build. Local records are saved." }
    }
    func connect(profileID: String, window: NSWindow?, boardID: String, history: TrolleyHistory) {
        guard available, !busy else { onChange?(); return }
        let request = UUID(); authenticationRequest = request
        busy = true; status = "Connecting to Game Center..."; onChange?()
        transport.authenticate(window: window) { [weak self] result in
            guard let self else { return }
            guard self.authenticationRequest == request else {
                self.operation?.cancel(); self.generation = UUID()
                self.busy = false; self.board = nil; self.submitted = [:]
                self.status = "Game Center account changed. Connect this player to refresh scores."
                self.onChange?(); return
            }
            self.authenticationRequest = nil
            self.busy = false
            switch result {
            case .success(let account):
                let key = "GameCenter.profile." + account.id
                if self.defaults.string(forKey: key) == nil { self.defaults.set(profileID, forKey: key) }
                self.refresh(profileID: profileID, boardID: boardID, history: history)
            case .failure(let error): self.status = error.localizedDescription; self.board = nil; self.onChange?()
            }
        }
    }
    func refresh(profileID: String, boardID: String, history: TrolleyHistory) {
        operation?.cancel(); generation = UUID()
        previousRank = self.boardID == boardID ? board?.personal?.rank : nil
        self.boardID = boardID; board = nil
        guard available, let account else { onChange?(); return }
        let ticket = generation
        let linked = linkedProfileID == profileID
        busy = true; status = linked ? "Syncing your saved records..." : "Viewing worldwide scores. This account is linked to another local player."
        onChange?()
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == ticket {
                    self.busy = false
                    if self.account?.id != account.id {
                        self.board = nil
                        self.status = "Game Center account changed. Your local records are saved."
                    }
                    self.onChange?()
                }
            }
            var syncFailed = false
            if linked, let config = self.configuration {
                let scores = config.scores(attempts: history.attempts, profileID: profileID)
                for (id, score) in scores.sorted(by: { $0.key < $1.key }) {
                    guard !Task.isCancelled, self.account?.id == account.id, self.generation == ticket else { return }
                    let key = account.id + ":" + profileID + ":" + id
                    guard self.submitted[key] != score else { continue }
                    do {
                        try await self.transport.submit(score, boardID: id)
                        self.submitted[key] = score
                    } catch { syncFailed = true }
                }
            }
            do {
                let loaded = try await self.transport.load(boardID)
                guard !Task.isCancelled, self.generation == ticket, self.account?.id == account.id else { return }
                self.board = loaded
                self.status = syncFailed ? "Scores are saved locally. Retry to finish syncing."
                    : linked ? "Connected as \(account.name). Records synced." : "Viewing as \(account.name). Scores belong to a different local player."
            } catch {
                guard self.generation == ticket else { return }
                self.status = "Game Center is unavailable. Your records are saved. Retry when connected."
            }
            self.busy = false; self.onChange?()
        }
    }
    func completed(profileID: String, history: TrolleyHistory) {
        guard available, account != nil, linkedProfileID == profileID, let config = configuration else { return }
        refresh(profileID: profileID, boardID: boardID ?? config.starsID, history: history)
    }
    var rankLabel: String? {
        guard let rank = board?.personal?.rank else { return nil }
        return previousRank.map { $0 > rank ? "#\($0) > #\(rank)" : "#\(rank)" } ?? "#\(rank)"
    }
}

@MainActor extension ArcadeView {
    func openWorldwideBoard() {
        boardScope = .worldwide; page(.records)
        let service = GameCenterScores.shared
        service.onChange = { [weak self] in self?.needsDisplay = true }
        if service.account != nil, let config = service.configuration {
            service.refresh(profileID: player.id, boardID: service.boardID ?? config.starsID, history: ArcadeStore.shared.records.trolley)
        }
    }
    func drawWorldwideBoard() {
        header("Worldwide leaderboard"); tabs(); boardScopeLinks()
        let service = GameCenterScores.shared, config = service.configuration
        let selected = service.boardID ?? config?.starsID
        let levelID = config?.levels.first { $0.conditions == level?.conditions }?.leaderboardID
        let choices = [("Career stars", config?.starsID), ("Cleared", config?.clearsID), ("Three-star", config?.perfectID), ("This level", levelID)]
        for (index, item) in choices.enumerated() {
            button(item.0, CGRect(x: 80 + index * 244, y: 213, width: 226, height: 40), selected: item.1 == selected, enabled: item.1 != nil && service.available && !service.busy) { [weak self] in
                guard let self, let id = item.1 else { return }
                if service.account == nil { service.connect(profileID: self.player.id, window: self.window, boardID: id, history: ArcadeStore.shared.records.trolley) }
                else { service.refresh(profileID: self.player.id, boardID: id, history: ArcadeStore.shared.records.trolley) }
            }
        }
        if let board = service.board {
            for (index, entry) in board.entries.enumerated() {
                let y = CGFloat(298 + index * 43)
                text("#\(entry.rank)", 80, y, 100); text(entry.name, 216, y, 594)
                text("\(entry.score)", 856, y, 184, alignment: .right)
            }
            if board.entries.isEmpty { text("Be the first to set a score.", 80, 308, 960) }
            let personal = board.personal.map { "Your rank: #\($0.rank) of \(board.players) - \($0.score)" } ?? "No worldwide score yet."
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
        setAccessibilityLabel("Worldwide Game Center leaderboard. \(service.status) " + (service.board?.entries.map { "Rank \($0.rank). \($0.name). \($0.score)." }.joined(separator: " ") ?? "")
            + (service.board?.personal.map { " Your rank: \($0.rank). Your score: \($0.score)." } ?? "") + " Ranked catalogue only, without rewinds.")
    }
}
