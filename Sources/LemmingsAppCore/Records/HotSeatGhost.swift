import Foundation
import CryptoKit
import NxlvKit

/// One completed turn, including a loss. The session and starting state scope its ghosts.
public struct HotSeatGhostAttempt: Codable, Sendable {
    public let playerID: String
    public let colour: ReplayGhostColour
    public let replay: LeaderboardActionReplay

    public init(playerID: String, colour: ReplayGhostColour, replay: LeaderboardActionReplay) {
        self.playerID = playerID; self.colour = colour; self.replay = replay
    }
}

/// Silent, independent engines follow simulation time, including paused steps and rewind.
public struct HotSeatGhostPlayback: Sendable {
    public struct Frame: Sendable {
        public let playerID: String
        public let colour: ReplayGhostColour
        public let state: ActionReplayState
    }
    private struct Track: Sendable {
        let playerID: String
        let colour: ReplayGhostColour
        var cursor: ActionReplayCursor
        var failed = false
    }
    private var tracks: [Track] = []
    public var count: Int { tracks.count }
    /// A local display choice. Hidden ghosts keep their tracks and reappear at the current tick.
    public var hidden = false

    public init(attempts: [HotSeatGhostAttempt], initial: ActionReplayState) {
        guard let hash = try? initial.hash() else { return }
        tracks = attempts.prefix(8).compactMap { attempt in
            guard attempt.replay.initialStateHash == hash,
                  attempt.replay.engine == initial.engine,
                  RunRecovery.isCompatibleEngine(attempt.replay.engineFingerprint),
                  (try? attempt.replay.validateStructure()) != nil,
                  let cursor = try? ActionReplayCursor(replay: attempt.replay, initial: initial) else { return nil }
            return Track(playerID: attempt.playerID, colour: attempt.colour, cursor: cursor)
        }
    }

    public mutating func frames(at tick: Int) -> [Frame] {
        guard !hidden else { return [] }
        var result: [Frame] = []
        for index in tracks.indices {
            guard !tracks[index].failed else { continue }
            do {
                try tracks[index].cursor.seek(to: tick)
                // A finished ghost disappears. Rewinding before its end restores it.
                if tick < tracks[index].cursor.replay.ticks {
                    result.append(Frame(playerID: tracks[index].playerID, colour: tracks[index].colour,
                                        state: tracks[index].cursor.state))
                }
            } catch { tracks[index].failed = true }
        }
        return result
    }
}

/// Keeps the latest turn per other player for exactly this session, level and starting state.
public struct HotSeatGhostArchive: Sendable {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }

    private func url(sessionID: String, conditions: String, initialHash: String) -> URL {
        let key = [sessionID, conditions, initialHash].joined(separator: "\n")
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }

    public func attempts(sessionID: String, conditions: String, initialHash: String,
                         excluding playerID: String, players: [String]) -> [HotSeatGhostAttempt] {
        let file = url(sessionID: sessionID, conditions: conditions, initialHash: initialHash)
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= LeaderboardActionReplay.byteLimit * 8,
              let data = try? Data(contentsOf: file),
              let entries = try? JSONDecoder().decode([HotSeatGhostAttempt].self, from: data) else { return [] }
        return entries.filter { $0.playerID != playerID && players.contains($0.playerID)
            && $0.replay.conditions.fingerprint == conditions && $0.replay.initialStateHash == initialHash }
    }

    public func remove(playerID: String) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            where file.pathExtension == "json" {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= LeaderboardActionReplay.byteLimit * 8 else { continue }
            let entries = try JSONDecoder().decode([HotSeatGhostAttempt].self, from: Data(contentsOf: file))
            let remaining = entries.filter { $0.playerID != playerID }
            guard remaining.count != entries.count else { continue }
            if remaining.isEmpty { try FileManager.default.removeItem(at: file) }
            else { try JSONEncoder().encode(remaining).write(to: file, options: .atomic) }
        }
    }

    public func save(_ attempt: HotSeatGhostAttempt, sessionID: String, players: [String]) throws {
        let replay = attempt.replay
        try replay.validateStructure()
        var entries = attempts(sessionID: sessionID, conditions: replay.conditions.fingerprint,
            initialHash: replay.initialStateHash, excluding: attempt.playerID, players: players)
        entries.append(attempt)
        let data = try JSONEncoder().encode(Array(entries.suffix(8)))
        guard data.count <= LeaderboardActionReplay.byteLimit * 8 else { throw RunRecoveryError.invalid }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url(sessionID: sessionID, conditions: replay.conditions.fingerprint,
                              initialHash: replay.initialStateHash), options: .atomic)
    }
}
