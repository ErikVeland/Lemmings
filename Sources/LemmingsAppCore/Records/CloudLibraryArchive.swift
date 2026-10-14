import CryptoKit
import Foundation
import NxlvKit

/// Portable identities are independent of Apple accounts and device profile IDs.
public struct CloudLibraryIdentity: Codable, Equatable, Sendable {
    public let version: Int
    public let id: String
    public let token: String
    public let key: Data
    public init() {
        version = 1; id = UUID().uuidString.lowercased()
        key = Self.randomBytes()
        token = Self.randomBytes().map { String(format: "%02x", $0) }.joined()
    }
    private static func randomBytes() -> Data {
        // CryptoKit obtains key material from the operating system CSPRNG.
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }
    public func validate() throws {
        guard version == 1, UUID(uuidString: id)?.uuidString.lowercased() == id, key.count == 32,
              token.count == 64, token == token.lowercased(), token.allSatisfy({ $0.isHexDigit && $0.isASCII }) else {
            throw SequelDataError.invalid(L10n.text("The library key is invalid."))
        }
    }
    public func seal(_ data: Data) throws -> Data {
        try validate()
        return try AES.GCM.seal(data, using: SymmetricKey(data: key), authenticating: Data(id.utf8)).combined!
    }
    public func open(_ data: Data) throws -> Data {
        try validate()
        guard data.count <= CloudLibraryArchive.maximumBytes + 28 else { throw SequelDataError.invalid(L10n.text("The cloud save is too large.")) }
        return try AES.GCM.open(.init(combined: data), using: SymmetricKey(data: key), authenticating: Data(id.utf8))
    }
}

