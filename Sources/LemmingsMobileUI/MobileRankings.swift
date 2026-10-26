#if os(iOS) || os(tvOS)
import AVKit
@preconcurrency import GameKit
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

@MainActor final class MobileGameCenterTransport: GameCenterServiceTransport {
    weak var presenter: UIViewController?
    init(presenter: UIViewController) { self.presenter = presenter }
    var account: GameCenterAccount? {
        let player = GKLocalPlayer.local
        return player.isAuthenticated ? .init(id: player.gamePlayerID, name: player.displayName) : nil
    }
    func authenticate(completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void) {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted" else {
            completion(.failure(URLError(.notConnectedToInternet))); return
        }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                if let controller { self?.presenter?.present(controller, animated: true) }
                else if let account = self?.account { completion(.success(account)) }
                else { completion(.failure(error ?? URLError(.userAuthenticationRequired))) }
            }
        }
    }
    func submit(_ score: Int, boardID: String) async throws {
        try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [boardID])
    }
    func load(_ boardID: String) async throws -> WorldwideBoard {
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [boardID])
        guard let board = boards.first else { throw URLError(.resourceUnavailable) }
        let (personal, entries, count) = try await board.loadEntries(for: .global, timeScope: .allTime,
                                                                   range: NSRange(location: 1, length: 10))
        func entry(_ value: GKLeaderboard.Entry) -> WorldwideEntry {
            .init(rank: value.rank, name: value.player.displayName, score: value.score)
        }
        return .init(entries: entries.map(entry), personal: personal.map(entry), players: count)
    }
}

@MainActor final class MobileRankingsController {
    enum Provider { case community, gameCenter }
    var provider = Provider.community
    var category = HostedCategory.stars
    var conditions: TrolleyConditions?
    let community: HostedRankingsService
    let gameCenter: GameCenterService
    init(presenter: UIViewController, store: ArcadeStore) {
        community = HostedRankingsService(countSharing: { AnonymousTelemetry.shared.sharesCounts }, recordsStoreProvider: { store })
        gameCenter = GameCenterService(transport: MobileGameCenterTransport(presenter: presenter), recordsStoreProvider: { store })
    }
    func completed(_ profileID: String, history: TrolleyHistory) {
        community.completed(profileID: profileID)
        gameCenter.completed(profileID: profileID, history: history)
    }
}

