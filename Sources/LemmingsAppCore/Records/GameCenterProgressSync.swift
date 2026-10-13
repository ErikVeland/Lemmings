import CryptoKit
import Foundation
import NxlvKit

@MainActor public protocol GameProgressTransport: AnyObject {
    var available: Bool { get }
    /// A team-scoped Game Center identity, shared by the Mac and iOS app IDs.
    var accountID: String? { get }
    func load(name: String) async throws -> [Data]
    func save(_ data: Data, name: String) async throws
}

public struct GameProgressArchive: Codable, Equatable, Sendable {
    public let version: Int
    public let owner: String
    public var records: ArcadeRecords
    public var preferences: GameProgressPreferences
    public init(owner: String, records: ArcadeRecords, preferences: GameProgressPreferences) {
        version = 1; self.owner = owner; self.records = records; self.preferences = preferences
    }
    public func validate(owner: String) throws {
        guard version == 1, self.owner == owner, records.profiles.map(\.id) == [ArcadeRecords.cloudProfileID] else {
            throw SequelDataError.invalid("This cloud save belongs to another player or a newer app version.")
        }
        _ = try records.validated()
        guard Set(records.runs.map(\.id)).count == records.runs.count,
            records.statistics.allSatisfy({ key, stats in
                (key.hasSuffix("|\(ArcadeRecords.cloudProfileID)|true") || key.hasSuffix("|\(ArcadeRecords.cloudProfileID)|false"))
                    && [stats.attempts, stats.clears, stats.zeroSaved, stats.allSaved].allSatisfy { (0...1_000_000_000).contains($0) }
                    && stats.clears <= stats.attempts && stats.zeroSaved <= stats.attempts && stats.allSaved <= stats.attempts
            }) else { throw SequelDataError.invalid("Invalid cloud record counts.") }
        try preferences.validate()
    }
    public mutating func merge(_ incoming: Self) throws {
        try incoming.validate(owner: owner)
        try records.mergeCloudRecords(incoming.records, profileID: ArcadeRecords.cloudProfileID)
        records = try records.cloudRecords(profileID: ArcadeRecords.cloudProfileID)
        try preferences.merge(incoming.preferences)
    }
    public static func decode(_ data: Data, owner: String) throws -> Self {
        guard data.count <= 32 * 1024 * 1024 else { throw SequelDataError.invalid("The cloud save is too large.") }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        try archive.validate(owner: owner)
        return archive
    }
}

/// A local save remains authoritative until a validated merge is written locally.
/// Network and encoding work never suspend gameplay or change turn ownership.
@MainActor public final class GameCenterProgressSync {
    public enum State: Equatable { case unavailable, idle, syncing, deferred, offline, failed(String) }
    public private(set) var state: State = .idle
    public var onChange: (@MainActor () -> Void)?
    public var onImported: (@MainActor () -> Void)?
    public var canImport: @MainActor () -> Bool = { true }
    public var isEnabled: @MainActor () -> Bool = { true }
    public var captureExtra: @MainActor (String) -> GameProgressPreferences = { _ in .init() }
    private let store: ArcadeStore
    private let defaults: UserDefaults
    private let transport: any GameProgressTransport
    private var work: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var pending = false
    private var importing = false
    private var synchronizing = false
    public init(store: ArcadeStore, defaults: UserDefaults = .standard, transport: any GameProgressTransport) {
        self.store = store; self.defaults = defaults; self.transport = transport
        if !transport.available { state = .unavailable }
    }
    public static func ownerKey(_ accountID: String) -> String {
        SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func fileName(owner: String) -> String { "ultimate-lemmings-progress-v1-" + owner }

    public func requestSync() {
        guard !importing, transport.available, isEnabled() else { return }
        pending = true
        retry?.cancel(); retry = nil
        guard work == nil, !synchronizing else { return }
        work = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            while self.pending && !Task.isCancelled {
                self.pending = false
                await self.syncNow()
                if case .failed = self.state { break }
                if self.state == .offline { break }
            }
            self.work = nil
        }
    }
    public func syncNow() async {
        guard isEnabled() else { return }
        guard !synchronizing else { pending = true; return }
        synchronizing = true
        defer {
            synchronizing = false
            if pending, work == nil { requestSync() }
        }
        guard transport.available else { setState(.unavailable); return }
        guard let accountID = transport.accountID else { setState(.offline); return }
        let owner = Self.ownerKey(accountID)
        do {
            let profileID = try linkedProfile(owner: owner)
            guard store.profilesAreWritable, store.storageError == nil else { throw SequelDataError.invalid("Local records are not writable.") }
            setState(.syncing)
            let name = Self.fileName(owner: owner)
            let remote = try await transport.load(name: name)
            guard isEnabled() else { return }
            guard transport.accountID == accountID, store.records.profile(profileID) != nil else { setState(.offline); return }
            let revision = store.progressRevision
            let records = store.records
            var preferences = GameProgressPreferences.capture(defaults: defaults, profileID: profileID, profileIDs: records.profiles.map(\.id))
            try preferences.merge(captureExtra(profileID))
            let merged = try await Task.detached(priority: .utility) { [records, preferences] in
                var archive = GameProgressArchive(owner: owner, records: try records.cloudRecords(profileID: profileID), preferences: preferences)
                try archive.validate(owner: owner)
                for data in remote { try archive.merge(GameProgressArchive.decode(data, owner: owner)) }
                return archive
            }.value
            guard transport.accountID == accountID, store.records.profile(profileID) != nil else { setState(.offline); return }
            guard store.progressRevision == revision else { pending = true; return }
            let safe = canImport()
            guard isEnabled() else { return }
            if safe {
                importing = true
                defer { importing = false }
                let changed = try store.mergeCloudRecords(merged.records, profileID: profileID)
                try merged.preferences.apply(defaults: defaults, profileID: profileID)
                if changed || merged.preferences != preferences { onImported?() }
            }
            let upload = try await Task.detached(priority: .utility) { () -> Data? in
                if remote.count == 1, try GameProgressArchive.decode(remote[0], owner: owner) == merged { return nil }
                let data = try JSONEncoder().encode(merged)
                guard data.count <= 32 * 1024 * 1024 else { throw SequelDataError.invalid("The cloud save is too large.") }
                return data
            }.value
            guard transport.accountID == accountID, store.records.profile(profileID) != nil else { setState(.offline); return }
            if let upload { try await transport.save(upload, name: name) }
            guard transport.accountID == accountID else { setState(.offline); return }
            setState(safe ? .idle : .deferred)
        } catch {
            if transport.accountID != accountID { setState(.offline) }
            else if error is SequelDataError || error is DecodingError { setState(.failed(error.localizedDescription)) }
            else {
                setState(.offline)
                retry?.cancel()
                retry = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.requestSync()
                }
            }
        }
    }
    private func linkedProfile(owner: String) throws -> String {
        let binding = "GameCenterProgress.profile." + owner
        if let id = defaults.string(forKey: binding) {
            guard store.records.profile(id) != nil else { throw SequelDataError.invalid("The linked local player was removed.") }
            return id
        }
        let id = store.records.mainProfileID
        let ownership = "GameCenterProgress.owner." + id
        if let previous = defaults.string(forKey: ownership), previous != owner {
            throw SequelDataError.invalid("This player's progress is linked to another Game Center account.")
        }
        defaults.set(owner, forKey: ownership)
        defaults.set(id, forKey: binding)
        return id
    }
    private func setState(_ state: State) { self.state = state; onChange?() }
}