public struct CloudLibraryArchive: Codable, Equatable, Sendable {
    public static let maximumBytes = 8 * 1024 * 1024
    public struct Stamp: Codable, Equatable, Comparable, Sendable {
        public let counter: UInt64
        public let device: String
        public init(counter: UInt64, device: String) { self.counter = counter; self.device = device }
        public static func < (a: Self, b: Self) -> Bool {
            a.counter == b.counter ? a.device < b.device : a.counter < b.counter
        }
    }
    public struct Player: Codable, Equatable, Sendable {
        public var profile: ArcadeProfile
        public var records: ArcadeRecords
        public var progress: GameProgressPreferences
        public var stamp: Stamp
        /// Original UUIDs retain identity when older builds assigned a cloud UUID.
        public var sourceProfileIDs: Set<String>?
        public init(profile: ArcadeProfile, records: ArcadeRecords, progress: GameProgressPreferences, stamp: Stamp,
                    sourceProfileIDs: Set<String>? = nil) {
            self.profile = profile; self.records = records; self.progress = progress; self.stamp = stamp
            self.sourceProfileIDs = sourceProfileIDs
        }
    }
    public struct Seat: Codable, Equatable, Sendable {
        public var id: String
        public var host: String
        public var players: [String]
        public var turn: String
        public var everyLevel: Bool
        public var progress: GameProgressPreferences
        public var revision: String
        public var ancestors: Set<String>
        public var stamp: Stamp
        public var savedAt: Date
        public init(id: String, host: String, players: [String], turn: String, everyLevel: Bool,
                    progress: GameProgressPreferences, revision: String = UUID().uuidString.lowercased(),
                    ancestors: Set<String> = [], stamp: Stamp, savedAt: Date = Date()) {
            self.id = id; self.host = host; self.players = players; self.turn = turn; self.everyLevel = everyLevel
            self.progress = progress; self.revision = revision; self.ancestors = ancestors; self.stamp = stamp
            self.savedAt = savedAt
        }
        /// A stable namespace preserves both sides of an offline shared-campaign conflict.
        public var branchID: String {
            let hex = SHA256.hash(data: Data((id + revision).utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
            return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        }
        public func sameState(as other: Self) -> Bool {
            id == other.id && host == other.host && players == other.players && turn == other.turn
                && everyLevel == other.everyLevel && progress == other.progress
        }
    }
    public let version: Int
    public var players: [String: Player]
    public var deleted: Set<String>
    public var seats: [String: [Seat]]
    public var primary: String?
    public init(players: [String: Player] = [:], deleted: Set<String> = [], seats: [String: [Seat]] = [:], primary: String? = nil) {
        version = 2; self.players = players; self.deleted = deleted; self.seats = seats; self.primary = primary
    }
    public var counter: UInt64 {
        max(players.values.map(\.stamp.counter).max() ?? 0, seats.values.flatMap { $0 }.map(\.stamp.counter).max() ?? 0)
    }
    public func validate() throws {
        guard version == 2, players.count <= 8, deleted.count <= 10_000, seats.count <= 200 else {
            throw SequelDataError.invalid(L10n.text("This library needs a newer app or exceeds its limits."))
        }
        guard primary.map({ players[$0] != nil }) ?? true else { throw SequelDataError.invalid(L10n.text("The primary cloud player is missing.")) }
        for id in deleted { guard UUID(uuidString: id) != nil else { throw SequelDataError.invalid("Invalid removed player.") } }
        for (id, player) in players {
            guard UUID(uuidString: id) != nil, player.profile.id == id, !deleted.contains(id),
                player.records.profiles.map(\.id) == [ArcadeRecords.cloudProfileID], player.stamp.counter < UInt64.max,
                UUID(uuidString: player.stamp.device) != nil else { throw SequelDataError.invalid("Invalid cloud player.") }
            guard (player.sourceProfileIDs?.count ?? 0) <= 64,
                (player.sourceProfileIDs ?? []).allSatisfy({ UUID(uuidString: $0)?.uuidString.lowercased() == $0 }) else {
                throw SequelDataError.invalid(L10n.text("Invalid source player identity."))
            }
            _ = try player.records.validated()
            // The existing per-player archive validation also checks event and statistics ownership.
            try GameProgressArchive(owner: id, records: player.records, preferences: player.progress).validate(owner: id)
        }
        for (id, branches) in seats {
            guard UUID(uuidString: id) != nil, !branches.isEmpty, branches.count <= 32,
                Set(branches.map(\.revision)).count == branches.count else { throw SequelDataError.invalid("Invalid shared campaign.") }
            for seat in branches {
                guard seat.id == id, UUID(uuidString: seat.revision) != nil, seat.ancestors.count <= 10_000,
                    !seat.ancestors.contains(seat.revision), seat.ancestors.allSatisfy({ UUID(uuidString: $0) != nil }),
                    (2...8).contains(seat.players.count), Set(seat.players).count == seat.players.count,
                    seat.players.contains(seat.host), seat.players.contains(seat.turn),
                    seat.players.allSatisfy({ players[$0] != nil }), seat.stamp.counter < UInt64.max,
                    UUID(uuidString: seat.stamp.device) != nil else { throw SequelDataError.invalid(L10n.text("Invalid shared campaign owner.")) }
                try seat.progress.validate()
            }
        }
    }
    public mutating func merge(_ incoming: Self) throws {
        try validate(); try incoming.validate()
        var result = self
        result.deleted.formUnion(incoming.deleted)
        // A stale copied save can still use the original UUID of an older cloud
        // identity. Deletion applies to those UUIDs as well as the cloud UUID.
        for (id, player) in result.players.merging(incoming.players, uniquingKeysWith: { a, b in
            var merged = a
            merged.sourceProfileIDs = (a.sourceProfileIDs ?? []).union(b.sourceProfileIDs ?? [])
            return merged
        }) where result.deleted.contains(id) {
            result.deleted.formUnion(player.sourceProfileIDs ?? [])
        }
        for (id, player) in incoming.players where !result.deleted.contains(id) {
            guard var local = result.players[id] else { result.players[id] = player; continue }
            try local.records.mergeCloudRecords(player.records, profileID: ArcadeRecords.cloudProfileID)
            local.records = try local.records.cloudRecords(profileID: ArcadeRecords.cloudProfileID)
            try local.progress.merge(player.progress)
            let sources = (local.sourceProfileIDs ?? []).union(player.sourceProfileIDs ?? [])
            local.sourceProfileIDs = sources.isEmpty ? nil : sources
            if local.stamp < player.stamp { local.profile = player.profile; local.stamp = player.stamp }
            else if local.stamp == player.stamp && local.profile != player.profile {
                throw SequelDataError.invalid(L10n.text("Cloud player edits conflict."))
            }
            result.players[id] = local
        }
        result.players = result.players.filter { !result.deleted.contains($0.key) }
        result.primary = [primary, incoming.primary].compactMap { $0 }.filter { result.players[$0] != nil }.min()
            ?? result.players.keys.sorted().first
        for (id, remote) in incoming.seats {
            var branches = result.seats[id] ?? []
            for seat in remote {
                if let same = branches.first(where: { $0.revision == seat.revision }) {
                    guard same == seat else { throw SequelDataError.invalid(L10n.text("Shared campaign revisions conflict.")) }
                } else { branches.append(seat) }
            }
            let ancestors = branches.reduce(into: Set<String>()) { $0.formUnion($1.ancestors) }
            result.seats[id] = branches.filter { !ancestors.contains($0.revision) }.sorted { $0.revision < $1.revision }
        }
        result.seats = result.seats.filter { $0.value.allSatisfy { seat in seat.players.allSatisfy { result.players[$0] != nil } } }
        try result.validate(); self = result
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw SequelDataError.invalid(L10n.text("The cloud save is too large.")) }
        return data
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw SequelDataError.invalid(L10n.text("The cloud save is too large.")) }
        let value = try JSONDecoder().decode(Self.self, from: data); try value.validate(); return value
    }
}