extension MobileLibraryViewController {
    func mobileArcadeLevel(session: any MobileGameSession, summary: MobileLevelSummary, pack: String) -> ArcadeLevel {
        if let tribes = session as? Lemmings2MobileSession {
            let c = tribes.initialRuntime.configuration
            let skills = Dictionary(zip(c.skills, c.supplies).map {
                (TrolleyCapture.skillKey($0.0.name), $0.1)
            }, uniquingKeysWith: +)
            let levelID = c.isPractice ? "practice-\(session.levelIndex)" : "\(session.levelIndex / 10):\(session.levelIndex % 10)"
            let conditions = TrolleyConditions(gameID: "lemmings2", packID: "tribes", levelID: levelID,
                levelFingerprint: session.levelFingerprint, rulesetVersion: session.engineFingerprint,
                physicsMode: session.engineFingerprint, population: c.total, rescueRequirement: 1,
                startingSkills: skills, timeLimitSeconds: Double(c.timeLimit),
                modifiers: ["practice": String(c.isPractice), "releaseInterval": String(c.releaseInterval),
                    "firstReleaseTick": String(c.firstReleaseTick),
                    "practiceSkills": c.isPractice ? c.skills.map { String($0.rawValue) }.joined(separator: ",") : ""])
            return .init(id: session.levelFingerprint, title: summary.title, game: pack,
                rules: session.engineFingerprint, total: c.total, required: 1, conditions: conditions)
        }
        if let chronicles = session as? Lemmings3MobileSession {
            let c = chronicles.initialRuntime.configuration
            let number = (session.levelIndex / 30) * 100 + 1 + session.levelIndex % 30
            let conditions = TrolleyConditions(gameID: "lemmings3", packID: "chronicles", levelID: String(number),
                levelFingerprint: session.levelFingerprint, rulesetVersion: session.engineFingerprint,
                physicsMode: session.engineFingerprint, population: c.total + c.extras.count, rescueRequirement: 1,
                startingSkills: [:], timeLimitSeconds: Double(c.timeLimit),
                modifiers: ["releaseInterval": String(c.releaseInterval), "releaseDelay": String(c.releaseDelay),
                    "reserves": String(c.total), "extras": String(c.extras.count)])
            return .init(id: session.levelFingerprint, title: summary.title, game: pack,
                rules: session.engineFingerprint, total: c.total + c.extras.count, required: 1, conditions: conditions)
        }
        if let initial = session.actionReplayInitial, case let .neolemmix(game) = initial {
            let c = game.configuration
            let parts = session.levelIdentifier.split(separator: "/", maxSplits: 2).map(String.init)
            let skills = Dictionary(c.skills.map { (TrolleyCapture.skillKey($0.key.rawValue), $0.value.availableCount ?? -1) }, uniquingKeysWith: +)
            let conditions = TrolleyConditions(gameID: "neolemmix", packID: parts.count > 1 ? parts[1] : pack,
                levelID: parts.count > 2 ? parts[2] : session.levelIdentifier,
                levelFingerprint: session.levelFingerprint, rulesetVersion: session.engineFingerprint,
                physicsMode: session.engineFingerprint, population: c.totalLemmings, rescueRequirement: c.requiredToSave,
                startingSkills: skills, timeLimitSeconds: c.timeLimitTicks.map { Double($0) / session.ticksPerSecond },
                modifiers: ["spawnInterval": String(c.spawnInterval), "spawnIntervalLocked": String(c.spawnIntervalLocked)])
            return .init(id: session.levelFingerprint, title: summary.title, game: pack,
                rules: session.engineFingerprint, total: c.totalLemmings, required: c.requiredToSave, conditions: conditions)
        }
        guard let classic = session as? ClassicMobileSession else {
            return .init(id: session.levelFingerprint, title: summary.title, game: pack,
                         rules: session.engineFingerprint, total: session.snapshot.total, required: session.snapshot.required)
        }
        let initial = classic.initialSimulation
        let snapshot = session.snapshot
        let fingerprint = TrolleyCapture.classicFingerprint(initial)
        let starting = Dictionary(initial.configuration.initialSkills.map { (TrolleyCapture.skillKey($0.key.rawValue), $0.value) }, uniquingKeysWith: +)
        let canonical = mobileRankings.gameCenter.configuration?.levels.first {
            $0.conditions.levelFingerprint == fingerprint && $0.conditions.startingSkills == starting
                && $0.conditions.population == snapshot.total && $0.conditions.rescueRequirement == snapshot.required
                && $0.conditions.timeLimitSeconds == initial.remainingTimeSeconds.map(Double.init)
        }?.conditions
        let official = ClassicTitle.allCases.first { session.levelIdentifier.hasPrefix($0.rawValue + "-") }
        var gameID = official?.rawValue ?? (pack.hasPrefix("release/") ? String(pack.dropFirst(8)) : "fan")
        var packID = official == nil ? pack : String(session.levelIdentifier.split(separator: "/").first ?? Substring(pack))
        var levelID = official == nil ? session.levelIdentifier : "level-\(session.levelIndex)"
        if session.levelIdentifier.hasPrefix("fan/") {
            gameID = "fan"
            let parts = session.levelIdentifier.split(separator: "/", maxSplits: 3)
            if parts.count == 4 {
                if let found = catalogue?.pack(id: String(parts[1])), case let .fan(file) = found.source { packID = file.lastPathComponent }
                let key = String(parts[3])
                if let divider = key.lastIndex(of: "#") {
                    let section = String(key[key.index(after: divider)...])
                    levelID = String(key[..<divider]) + ":" + (section == "-1" ? "whole-file" : section)
                }
            }
        }
        let conditions = canonical ?? TrolleyConditions(gameID: gameID,
            packID: packID, levelID: levelID, levelFingerprint: fingerprint,
            rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1", population: snapshot.total,
            rescueRequirement: snapshot.required, startingSkills: starting,
            timeLimitSeconds: initial.remainingTimeSeconds.map(Double.init))
        return .init(id: conditions.gameID + ":" + conditions.levelID, title: summary.title, game: pack,
                     rules: "classic-dos-v1", total: snapshot.total, required: snapshot.required, conditions: conditions)
    }

    func rankingsPage(subtitle: String) -> GameFrontEnd.Page {
        let rankings = mobileRankings
        let community = rankings.provider == .community
        let busy = community ? rankings.community.busy : rankings.gameCenter.busy
        var rows: [GameFrontEnd.Action] = []
        if community {
            rows.append(.init("rankCategory", rankings.category.title, enabled: !busy))
            rows.append(.init("rankShare", L10n.text("Share records"), enabled: rankings.community.endpoint != nil,
                              selected: rankings.community.sharing(profiles.activeID)))
            for entry in rankings.community.board?.entries ?? [] {
                rows.append(.init("rankReplay.\(entry.rank)", "#\(entry.rank)  \(entry.name)  " + rankings.category.score(entry.score),
                                  enabled: (entry.replay || (entry.actionReplay == true && rankings.conditions != nil)) && !busy))
            }
        } else {
            if let config = rankings.gameCenter.configuration {
                let level = config.levels.first { $0.conditions == rankings.conditions }
                let choices: [(String, String?)] = [(L10n.text("Career stars"), config.starsID), (L10n.text("Levels cleared"), config.clearsID),
                    (L10n.text("Three-star levels"), config.perfectID), (L10n.text("This level"), level?.leaderboardID),
                    (L10n.text("Fastest clear"), level?.fastestClearID), (L10n.text("Fastest 100%"), level?.fastestAllSavedID)]
                for (title, boardID) in choices {
                    rows.append(.init("rankBoard." + (boardID ?? title), title,
                        enabled: boardID != nil && rankings.gameCenter.available && !busy,
                        selected: boardID == (rankings.gameCenter.boardID ?? config.starsID)))
                }
            }
            let speedBoard = rankings.gameCenter.configuration?.levels.contains {
                $0.fastestClearID == rankings.gameCenter.boardID || $0.fastestAllSavedID == rankings.gameCenter.boardID
            } ?? false
            for entry in rankings.gameCenter.board?.entries ?? [] {
                let score = speedBoard ? HostedCategory.fastestClear.score(entry.score) : String(entry.score)
                rows.append(.init("rankRow.\(entry.rank)", "#\(entry.rank)  \(entry.name)  " + score, enabled: false))
            }
        }
        let loaded = community ? rankings.community.board != nil : rankings.gameCenter.board != nil
        let empty = community ? rankings.community.board?.entries.isEmpty == true : rankings.gameCenter.board?.entries.isEmpty == true
        let status = busy ? "" : empty ? L10n.text("No scores") : loaded ? "" : community ? rankings.community.status : rankings.gameCenter.status
        return MobileCareerArt.rankings(community: community, subtitle: subtitle, busy: busy,
            status: status, rows: rows, connected: rankings.gameCenter.account != nil,
            available: community ? rankings.community.endpoint != nil : rankings.gameCenter.available)
    }

