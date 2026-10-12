import Foundation
import NxlvKit

public struct WorldwideEntry: Equatable, Sendable {
    public let rank: Int
    public let name: String
    public let score: Int
    public init(rank: Int, name: String, score: Int) { self.rank = rank; self.name = name; self.score = score }
}
public struct WorldwideBoard: Equatable, Sendable {
    public let entries: [WorldwideEntry]
    public let personal: WorldwideEntry?
    public let players: Int
    public init(entries: [WorldwideEntry], personal: WorldwideEntry?, players: Int) { self.entries = entries; self.personal = personal; self.players = players }
}
public struct GameCenterAccount: Equatable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}
@MainActor public protocol GameCenterServiceTransport {
    var account: GameCenterAccount? { get }
    func authenticate(completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void)
    func submit(_ score: Int, boardID: String) async throws
    func load(_ boardID: String) async throws -> WorldwideBoard
}

@MainActor open class GameCenterService {
    private let recordsStoreProvider: @MainActor () -> ArcadeStore
    public let configuration: TrolleyOnlineConfiguration?
    private let transport: any GameCenterServiceTransport
    private let defaults: UserDefaults
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var authenticationRequest: UUID?
    private var submitted: [String: Int] = [:]
    private var loadedBoard: WorldwideBoard?
    private var boardAccountID: String?
    public var board: WorldwideBoard? {
        guard let account, account.id == boardAccountID else { return nil }
        return loadedBoard
    }
    public private(set) var boardID: String?
    public private(set) var previousRank: Int?
    public private(set) var status = "Connect Game Center to compare worldwide."
    public private(set) var busy = false
    public var onChange: (() -> Void)?
    public var available: Bool { configuration?.enabled == true && configuration?.isValid == true }
    public var account: GameCenterAccount? { transport.account }
    /// Game Center ranks one person, so exactly one local profile owns the
    /// worldwide scores: the first one created on this Mac. Every other profile
    /// on the same copy keeps local records only. The stored account binding
    /// still records which Apple account was used, so an account change is
    /// detected, but it no longer decides which profile submits.
    public var linkedProfileID: String? { recordsStoreProvider().records.mainProfileID }
    public var linkedProfileInitials: String? {
        linkedProfileID.flatMap { recordsStoreProvider().records.profile($0)?.initials }
    }
    public init(configuration: TrolleyOnlineConfiguration? = nil, transport: any GameCenterServiceTransport, defaults: UserDefaults = .standard, recordsStoreProvider: @escaping @MainActor () -> ArcadeStore) {
        self.recordsStoreProvider = recordsStoreProvider
        self.configuration = configuration ?? Bundle.main.url(forResource: "leaderboards", withExtension: "json", subdirectory: "GameCenter")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(TrolleyOnlineConfiguration.self, from: $0) }
        self.transport = transport; self.defaults = defaults
        if !available { status = "Worldwide rankings are not enabled in this build. Local records are saved." }
    }
    public func connect(profileID: String, boardID: String, history: TrolleyHistory) {
        guard available, !busy else { onChange?(); return }
        let request = UUID(); authenticationRequest = request
        busy = true; status = "Connecting to Game Center..."; onChange?()
        transport.authenticate() { [weak self] result in
            guard let self else { return }
            guard self.authenticationRequest == request else { return }
            self.busy = false
            switch result {
            case .success(let account):
                let key = "GameCenter.profile." + account.id
                if self.defaults.string(forKey: key) == nil { self.defaults.set(profileID, forKey: key) }
                self.refresh(profileID: profileID, boardID: boardID, history: history)
            case .failure(let error):
                self.operation?.cancel(); self.generation = UUID()
                self.status = error.localizedDescription; self.loadedBoard = nil; self.previousRank = nil
                self.onChange?()
            }
        }
    }
    public func refresh(profileID: String, boardID: String, history: TrolleyHistory) {
        operation?.cancel(); generation = UUID()
        previousRank = self.boardID == boardID ? board?.personal?.rank : nil
        self.boardID = boardID; loadedBoard = nil; busy = false
        guard available, let account else {
            authenticationRequest = nil
            status = available ? "Connect Game Center to compare worldwide."
                : "Worldwide rankings are not enabled in this build. Local records are saved."
            onChange?(); return
        }
        let ticket = generation
        let linked = linkedProfileID == profileID
        busy = true
        status = linked ? "Syncing your saved records..."
            : "Viewing worldwide scores. \(linkedProfileInitials ?? "The main profile") holds this Mac's worldwide place. This player keeps local records."
        onChange?()
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == ticket {
                    self.busy = false
                    if self.account?.id != account.id {
                        self.loadedBoard = nil
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
                        guard !Task.isCancelled, self.generation == ticket, self.account?.id == account.id else { return }
                        self.submitted[key] = score
                    } catch { syncFailed = true }
                }
            }
            guard !Task.isCancelled, self.generation == ticket, self.account?.id == account.id else { return }
            do {
                let loaded = try await self.transport.load(boardID)
                guard !Task.isCancelled, self.generation == ticket, self.account?.id == account.id else { return }
                self.loadedBoard = loaded
                self.boardAccountID = account.id
                self.status = syncFailed ? "Scores are saved locally. Retry to finish syncing."
                    : linked ? "Connected as \(account.name). Records synced." : "Viewing as \(account.name). Scores belong to a different local player."
            } catch {
                guard self.generation == ticket else { return }
                self.status = "Game Center is unavailable. Your records are saved. Retry when connected."
            }
            self.busy = false; self.onChange?()
        }
    }
    public func completed(profileID: String, history: TrolleyHistory) {
        guard available, account != nil, linkedProfileID == profileID, let config = configuration else { return }
        refresh(profileID: profileID, boardID: boardID ?? config.starsID, history: history)
    }
    public var rankLabel: String? {
        guard let rank = board?.personal?.rank else { return nil }
        return previousRank.map { $0 > rank ? "#\($0) > #\(rank)" : "#\(rank)" } ?? "#\(rank)"
    }
}

