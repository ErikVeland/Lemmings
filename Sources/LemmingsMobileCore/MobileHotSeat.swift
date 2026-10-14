import Foundation

/// One shared campaign for two or more players on one device.
///
/// The roster, the turn and the house rule live here. Progress for the shared
/// campaign is stored under `scope`, apart from every solo player.
public struct MobileHotSeat: Codable, Equatable, Identifiable, Sendable {
    public enum TurnPolicy: String, CaseIterable, Codable, Sendable {
        case everyLevel
        case atFirstFail

        public var title: String { self == .everyLevel ? "Every level" : "At first fail" }
        public var other: TurnPolicy { self == .everyLevel ? .atFirstFail : .everyLevel }
    }

    /// One button on a result page. `player` is the player who acts next.
    public struct Choice: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case next, retry }
        public let kind: Kind
        public let player: String
        public let primary: Bool
    }

    public static let minimumPlayers = 2

    public let id: String
    public let host: String
    public private(set) var players: [String]
    public private(set) var turn: String
    public var policy: TurnPolicy
    public var savedAt: Date

    /// Keys the shared campaign's progress and checkpoints.
    public var scope: String { "hotseat." + id }

    /// A session needs two players, and the host is always one of them.
    public init?(host: String, players: [String], policy: TurnPolicy = .everyLevel,
                 id: String = UUID().uuidString.lowercased(), savedAt: Date = Date()) {
        var roster: [String] = []
        for player in [host] + players where !roster.contains(player) { roster.append(player) }
        guard roster.count >= Self.minimumPlayers, roster.count <= MobileProfiles.maximum else { return nil }
        self.id = id
        self.host = host
        self.players = roster
        self.turn = host
        self.policy = policy
        self.savedAt = savedAt
    }

    // MARK: - Turns

    /// The player after `id` in roster order, or nil when `id` is not playing.
    public func nextPlayer(after id: String) -> String? {
        guard let index = players.firstIndex(of: id) else { return nil }
        return players[(index + 1) % players.count]
    }

    public var next: String { nextPlayer(after: turn) ?? host }

    public mutating func pass(to player: String) {
        guard players.contains(player) else { return }
        turn = player
        savedAt = Date()
    }

    /// The buttons a result page offers. Each names the player who will act.
    public func choices(didWin: Bool) -> [Choice] {
        let current = turn, following = next
        var result: [Choice] = []
        func add(_ kind: Choice.Kind, _ player: String, primary: Bool = false) {
            if !result.contains(where: { $0.kind == kind && $0.player == player }) {
                result.append(Choice(kind: kind, player: player, primary: primary))
            }
        }
        if !didWin {
            add(.retry, following, primary: true)
            add(.retry, current)
        } else if policy == .everyLevel {
            add(.next, following, primary: true)
            add(.retry, current)
            add(.retry, following)
        } else {
            add(.next, current, primary: true)
            add(.retry, current)
            add(.retry, following)
        }
        return result
    }

    // MARK: - Roster

    /// Removes a player who left the device. The host cannot leave, and two players are the least.
    public func removing(_ player: String) -> MobileHotSeat? {
        guard player != host, players.contains(player) else { return self }
        var copy = self
        copy.players.removeAll { $0 == player }
        guard copy.players.count >= Self.minimumPlayers else { return nil }
        // A player who leaves cannot still be holding the turn.
        if copy.turn == player { copy.turn = nextPlayer(after: player).flatMap { copy.players.contains($0) ? $0 : nil } ?? copy.host }
        return copy
    }

    /// The same players and rule, starting again from the beginning with the host.
    public func restarted() -> MobileHotSeat {
        MobileHotSeat(host: host, players: players, policy: policy) ?? self
    }
}

/// The roster being chosen before a session starts. The host stays in it.
public struct MobileHotSeatRoster: Equatable, Sendable {
    public let host: String
    public private(set) var players: [String]

    public init(host: String, players: [String] = []) {
        self.host = host
        self.players = [host] + players.filter { $0 != host }
    }

    public var canStart: Bool { players.count >= MobileHotSeat.minimumPlayers }