    func handleRankings(_ id: String) -> Bool {
        let rankings = mobileRankings
        switch id {
        case "worldwide":
            rankings.conditions = arcadeStore.records.runs.last { $0.profileID == profiles.activeID }?.level.conditions
            rankings.community.onChange = { [weak self] in if self?.route == .rankings { self?.rebuild() } }
            rankings.gameCenter.onChange = { [weak self] in if self?.route == .rankings { self?.rebuild() } }
            navigate(.rankings); refreshRankings()
        case "rankCommunity": rankings.provider = .community; rebuild()
        case "rankGameCenter": rankings.provider = .gameCenter; rebuild()
        case "rankCategory":
            let available = HostedCategory.allCases.filter { $0.career || rankings.conditions != nil }
            let index = available.firstIndex(of: rankings.category) ?? 0
            rankings.category = available[(index + 1) % available.count]; refreshRankings()
        case "rankShare":
            rankings.community.setSharing(!rankings.community.sharing(profiles.activeID), profile: profiles.activeID); rebuild()
        case "rankRefresh": refreshRankings()
        default:
            if id.hasPrefix("rankBoard.") {
                refreshRankings(boardID: String(id.dropFirst(10)))
                return true
            }
            guard id.hasPrefix("rankReplay."), let rank = Int(id.dropFirst(11)),
                  let entry = rankings.community.board?.entries.first(where: { $0.rank == rank }) else { return false }
            if entry.actionReplay == true, let conditions = rankings.conditions {
                rankings.community.playbackActions(entry, conditions: conditions) { [weak self] replay, title in
                    self?.showRankedActionReplay(replay, title: title)
                }
                return true
            }
            rankings.community.playback(entry) { [weak self] file, _ in
                guard let self else { return }
                do {
                    let preserved = FileManager.default.temporaryDirectory.appendingPathComponent("rank-replay-" + UUID().uuidString + ".mp4")
                    try FileManager.default.copyItem(at: file, to: preserved)
                    let player = AVPlayerViewController(); player.player = AVPlayer(url: preserved)
                    player.player?.isMuted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
                    self.present(player, animated: true) { player.player?.play() }
                } catch { self.notice = error.localizedDescription; self.rebuild() }
            }
        }
        return true
    }

    func showRankedActionReplay(_ replay: LeaderboardActionReplay, title: String) {
        Task {
            do {
                let content = try loadMobileRankedContent(replay.conditions)
                let document: Data
                if let classic = content.session as? ClassicMobileSession {
                    let initial = classic.initialSimulation
                    document = try await Task.detached(priority: .userInitiated) {
                        try replay.classicReplay(initial: initial, title: title)
                    }.value
                } else {
                    document = try MobileActionReplayDocument.checked(replay, session: content.session)
                }
                guard let session = try content.session.makeReplaySession(document: document) else {
                    throw MobileSessionError.invalidCheckpoint
                }
                let store = MobileCheckpointStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("leaderboard-replay-" + UUID().uuidString))
                let player = MobileGameViewController(summary: content.summary, session: session, checkpointStore: store, restoredCheckpoint: nil,
                    settingsProfileID: settingsProfileID)
                player.modalPresentationStyle = .fullScreen
                present(player, animated: false)
            } catch { notice = error.localizedDescription; rebuild() }
        }
    }

    func refreshRankings(boardID: String? = nil) {
        let rankings = mobileRankings
        if rankings.provider == .community {
            rankings.community.refresh(conditions: rankings.conditions, category: rankings.category, assisted: false)
        } else if let config = rankings.gameCenter.configuration {
            let board = boardID ?? rankings.gameCenter.boardID ?? config.starsID
            if rankings.gameCenter.account == nil {
                rankings.gameCenter.connect(profileID: profiles.activeID, boardID: board, history: arcadeStore.records.trolley)
            } else {
                rankings.gameCenter.refresh(profileID: profiles.activeID, boardID: board, history: arcadeStore.records.trolley)
            }
        }
    }
}
#endif
