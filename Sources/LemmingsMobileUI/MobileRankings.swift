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
    /// World ranks shared players; This device ranks local players.
    var world = true
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

    /// The result screen's level leaderboard. Nil when the level has no ranked conditions.
    func mobileLevelLeaderboard() -> (metric: String, lines: [String])? {
        let community = mobileRankings.community
        guard community.levelConditions != nil else { return nil }
        let category = community.levelCategory
        let rows = community.levelBoard?.entries.prefix(3).map { HostedLeaderboardText.row($0, category: category) } ?? []
        let leaders = HostedLeaderboardText.leaders(community.levelBoard, category: category)
        let lines = (leaders.map { [$0] } ?? []) + rows
        return (category.title, lines.isEmpty ? (community.levelStatus.isEmpty ? [] : [community.levelStatus]) : lines)
    }

    func rankingsPage(subtitle: String) -> GameFrontEnd.Page {
        let rankings = mobileRankings, community = rankings.community
        let rows: [GameFrontEnd.Action]
        if rankings.world {
            let me = profiles.active.name
            rows = (community.board?.entries ?? []).map { entry in
                .init("rankReplay.\(entry.rank)", entry.stars == nil
                      ? "\(entry.rank).  \(entry.name)   " + rankings.category.score(entry.score)
                      : MobileCareerArt.careerRowTitle(rank: entry.rank, name: entry.name, stars: entry.stars ?? 0,
                                                       clears: entry.clears ?? 0, perfect: entry.perfect ?? 0),
                      enabled: entry.replay, selected: entry.name == me)
            }
        } else {
            rows = MobileCareerArt.localLeaderboardRows(records: arcadeStore.records, category: rankings.category, activeID: profiles.activeID)
        }
        return MobileCareerArt.leaderboards(world: rankings.world, category: rankings.category, rows: rows,
            busy: rankings.world && community.busy, status: rankings.world ? community.status : "",
            sharing: community.endpoint == nil ? nil : community.sharing(profiles.activeID),
            gameCenter: rankings.gameCenter.available)
    }

    func handleRankings(_ id: String) -> Bool {
        let rankings = mobileRankings
        switch id {
        case "worldwide":
            rankings.conditions = arcadeStore.records.runs.last { $0.profileID == profiles.activeID }?.level.conditions
            rankings.community.onChange = { [weak self] in if self?.route == .rankings { self?.rebuild() } }
            rankings.gameCenter.onChange = { [weak self] in if self?.route == .rankings { self?.rebuild() } }
            navigate(.rankings); refreshRankings()
        case "rankScope.world": rankings.world = true; refreshRankings(); rebuild()
        case "rankScope.local": rankings.world = false; rebuild()
        case "rankGameCenter": showGameCenterLeaderboards()
        case "rankShare":
            rankings.community.setSharing(!rankings.community.sharing(profiles.activeID), profile: profiles.activeID); rebuild()
        default:
            if id.hasPrefix("rankCategory."), let category = HostedCategory(rawValue: String(id.dropFirst(13))) {
                rankings.category = category
                if rankings.world { refreshRankings() }
                rebuild(); return true
            }
            guard id.hasPrefix("rankReplay."), let rank = Int(id.dropFirst(11)),
                  let entry = rankings.community.board?.entries.first(where: { $0.rank == rank }) else { return false }
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

    func refreshRankings() {
        mobileRankings.community.refresh(conditions: nil, category: mobileRankings.category, assisted: false)
    }

    /// Game Center keeps its own ranking screen. Sign in first when the player has not connected yet.
    func showGameCenterLeaderboards() {
        let rankings = mobileRankings
        guard let config = rankings.gameCenter.configuration, rankings.gameCenter.available else { return }
        if rankings.gameCenter.account == nil {
            rankings.gameCenter.connect(profileID: profiles.activeID, boardID: config.starsID, history: arcadeStore.records.trolley)
            return
        }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = MobileGameCenterDismissal.shared
        present(controller, animated: true)
    }
}

@MainActor final class MobileGameCenterDismissal: NSObject, GKGameCenterControllerDelegate {
    static let shared = MobileGameCenterDismissal()
    nonisolated func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
        Task { @MainActor in controller.dismiss(animated: true) }
    }
}
#endif