    /// Adds or removes a player. The host cannot be removed.
    public mutating func toggle(_ player: String) {
        if player == host { return }
        if let index = players.firstIndex(of: player) { players.remove(at: index) }
        else if players.count < MobileProfiles.maximum { players.append(player) }
    }

    public func contains(_ player: String) -> Bool { players.contains(player) }
}

/// The running session and the earlier ones the host can resume.
public struct MobileHotSeatStore: Codable, Equatable, Sendable {
    public static let historyLimit = 200

    public private(set) var current: MobileHotSeat?
    public private(set) var saved: [MobileHotSeat] = []
    /// The house rule the next session starts with.
    public var policy: MobileHotSeat.TurnPolicy = .everyLevel

    public init() {}

    /// Keeps legacy TV sessions and their current turn during the shared-frontend upgrade.
    public mutating func importLegacySessions(_ sessions: [MobileHotSeat], activeScope: String?) {
        for seat in sessions.sorted(by: { $0.savedAt > $1.savedAt }) {
            guard current?.id != seat.id, !saved.contains(where: { $0.id == seat.id }) else { continue }
            if current == nil, seat.scope == activeScope { current = seat; policy = seat.policy }
            else { saved.append(seat) }
        }
        saved.sort { $0.savedAt > $1.savedAt }
    }

    private static let name = "hotseat"

    public static func load(from storage: MobileStorage) -> MobileHotSeatStore {
        storage.load(MobileHotSeatStore.self, name: name) ?? MobileHotSeatStore()
    }

    public func save(to storage: MobileStorage) throws { try storage.save(self, name: Self.name) }

    /// Starts a new shared campaign. The running one moves to Saved Hot Seats.
    @discardableResult
    public mutating func start(roster: MobileHotSeatRoster) -> MobileHotSeat? {
        guard roster.canStart, var session = MobileHotSeat(host: roster.host, players: roster.players, policy: policy) else { return nil }
        session.policy = policy
        archive()
        current = session
        return session
    }

    public mutating func update(_ session: MobileHotSeat) {
        guard current?.id == session.id else { return }
        current = session
        if session.policy != policy { policy = session.policy }
    }

    /// Returns to solo play and keeps the shared campaign for later.
    public mutating func endSession() { archive(); current = nil }

    /// Starts the shared campaign again from the beginning with the same players.
    @discardableResult
    public mutating func restart() -> MobileHotSeat? {
        guard let running = current else { return nil }
        let fresh = running.restarted()
        archive()
        current = fresh
        return fresh
    }

    /// Sessions the host can resume, newest first.
    public func resumable(host: String) -> [MobileHotSeat] { saved.filter { $0.host == host } }
    public func sharedSessions(player: String) -> [MobileHotSeat] { saved.filter { $0.players.contains(player) } }

    @discardableResult
    public mutating func resume(id: String) -> MobileHotSeat? {
        guard let index = saved.firstIndex(where: { $0.id == id }) else { return nil }
        let chosen = saved.remove(at: index)
        archive()
        current = chosen
        policy = chosen.policy
        return chosen
    }

    /// Applies a player's departure to every session. A session left with one player ends.
    public mutating func removePlayer(_ player: String) {
        func apply(_ session: MobileHotSeat) -> MobileHotSeat? { session.host == player ? nil : session.removing(player) }
        current = current.flatMap(apply)
        saved = saved.compactMap(apply)
    }
    /// Imports safe-menu cloud sessions without selecting a different campaign.
    public mutating func importCloudSessions(_ sessions: [MobileHotSeat]) {
        for seat in sessions {
            if current?.id == seat.id { current = seat; policy = seat.policy }
            else {
                saved.removeAll { $0.id == seat.id }; saved.append(seat)
            }
        }
        saved.sort { $0.savedAt > $1.savedAt }
    }

    private mutating func archive() {
        guard let running = current else { return }
        saved.removeAll { $0.id == running.id }
        saved.insert(running, at: 0)
        if saved.count > Self.historyLimit { saved.removeLast(saved.count - Self.historyLimit) }
    }
}
