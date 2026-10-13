import Foundation
import NxlvKit

/// One merge coordinator for every profile and all three campaign engines.
/// Provider failures never prevent local play or replace another device's save.
@MainActor public final class CloudLibrarySync {
    public enum State: Equatable { case idle, syncing, synced, pending, offline, paused, failed(String) }
    public private(set) var state: State = .idle
    public private(set) var lastSynced: Date?
    public var onChange: (@MainActor () -> Void)?
    public var onImported: (@MainActor () -> Void)?
    public var canImport: @MainActor () -> Bool = { true }
    public var captureExtra: @MainActor (String, String?) throws -> GameProgressPreferences = { _, _ in .init() }
    public var captureSeats: @MainActor () -> [ArcadeStore.SavedHotSeat] = { [] }
    public var importSeats: @MainActor ([ArcadeStore.SavedHotSeat]) throws -> Void = { _ in }
    private let store: ArcadeStore
    private let defaults: UserDefaults
    private let transport: any CloudLibraryTransport
    private let stateFile: URL
    private var identities: [CloudLibraryIdentity]
    private var saved = LocalState()
    private var running = false
    private var task: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var requested = false
    private var stateReadFailed = false
    private struct LocalState: Codable {
        var mapping: [String: String] = [:]
        var archive = CloudLibraryArchive()
        var seatRevisions: [String: String] = [:]
        var device = UUID().uuidString.lowercased()
    }
    public init(store: ArcadeStore, storage: AppStorage = .current(), transport: any CloudLibraryTransport,
                identities: [CloudLibraryIdentity] = []) {
        self.store = store; defaults = storage.defaults; self.transport = transport
        self.identities = identities
        stateFile = storage.applicationSupport.appendingPathComponent("Cloud Library/local-state-v2.json")
        if let data = try? Data(contentsOf: stateFile) {
            do { saved = try JSONDecoder().decode(LocalState.self, from: data); try saved.archive.validate() }
            catch { stateReadFailed = true; state = .failed("Cloud sync state could not be read. Existing saves were kept.") }
        }
    }
    public var status: String {
        switch state {
        case .idle: "Cloud saves"
        case .syncing: "Syncing"
        case .synced: "Synced"
        case .pending: "Saved on this device"
        case .offline: "Offline - saved on this device"
        case .paused: "Cloud saves paused"
        case .failed(let message): message
        }
    }
    public var enabled: Bool {
        get { defaults.object(forKey: "CloudLibrary.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "CloudLibrary.enabled"); if newValue { requestSync() } else { setState(.paused) } }
    }
    public var providerNames: String {
        (transport as? AppleCloudLibraryTransport)?.providers.sorted().joined(separator: " + ") ?? "Cloud"
    }
    public func start() {
        guard ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted" else { return }
        requestSync()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                self?.requestSync()
            }
        }
    }
    public func stop() { timer?.cancel(); timer = nil; task?.cancel(); task = nil }
    public func requestSync() {
        requested = true
        guard task == nil, !running else { return }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            // A save during import/upload gets another pass. An unchanged offline
            // provider waits for the periodic retry or next foreground activation.
            while self.requested && !Task.isCancelled {
                self.requested = false; await self.syncNow()
                if self.state == .offline || { if case .failed = self.state { return true }; return false }() { break }
            }
            self.task = nil
        }
    }
    private func persist(_ value: LocalState) throws {
        try FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: stateFile, options: .atomic)
        saved = value
    }
    private func capture(_ base: LocalState) throws -> LocalState {
        var local = base
        let next = CloudLibraryArchive.Stamp(counter: base.archive.counter + 1, device: base.device)
        let localIDs = Set(store.records.profiles.map(\.id))
        for (id, global) in local.mapping where !localIDs.contains(id) {
            local.archive.deleted.insert(global); local.archive.players[global] = nil
        }
        for profile in store.records.profiles {
            let global = local.mapping[profile.id] ?? UUID().uuidString.lowercased()
            local.mapping[profile.id] = global
            guard !local.archive.deleted.contains(global) else { continue }
            var progress = GameProgressPreferences.capture(defaults: defaults, profileID: profile.id, profileIDs: Array(localIDs))
            try progress.merge(captureExtra(profile.id, nil))
            let metadata = ArcadeProfile(id: global, initials: profile.initials, portrait: profile.portrait)
            let previous = local.archive.players[global]
            var player = CloudLibraryArchive.Player(profile: metadata, records: try store.records.cloudRecords(profileID: profile.id),
                progress: progress, stamp: previous?.profile == metadata ? previous!.stamp : next)
            if let previous {
                try player.records.mergeCloudRecords(previous.records, profileID: ArcadeRecords.cloudProfileID)
                player.records = try player.records.cloudRecords(profileID: ArcadeRecords.cloudProfileID)
                try player.progress.merge(previous.progress)
            }
            local.archive.players[global] = player
        }
        let seats = store.libraryHotSeats + captureSeats()
        for seat in seats {
            guard let host = local.mapping[seat.host], seat.players.allSatisfy({ local.mapping[$0] != nil }) else { continue }
            var progress = GameProgressPreferences.capture(defaults: defaults, profileID: seat.host, profileIDs: Array(localIDs), sessionID: seat.id)
            try progress.merge(captureExtra(seat.host, seat.id))
            var value = CloudLibraryArchive.Seat(id: seat.id, host: host, players: seat.players.compactMap { local.mapping[$0] },
                turn: local.mapping[seat.turn ?? seat.host] ?? host, everyLevel: seat.policy != .atFirstFail,
                progress: progress, stamp: next, savedAt: seat.savedAt ?? Date())
            let branches = local.archive.seats[seat.id] ?? []
            if let previous = branches.first(where: { $0.revision == local.seatRevisions[seat.id] }) ?? branches.first, previous.sameState(as: value) {
                value = previous
            } else if let previous = branches.first(where: { $0.revision == local.seatRevisions[seat.id] }) {
                value.ancestors = previous.ancestors.union([previous.revision])
            }
            local.seatRevisions[seat.id] = value.revision
            // Preserve any unrelated offline branch until it is imported under a
            // stable separate session ID. Never combine its carry-over population.
            local.archive.seats[seat.id] = branches.filter { $0.revision != value.revision && !value.ancestors.contains($0.revision) } + [value]
        }
        local.archive.seats = local.archive.seats.filter { $0.value.allSatisfy { seat in seat.players.allSatisfy { local.archive.players[$0] != nil } } }
        try local.archive.validate(); return local
    }
    public func syncNow() async {
        guard enabled else { setState(.paused); return }
        guard !running else { requested = true; return }
        guard !stateReadFailed else { return }
        running = true; defer { running = false }
        do {
            if identities.isEmpty, let apple = transport as? AppleCloudLibraryTransport { identities = try apple.credentials() }
            identities = try await transport.discover(identities)
            if let apple = transport as? AppleCloudLibraryTransport { try apple.storeCredentials(identities) }
            setState(.syncing)
            let revision = store.progressRevision
            var remote = CloudLibraryArchive()
            var writable: [CloudLibraryIdentity] = []
            for identity in identities {
                do {
                    let versions = try await transport.load(identity)
                    for data in versions { try remote.merge(CloudLibraryArchive.decode(data)) }
                    writable.append(identity)
                } catch {
                    // Corrupt, unknown or unauthorized saves remain untouched.
                    if error is DecodingError || error is SequelDataError { throw error }
                }
            }
            guard !writable.isEmpty else { setState(.offline); return }
            guard enabled, revision == store.progressRevision else { requested = enabled; setState(enabled ? .pending : .paused); return }
            var base = saved
            // A fresh installation adopts the existing primary player. Existing
            // local progress gets its own identity and is never matched by initials.
            if base.mapping.isEmpty, store.records.profiles.count == 1, store.records.runs.isEmpty,
                store.records.statistics.isEmpty, store.records.trolley.starts.isEmpty,
                let first = remote.players.keys.sorted().first {
                let profile = store.records.mainProfileID
                let localProgress = GameProgressPreferences.capture(defaults: defaults, profileID: profile, profileIDs: [profile])
                let extra = try captureExtra(profile, nil)
                if localProgress.values.isEmpty && extra.values.isEmpty {
                    base.mapping[profile] = first
                    // Restore the remote portrait/name before capture to prevent
                    // default placeholder metadata replacing a restored identity.
                    let player = remote.players[first]!
                    base.archive.players[first] = player
                }
            }
            var local = try capture(base)
            // Capture must not stamp a fresh placeholder over remote metadata.
            if saved.mapping.isEmpty, let first = base.mapping[store.records.mainProfileID], let restored = remote.players[first],
                base.archive.players[first] != nil { local.archive.players[first]?.profile = restored.profile; local.archive.players[first]?.stamp = restored.stamp }
            let captured = local
            let incomingRemote = remote
            let merged = try await Task.detached(priority: .utility) {
                var archive = captured.archive; try archive.merge(incomingRemote); return archive
            }.value
            guard enabled, revision == store.progressRevision else { requested = enabled; setState(enabled ? .pending : .paused); return }
            local.archive = merged
            let safe = canImport()
            if safe {
                let changed = try apply(&local)
                try persist(local)
                if changed { onImported?() }
            } else {
                // Retain identity mappings and lineage, but keep unimported remote
                // players out of the deletion detector until a safe-menu pass.
                try persist(captured)
            }
            let payload = try await Task.detached(priority: .utility) { try merged.encoded() }.value
            var uploaded = false
            for identity in writable {
                guard enabled else { setState(.paused); return }
                do { try await transport.save(payload, identity: identity, device: saved.device); uploaded = true }
                catch { /* Retry from local state on activation or the periodic pass. */ }
            }
            guard uploaded else { setState(.offline); return }
            lastSynced = Date()
            let partial = (transport as? AppleCloudLibraryTransport)?.issues.isEmpty == false
            setState(safe && !partial ? .synced : .pending)
        } catch {
            if error is SequelDataError || error is DecodingError { setState(.failed(error.localizedDescription)) }
            else { setState(.offline) }
        }
    }
    private func apply(_ local: inout LocalState) throws -> Bool {
        let previousRecords = store.records
        let beforeDefaults = defaults.dictionaryRepresentation() as NSDictionary
        var incoming: [(ArcadeProfile, ArcadeRecords)] = []
        for (global, player) in local.archive.players.sorted(by: { $0.key < $1.key }) {
            let id = local.mapping.first(where: { $0.value == global })?.key ?? global
            local.mapping[id] = global
            incoming.append((.init(id: id, initials: player.profile.initials, portrait: player.profile.portrait), player.records))
        }
        let deleted = Set(local.mapping.filter { local.archive.deleted.contains($0.value) }.map(\.key))
        _ = try store.mergeLibraryPlayers(incoming, deleted: deleted)
        for (id, global) in local.mapping where local.archive.players[global] != nil {
            try local.archive.players[global]!.progress.apply(defaults: defaults, profileID: id)
        }
        var seats: [ArcadeStore.SavedHotSeat] = []
        for (id, branches) in local.archive.seats {
            let localRevision = local.seatRevisions[id]
            let chosen = branches.first(where: { branch in
                branch.revision == localRevision || localRevision.map { branch.ancestors.contains($0) } == true
            })
                ?? branches.sorted { $0.stamp > $1.stamp }.first!
            for branch in branches {
                let destination = branch.revision == chosen.revision ? id : branch.branchID
                if destination != id, local.archive.seats[destination] != nil { continue }
                let reverse = Dictionary(local.mapping.map { ($0.value, $0.key) }, uniquingKeysWith: { a, _ in a })
                guard let host = reverse[branch.host], let turn = reverse[branch.turn] else { throw SequelDataError.invalid("The shared campaign players are missing.") }
                try branch.progress.apply(defaults: defaults, profileID: host, sessionID: destination)
                seats.append(.init(id: destination, host: host, players: branch.players.compactMap { reverse[$0] }, turn: turn,
                    active: false, savedAt: branch.savedAt, policy: branch.everyLevel ? .everyLevel : .atFirstFail))
                local.seatRevisions[destination] = branch.revision
                if destination != id {
                    var fork = branch; fork.id = destination
                    local.archive.seats[destination] = [fork]
                }
            }
        }
        try store.importLibraryHotSeats(seats); try importSeats(seats)
        return previousRecords != store.records || !(beforeDefaults.isEqual(to: defaults.dictionaryRepresentation()))
    }
    public func makeLink() async throws -> String {
        await syncNow()
        guard enabled, state == .synced || state == .pending, let apple = transport as? AppleCloudLibraryTransport,
            apple.providers.contains("Cloud"), !apple.issues.contains(where: { $0.hasPrefix("Cloud") }) else { throw SequelDataError.invalid("Connect to the internet to link a device.") }
        return try await apple.makeLink(identities)
    }
    public func join(_ code: String) async throws {
        guard canImport(), let apple = transport as? AppleCloudLibraryTransport else { throw SequelDataError.invalid("Return to the library before linking devices.") }
        let linked = try await apple.redeemLink(code)
        var combined = identities.isEmpty ? try apple.credentials() : identities
        for identity in linked where !combined.contains(where: { $0.id == identity.id }) { combined.append(identity) }
        try apple.storeCredentials(combined); identities = combined
        requestSync()
    }
    private func setState(_ value: State) { state = value; onChange?() }
}
