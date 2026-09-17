import Foundation
import CryptoKit
import Darwin
import NxlvKit

struct RunRecovery: Codable, Sendable {
    var version = 1
    let engine: String
    let profileID: String
    var hotSeatID: String? = nil
    var fullQuest: Bool? = nil
    var fanPackGraphics: Bool? = nil
    var fanTextSteel: Bool? = nil
    var fanLocalStyles: Bool? = nil
    var fanHolidayStyles: Bool? = nil
    let runID: UUID
    let dataSetID: String
    let levelIndex: Int
    let levelFingerprint: String
    let initialStateHash: String
    let tick: Int
    let events: [ClassicDOSReplayEvent]
    let stateHash: String
    let usedRewind: Bool
    let nukeCount: Int
    let rewindCount: Int
    let undoCount: Int
    let selectedSkill: Int
    let scrollX: Double
    let scrollY: Double
    var l2: L2RunRecovery? = nil
    var l3: L3RunRecovery? = nil
    var neo: NeoRunRecovery? = nil
    var fan: FanRunRecovery? = nil
    var sourcePath: String? = nil
    var savedAt = Date()

    static let bundledEngine: String = {
        guard let root = Bundle.main.resourceURL else { return "" }
        return (try? String(contentsOf: root.appendingPathComponent("Trolley/engine-fingerprint.txt"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }()
    func validated() throws -> Self {
        guard version == 1 else { throw RunRecoveryError.version }
        guard (0...120_000).contains(tick), (0..<10_000).contains(levelIndex),
              events.count <= 100_000, !dataSetID.isEmpty, !engine.isEmpty,
              !profileID.isEmpty, !initialStateHash.isEmpty, !levelFingerprint.isEmpty, !stateHash.isEmpty,
              [nukeCount, rewindCount, undoCount].allSatisfy({ (0...1_000_000).contains($0) }),
              scrollX.isFinite, scrollY.isFinite, (0..<(neo == nil ? 8 : NeoLemmixSkill.allCases.count)).contains(selectedSkill),
              events.allSatisfy({ $0.afterTick == true && (0...120_000).contains($0.tick) }),
              zip(events, events.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw RunRecoveryError.invalid
        }
        if let fan {
            guard l2 == nil, l3 == nil, neo == nil, dataSetID == "fan-classic",
                sourcePath?.hasPrefix("/") == true, levelIndex == fan.index else { throw RunRecoveryError.invalid }
            try fan.validate()
        }
        if let l2 {
            guard neo == nil, l3 == nil, events.isEmpty, sourcePath?.hasPrefix("/") == true,
                dataSetID == "lemmings2" else { throw RunRecoveryError.invalid }
            try l2.validate(tick: tick)
        }
        if let l3 {
            guard neo == nil, events.isEmpty, sourcePath?.hasPrefix("/") == true,
              dataSetID == "lemmings3", selectedSkill < 5 else { throw RunRecoveryError.invalid }
            try l3.validate(tick: tick)
        }
        if let neo {
            guard events.isEmpty, sourcePath?.hasPrefix("/") == true,
                  neo.state.tickCount == tick else { throw RunRecoveryError.invalid }
            try neo.validate()
        }
        return self
    }
}

struct FanRunRecovery: Codable, Sendable {
    struct Entry: Codable, Sendable {
        let file: String
        let section: Int?
        let label: String
    }
    let queue: [Entry]
    let index: Int
    var baseDataSetID: String? = nil
    func validate() throws {
        guard queue.count <= 10_000, queue.indices.contains(index),
            baseDataSetID.map({ !$0.isEmpty && $0.utf8.count <= 4096 }) ?? true,
            queue.allSatisfy({ !$0.file.isEmpty && $0.file.utf8.count <= 4096
                && !$0.file.hasPrefix("/") && !$0.file.split(separator: "/").contains("..")
                && ($0.section.map { (0..<10_000).contains($0) } ?? true)
                && $0.label.utf8.count <= 4096 }) else { throw RunRecoveryError.invalid }
    }
}

enum RunRecoveryError: Error, LocalizedError {
    case version, invalid, changed, busy, differentGame
    var errorDescription: String? {
        switch self {
        case .version: return "This saved run needs a different app version. Its files were preserved."
        case .invalid: return "The saved run could not be verified. Its files were preserved."
        case .changed: return "The saved run changed in another app. Reopen the game before saving again."
        case .busy: return "Another app is saving this run. Try again."
        case .differentGame: return "The saved run uses different game data or rules. Its files were preserved."
        }
    }
}

/// Atomic checkpoints have a validated backup and never overwrite an unseen writer.
final class RunRecoveryFile {
    private struct Document: Codable {
        var version = 1
        let payload: Data?
        let checksum: String
    }
    let url: URL
    var backupURL: URL { url.appendingPathExtension("backup") }
    private var expected: Data?
    private(set) var recoveredBackup = false
    init(url: URL) { self.url = url }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func decode(_ data: Data) throws -> RunRecovery? {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.version == 1 else { throw RunRecoveryError.version }
        guard document.checksum == hash(document.payload ?? Data()) else { throw RunRecoveryError.invalid }
        return try document.payload.map { try JSONDecoder().decode(RunRecovery.self, from: $0).validated() }
    }
    private func read(_ path: URL) throws -> Data {
        var freshPath = path
        freshPath.removeAllCachedResourceValues()
        let size = try freshPath.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 64 * 1024 * 1024 else { throw RunRecoveryError.invalid }
        let bytes = try Data(contentsOf: path, options: .mappedIfSafe)
        guard bytes.count <= 64 * 1024 * 1024 else { throw RunRecoveryError.invalid }
        return bytes
    }
    private func current() throws -> Data? {
        FileManager.default.fileExists(atPath: url.path) ? try read(url) : nil
    }
    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw RunRecoveryError.busy }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
    func load() throws -> RunRecovery? {
        try locked {
            recoveredBackup = false
            do {
                if let data = try current() {
                    let value = try decode(data)
                    expected = data
                    return value
                }
            } catch RunRecoveryError.version {
                throw RunRecoveryError.version
            } catch {
                guard FileManager.default.fileExists(atPath: backupURL.path) else { throw error }
            }
            guard FileManager.default.fileExists(atPath: backupURL.path) else { expected = nil; return nil }
            let backup = try read(backupURL)
            let value = try decode(backup)
            if FileManager.default.fileExists(atPath: url.path) {
                // Preserve oversized files without loading their contents into memory.
                try FileManager.default.copyItem(at: url,
                    to: url.appendingPathExtension("unreadable-\(UUID().uuidString)"))
            }
            try backup.write(to: url, options: .atomic)
            expected = backup; recoveredBackup = true
            return value
        }
    }
    func save(_ recovery: RunRecovery?) throws {
        try locked {
            let existing = try current()
            guard existing == expected else { throw RunRecoveryError.changed }
            let payload = try recovery.map { try JSONEncoder().encode($0.validated()) }
            let bytes = try JSONEncoder().encode(Document(payload: payload, checksum: hash(payload ?? Data())))
            guard bytes.count <= 64 * 1024 * 1024 else { throw RunRecoveryError.invalid }
            // Clear both copies so a completed run cannot return through backup recovery.
            try (recovery == nil ? bytes : existing ?? bytes).write(to: backupURL, options: .atomic)
            try bytes.write(to: url, options: .atomic)
            expected = bytes
        }
    }
}

/// One serial writer keeps disk work off the game clock. Forced saves drain it on exit.
final class RunRecoveryStore: @unchecked Sendable {
    private static let integrationDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("RunRecovery-\(UUID().uuidString)")
    let directory: URL
    private let queue = DispatchQueue(label: "academy.glasscode.lemmings.checkpoints", qos: .utility)
    private var files: [UUID: RunRecoveryFile] = [:]
    init(directory: URL? = nil) {
        if let directory { self.directory = directory }
        else if Bundle.main.bundleIdentifier?.contains("integration-tests") == true {
            self.directory = Self.integrationDirectory
        } else {
            self.directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Ultimate Lemmings/Checkpoints")
        }
    }
    private func file(_ id: UUID) throws -> RunRecoveryFile {
        if let file = files[id] { return file }
        let file = RunRecoveryFile(url: directory.appendingPathComponent(id.uuidString + ".json"))
        _ = try file.load(); files[id] = file
        return file
    }
    func save(_ recovery: RunRecovery, immediately: Bool = false,
              onError: @escaping @MainActor @Sendable (String) -> Void) {
        let operation: @Sendable () -> Void = { [self] in
            do { try file(recovery.runID).save(recovery) }
            catch { let message = error.localizedDescription; Task { @MainActor in onError(message) } }
        }
        if immediately { queue.sync(execute: operation) } else { queue.async(execute: operation) }
    }
    func clear(_ id: UUID) throws { try queue.sync { try file(id).save(nil) } }
    /// Unrestorable runs leave Resume. Their bytes move to "Set aside" instead of being deleted.
    var setAsideDirectory: URL { directory.appendingPathComponent("Set aside") }
    func setAside(_ id: UUID) throws { try queue.sync { try moveAside(id) } }
    /// Sets aside every run that cannot be read. Returns how many were moved.
    @discardableResult func setAsideUnreadable() throws -> Int {
        try queue.sync {
            var moved = 0
            for id in try runIDs() {
                do { _ = try file(id).load() }
                catch RunRecoveryError.busy { continue }
                catch { try moveAside(id); moved += 1 }
            }
            return moved
        }
    }
    /// Deletes the readable runs of a removed player. Runs that cannot be read stay untouched.
    func discard(profileID: String) throws {
        try queue.sync {
            for id in try runIDs() {
                guard let value = try? file(id).load(), value.profileID == profileID else { continue }
                files[id] = nil
                for suffix in [".json", ".json.backup", ".json.lock"] {
                    try? FileManager.default.removeItem(at: directory.appendingPathComponent(id.uuidString + suffix))
                }
            }
        }
    }
    private func runIDs() throws -> Set<UUID> {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        // Include missing-primary backups after an interrupted file operation.
        return Set(urls.compactMap { URL -> UUID? in
            let stem = URL.deletingPathExtension()
            return UUID(uuidString: URL.pathExtension == "backup" ? stem.deletingPathExtension().lastPathComponent : stem.lastPathComponent)
        })
    }
    private func moveAside(_ id: UUID) throws {
        files[id] = nil
        let manager = FileManager.default
        try manager.createDirectory(at: setAsideDirectory, withIntermediateDirectories: true)
        let stamp = UUID().uuidString
        for suffix in [".json", ".json.backup"] {
            let source = directory.appendingPathComponent(id.uuidString + suffix)
            guard manager.fileExists(atPath: source.path) else { continue }
            try manager.moveItem(at: source, to: setAsideDirectory.appendingPathComponent("\(id.uuidString)-\(stamp)\(suffix)"))
        }
        try? manager.removeItem(at: directory.appendingPathComponent(id.uuidString + ".json.lock"))
    }
    func latest(profileID: String, hotSeatID: String? = nil) throws -> RunRecovery? {
        try queue.sync {
            let ids = try runIDs()
            var latest: RunRecovery?
            var firstError: Error?
            for id in ids {
                do {
                    let item = try file(id)
                    guard let value = try item.load(), value.profileID == profileID, value.hotSeatID == hotSeatID else { continue }
                    if latest == nil || value.savedAt > latest!.savedAt { latest = value }
                } catch { if firstError == nil { firstError = error } }
            }
            if latest == nil, let firstError { throw firstError }
            return latest
        }
    }
}

struct NeoRunRecovery: Codable, Sendable {
    struct Input: Codable, Sendable {
        enum Action: Codable, Sendable {
            case assign(skill: Int, lemming: Int)
            case rate(delta: Int)
            case nuke
        }
        let tick: Int
        let action: Action
    }
    let initialState: NeoLemmixSimulation
    let state: NeoLemmixSimulation
    let inputs: [Input]
    func validate() throws {
        guard initialState.tickCount == 0, (0...120_000).contains(state.tickCount),
              inputs.count <= 100_000,
              inputs.allSatisfy({ (0...state.tickCount).contains($0.tick) }),
              zip(inputs, inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw RunRecoveryError.invalid
        }
    }
}

struct L3RunRecovery: Codable, Sendable {
    struct Input: Codable, Sendable {
        let tick: Int
        let action: String
        let lemming: Int?
        let direction: String?
    }
    let progress: Lemmings3ClassicCampaign.Progress
    let inputs: [Input]
    let skillAssignments: [String: Int]
    let toolUses: [String: Int]
    func validate(tick: Int) throws {
        guard progress.version == 1, progress.tribe != nil, (0..<30).contains(progress.index),
              inputs.count <= 100_000, inputs.allSatisfy({ (0...tick).contains($0.tick) }),
              zip(inputs, inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }),
              skillAssignments.values.allSatisfy({ (0...100_000).contains($0) }),
              toolUses.values.allSatisfy({ (0...100_000).contains($0) }) else { throw RunRecoveryError.invalid }
    }
    func restore(initial: Lemmings3Runtime, checkpoint: RunRecovery) throws -> Lemmings3Runtime {
        _ = try checkpoint.validated()
        guard Self.stateHash(initial) == checkpoint.initialStateHash else { throw RunRecoveryError.differentGame }
        var game = initial
        for input in inputs {
            while game.tick < input.tick && !game.isComplete { game.step() }
            guard Self.apply(input, to: &game) else { throw RunRecoveryError.invalid }
        }
        while game.tick < checkpoint.tick && !game.isComplete { game.step() }
        guard game.tick == checkpoint.tick, !game.isComplete,
              Self.stateHash(game) == checkpoint.stateHash else { throw RunRecoveryError.invalid }
        return game
    }
    static func stateHash(_ game: Lemmings3Runtime) -> String {
        var hash = SHA256()
        func number(_ value: Int) {
            var value = Int64(value).littleEndian
            withUnsafeBytes(of: &value) { hash.update(data: Data($0)) }
        }
        func text(_ value: String) { let data = Data(value.utf8); number(data.count); hash.update(data: data) }
        let c = game.configuration
        for value in [c.width, c.height, c.total, c.releaseInterval, c.releaseDelay, c.timeLimit,
                      c.sourceLevelReference ?? -1, game.tick, game.released, game.saved, game.lost,
                      game.reserve, game.bonusSeconds, game.isComplete ? 1 : 0] { number(value) }
        for point in [c.entrance] + c.additionalEntrances + c.exits { number(point.x); number(point.y) }
        for grid in [game.attributes, c.backgroundAttributes] {
            number(grid.count)
            var bytes = Data(capacity: grid.count * 2)
            for value in grid { bytes.append(UInt8(truncatingIfNeeded: value)); bytes.append(UInt8(value >> 8)) }
            hash.update(data: bytes)
        }
        number(game.lemmings.count)
        for lem in game.lemmings {
            text(lem.state.rawValue); text(lem.workDirection.rawValue)
            for value in [lem.id, lem.x, lem.y, lem.direction, lem.age, lem.fall, lem.velocityY,
                          lem.tool?.rawValue ?? -1, lem.quantity, lem.swimTicks, lem.trapTicks,
                          lem.mobilityTool?.rawValue ?? -1, lem.mobilityTicks, lem.charmedBy ?? -1,
                          lem.charmTicks, lem.charmImmunity] { number(value) }
        }
        number(game.pickups.count)
        for box in game.pickups {
            for value in [box.id, box.tool.rawValue, box.x, box.y, box.quantity, box.ignoredBy ?? -1] { number(value) }
        }
        number(game.explosives.count)
        for bomb in game.explosives {
            for value in [bomb.id, bomb.tool.rawValue, bomb.x, bomb.y, bomb.velocityX, bomb.velocityY, bomb.age] { number(value) }
        }
        number(game.fireballs.count)
        for ball in game.fireballs { for value in [ball.x, ball.y, ball.direction, ball.age] { number(value) } }
        number(game.creatures.count)
        for creature in game.creatures {
            text(creature.digDirection.rawValue)
            for value in [creature.id, creature.kind.rawValue, creature.x, creature.y, creature.direction,
                          creature.alive ? 1 : 0, creature.target ?? -1, creature.cooldown, creature.age] { number(value) }
        }
        for trap in c.traps.sorted(by: { $0.id < $1.id }) { number(trap.id); number(game.trapFrame(id: trap.id)) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    @discardableResult static func apply(_ input: Input, to game: inout Lemmings3Runtime) -> Bool {
        guard input.tick == game.tick, !game.isComplete else { return false }
        if input.action == "abort" {
            guard input.lemming == nil, input.direction == nil else { return false }
            game.abort(); return true
        }
        guard let id = input.lemming else { return false }
        if input.action == "use" {
            guard let raw = input.direction, let direction = Lemmings3Runtime.Direction(rawValue: raw) else { return false }
            return game.useTool(to: id, direction: direction)
        }
        guard input.direction == nil, let action = Lemmings3Runtime.Action(rawValue: input.action) else { return false }
        return game.assign(action, to: id)
    }
}

/// Canonical value encoding for the native L2 runtime, including private state.
/// Checkpoints remain tied to the exact engine fingerprint and validated assets.
private enum RecoveryValueEncoding {
    static func data(_ value: Any) throws -> Data {
        if let data = value as? Data { return data }
        if let bytes = value as? [UInt8] { return Data(bytes) }
        if let bits = value as? [Bool] { return Data(bits.map { $0 ? 1 : 0 }) }
        if let text = value as? String { return Data(text.utf8) }
        if let number = value as? Int { var n = Int64(number).littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        if let number = value as? UInt64 { var n = number.littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        if let number = value as? UInt32 { var n = number.littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        if let number = value as? UInt16 { var n = number.littleEndian; return withUnsafeBytes(of: &n) { Data($0) } }
        if let number = value as? UInt8 { return Data([number]) }
        if let number = value as? Double { return try data(number.bitPattern) }
        if let number = value as? Float { return try data(number.bitPattern) }
        if let flag = value as? Bool { return Data([flag ? 1 : 0]) }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle != .class else { throw RunRecoveryError.invalid }
        var parts = try mirror.children.map { child -> Data in
            var bytes = Data((child.label ?? "").utf8)
            bytes.append(0); bytes.append(try data(child.value)); return bytes
        }
        if mirror.displayStyle == .dictionary || mirror.displayStyle == .set {
            // Collection position labels are not part of set or dictionary identity.
            parts = try mirror.children.map { try data($0.value) }.sorted { $0.lexicographicallyPrecedes($1) }
        }
        var result = Data(String(reflecting: type(of: value)).utf8); result.append(0)
        if parts.isEmpty { result.append(Data(String(describing: value).utf8)) }
        for part in parts {
            var size = UInt64(part.count).littleEndian
            withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }
            result.append(part)
        }
        return result
    }
}

struct L2RunRecovery: Codable, Sendable {
    struct Practice: Codable, Sendable {
        let choice: Int
        let skills: [Int]
        func validate() throws {
            guard Lemmings2Practice.tribes.indices.contains(choice), skills.count == 8,
                Set(skills).count == 8,
                skills.allSatisfy({ Lemmings2Runtime.Skill(rawValue: $0).map { $0 != .unused } == true })
                else { throw RunRecoveryError.invalid }
        }
    }
    struct Input: Codable, Sendable {
        enum Action: Codable, Equatable, Sendable {
            case assign(slot: Int, lemming: Int)
            case fan(x: Int, y: Int, active: Bool)
            case aim(x: Int, y: Int, held: Bool)
            case releasePointer
            case machine(x: Int, y: Int)
            case chain(x: Int, y: Int)
            case nuke
        }
        let tick: Int
        let action: Action
    }
    let progress: Lemmings2Campaign.Progress
    let inputs: [Input]
    var practice: Practice? = nil
    static func stateHash(_ game: Lemmings2Runtime, includeConfiguration: Bool = false) throws -> String {
        var digest = SHA256()
        for child in Mirror(reflecting: game).children {
            guard child.label != "soundEvents", includeConfiguration || child.label != "configuration" else { continue }
            digest.update(data: Data((child.label ?? "").utf8))
            digest.update(data: try RecoveryValueEncoding.data(child.value))
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func validate(tick: Int) throws {
        try practice?.validate()
        guard progress.version == 1, (0..<12).contains(progress.tribe), (0..<10).contains(progress.level),
            inputs.count <= 100_000, inputs.allSatisfy({ (0...tick).contains($0.tick) }),
            zip(inputs, inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else { throw RunRecoveryError.invalid }
    }
    private static func absSafe(_ coordinate: Int) -> Bool { (-1_000_000...1_000_000).contains(coordinate) }
    static func apply(_ input: Input, to game: inout Lemmings2Runtime) throws {
        guard game.tick == input.tick, !game.isComplete else { throw RunRecoveryError.invalid }
        switch input.action {
        case let .assign(slot, id): guard game.assign(slot: slot, to: id) else { throw RunRecoveryError.invalid }
        case let .fan(x, y, active):
            guard absSafe(x), absSafe(y) else { throw RunRecoveryError.invalid }
            game.setFan(x: x, y: y, active: active)
        case let .aim(x, y, held):
            guard absSafe(x), absSafe(y) else { throw RunRecoveryError.invalid }
            game.setAim(x: x, y: y, held: held)
        case .releasePointer: game.releasePointerInput()
        case let .machine(x, y): guard absSafe(x), absSafe(y), game.moveMachine(x: x, y: y) else { throw RunRecoveryError.invalid }
        case let .chain(x, y): guard absSafe(x), absSafe(y), game.releaseChain(x: x, y: y) else { throw RunRecoveryError.invalid }
        case .nuke: guard !game.isNuking else { throw RunRecoveryError.invalid }; game.nuke()
        }
    }
    func restore(initial: Lemmings2Runtime, checkpoint: RunRecovery) throws -> (Lemmings2Runtime, Lemmings2Runtime?, Int) {
        _ = try checkpoint.validated()
        guard try Self.stateHash(initial, includeConfiguration: true) == checkpoint.initialStateHash else { throw RunRecoveryError.differentGame }
        var game = initial, beforeNuke: Lemmings2Runtime?, beforeNukeCount = 0
        for (index, input) in inputs.enumerated() {
            while game.tick < input.tick && !game.isComplete { game.step(); _ = game.drainSoundEvents() }
            if case .nuke = input.action { beforeNuke = game; beforeNukeCount = index }
            try Self.apply(input, to: &game)
            _ = game.drainSoundEvents()
        }
        while game.tick < checkpoint.tick && !game.isComplete { game.step(); _ = game.drainSoundEvents() }
        guard game.tick == checkpoint.tick, !game.isComplete,
            try Self.stateHash(game) == checkpoint.stateHash else { throw RunRecoveryError.invalid }
        _ = game.drainSoundEvents()
        return (game, beforeNuke, beforeNukeCount)
    }
}
