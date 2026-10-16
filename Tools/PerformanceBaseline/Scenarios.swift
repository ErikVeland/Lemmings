import CryptoKit
import Darwin
import Foundation
import NxlvKit
import os.signpost

private let tickLog = OSLog(subsystem: "local.lemmings.performance", category: .pointsOfInterest)

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}

@_silgen_name("benchmark_allocations_begin") func allocationsBegin() -> Int32
@_silgen_name("benchmark_allocations_end") func allocationsEnd() -> UInt64
@_silgen_name("benchmark_allocations_selftest") func allocationsSelftest() -> UInt64

struct BaselineCase: Codable {
    let id: String
    let engine: String
    let purpose: String
    let level: String
    let replay: String?
    let initialHash: String?
}

struct TickSample: Codable {
    let ticks: Int
    let wallSeconds: Double
    let cpuSeconds: Double
    let allocations: UInt64?
    let stateHash: String
    let saved: Int
    let width: Int
    let height: Int
    let population: Int
    var recordedOutcomeMatches = true
    var batchRuns = 1
}

func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func canonical<T: Encodable>(_ value: T) throws -> String {
    // Codable preserves array order, but Set and enum-keyed Dictionary order
    // is process-specific. Normalise only the known unordered fields.
    func normalise(_ value: Any, key: String = "") -> Any {
        if let object = value as? [String: Any] {
            return object.mapValues { $0 }.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = normalise(pair.value, key: pair.key)
            }
        }
        guard let array = value as? [Any] else { return value }
        if ["traits", "disabledZoneIDs", "gadgetAnimatingZoneIDs"].contains(key) {
            return array.sorted { String(describing: $0) < String(describing: $1) }
        }
        if key == "skills", array.count.isMultiple(of: 2) {
            var object: [String: Any] = [:]
            for index in stride(from: 0, to: array.count, by: 2) {
                object[String(describing: array[index])] = normalise(array[index + 1])
            }
            return object
        }
        return array.map { normalise($0) }
    }
    let encoded = try JSONEncoder().encode(value)
    let normalised = normalise(try JSONSerialization.jsonObject(with: encoded))
    return digest(try JSONSerialization.data(withJSONObject: normalised, options: [.sortedKeys]))
}
func cpuTime() -> Double {
    var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
        + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}

struct TickTimer {
    let cpu: Double
    let wall: UInt64
    let counts: Bool
    init(countAllocations: Bool) {
        if !countAllocations { os_signpost(.begin, log: tickLog, name: "SimulationTicks") }
        cpu = cpuTime()
        counts = countAllocations && allocationsBegin() != 0
        wall = DispatchTime.now().uptimeNanoseconds
    }
    func stop() -> (Double, Double, UInt64?) {
        let seconds = Double(DispatchTime.now().uptimeNanoseconds - wall) / 1_000_000_000
        let count = counts ? allocationsEnd() : nil
        if !counts { os_signpost(.end, log: tickLog, name: "SimulationTicks") }
        return (seconds, cpuTime() - cpu, count)
    }
}

struct ClassicInput {
    let level: ClassicLevel
    let rendered: ClassicRenderedLevel
    let base: ClassicDOSSimulation
    let replay: ClassicDOSReplay
    let before: [Int: [ClassicDOSReplayAction]]
    let after: [Int: [ClassicDOSReplayAction]]

    init(_ item: BaselineCase, assets: URL) throws {
        let resources = assets.appendingPathComponent("resources")
        let parts = item.level.split(separator: "/", maxSplits: 1).map(String.init)
        let pack = resources.appendingPathComponent("LevelPacks/" + parts[0])
        let member = parts[1].split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard let entry = FanLevelLibrary.entries(in: pack).first(where: {
            $0.file == member[0] && ($0.section ?? 0) == Int(member[1])
        }) else { throw Failure("Fan entry missing: \(item.level)") }
        let loaded = try FanLevelLibrary.level(entry, in: pack)
        level = loaded.0
        let ports = resources.appendingPathComponent("Ports")
        let ground = try FanLevelLibrary.groundSet(for: level, styleName: loaded.1,
            portsRoot: ports, pack: pack, entry: entry)
        let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry, pack: pack, portsRoot: ports)
        rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
            specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
        base = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mainDATAssets: ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30")),
            mechanics: FanLevelLibrary.mechanics(for: pack, entry: entry), clock: .golems)
        replay = try JSONDecoder().decode(ClassicDOSReplay.self,
            from: Data(contentsOf: assets.appendingPathComponent(item.replay!)))
        guard ClassicDOSReplayRecorder.stateHash(of: base) == replay.initialStateHash else {
            throw Failure("Classic initial identity differs: \(item.id)")
        }
        before = Dictionary(grouping: replay.events.filter { $0.afterTick != true }, by: \.tick).mapValues { $0.map(\.action) }
        after = Dictionary(grouping: replay.events.filter { $0.afterTick == true }, by: \.tick).mapValues { $0.map(\.action) }
    }

    func run(countAllocations: Bool) throws -> TickSample {
        var game = base
        for event in replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                guard game.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)) else { throw Failure("Scheduled assignment refused") }
            }
        }
        func apply(_ actions: [ClassicDOSReplayAction], live: Bool) throws {
            for action in actions {
                switch action {
                case let .assign(id, skill):
                    if live {
                        let result = replay.sourceRules == .golemsFallingBuilder
                            ? game.assignGolemsReplay(skill, to: id) : game.assign(skill, to: id)
                        guard result == .assigned else { throw Failure("Live assignment refused") }
                    }
                case let .releaseRate(rate): game.setReleaseRate(rate)
                case .nuke: game.beginNuke()
                }
            }
        }
        try apply(after[0] ?? [], live: true)
        let timer = TickTimer(countAllocations: countAllocations)
        while !game.isComplete && game.tickCount < 30_000 {
            try apply(before[game.tickCount + 1] ?? [], live: false)
            _ = game.tick()
            try apply(after[game.tickCount] ?? [], live: true)
        }
        let (wall, cpu, count) = timer.stop()
        let hash = ClassicDOSReplayRecorder.stateHash(of: game)
        guard game.isComplete else { throw Failure("Classic tick limit") }
        if let expected = replay.expected {
            guard hash == expected.stateHash, game.tickCount == expected.ticks, game.savedCount == expected.saved else { throw Failure("Classic recorded outcome differs") }
        }
        return .init(ticks: game.tickCount, wallSeconds: wall, cpuSeconds: cpu, allocations: count,
            stateHash: hash, saved: game.savedCount, width: rendered.width, height: rendered.height,
            population: base.configuration.totalLemmings)
    }
}

struct NeoInput {
    let text: String
    let level: NxlvLevel
    let rendered: NxlvRenderedLevel
    let base: NeoLemmixSimulation
    init(_ item: BaselineCase, assets: URL) throws {
        text = try String(contentsOf: assets.appendingPathComponent("neo/levels/" + item.level), encoding: .utf8)
        guard let decoded = NxlvLevel(text: text) else { throw Failure("NeoLemmix decode failed") }
        level = decoded
        let resolution = NxlvStyleResolver(stylesRootURL: assets.appendingPathComponent("neo/styles")).resolve(level: level)
        let result = NxlvRenderer().render(level: level, resolution: resolution)
        guard resolution.isComplete, !result.hasErrors, let frame = result.renderedLevel else { throw Failure("NeoLemmix render failed: \(item.level)") }
        rendered = frame
        base = try NeoLemmixSimulation(level: level, renderedLevel: frame)
    }
    func run(countAllocations: Bool, stress: Bool = false) throws -> TickSample {
        var game = base
        if stress {
            game.enqueue(.setSpawnInterval(4), atTick: 1)
            game.enqueue(.nuke, atTick: 1024)
        }
        let timer = TickTimer(countAllocations: countAllocations)
        while game.tickCount < 4096 && !game.isComplete { game.tick() }
        let (wall, cpu, count) = timer.stop()
        return .init(ticks: game.tickCount, wallSeconds: wall, cpuSeconds: cpu, allocations: count,
            stateHash: try canonical(game), saved: game.savedCount, width: game.terrain.width,
            height: game.terrain.height, population: game.configuration.totalLemmings)
    }
}

struct L2Input {
    let base: Lemmings2Runtime
    let witness: Lemmings2ReplayWitness
    let events: [Lemmings2TimedEvent]
    init(_ item: BaselineCase, source: URL, assets: URL) throws {
        let decoded = try JSONDecoder().decode(Lemmings2ReplayWitness.self,
            from: Data(contentsOf: source.appendingPathComponent(item.replay!)))
        witness = decoded
        let root = assets.appendingPathComponent("resources/Ports/Lemm2")
        let campaign = try Lemmings2Campaign(root: root)
        guard let level = campaign.levels.first(where: { $0.fingerprint == decoded.levelSHA256 }) else { throw Failure("Unknown L2 fixture") }
        let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
        base = try Lemmings2Runtime(level: level, style: style, masks: Lemmings2TerrainMasks(root: root), total: witness.population)
        events = witness.timedEvents()
    }
    func run(countAllocations: Bool) throws -> TickSample {
        var game = base; var cursor = Lemmings2EventCursor()
        let timer = TickTimer(countAllocations: countAllocations)
        while !game.isComplete && game.tick < 30_000 {
            try cursor.apply(eventsAt: &game, events: events)
            game.step()
        }
        let (wall, cpu, count) = timer.stop()
        guard game.isComplete, cursor.next == events.count, game.saved == witness.expectedSaved,
              game.tick == witness.expectedTicks else { throw Failure("L2 outcome differs") }
        return .init(ticks: game.tick, wallSeconds: wall, cpuSeconds: cpu, allocations: count,
            stateHash: game.stateFingerprint, saved: game.saved, width: game.configuration.width,
            height: game.configuration.height, population: game.configuration.total)
    }
}

struct L3Input {
    let base: Lemmings3Runtime
    let witness: L3Replay
    init(_ item: BaselineCase, source: URL, assets: URL) throws {
        witness = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: source.appendingPathComponent(item.replay!)))
        let root = assets.appendingPathComponent("resources/Ports/LEM3CD")
        let level = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", witness.level))))
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: level.style)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        base = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary, total: witness.population)
        guard L3Replay.stateHash(base) == witness.initialStateHash, L3Replay.digest(level.rawData) == witness.levelSHA256 else { throw Failure("L3 initial identity differs") }
    }
    func run(countAllocations: Bool) throws -> TickSample {
        var game = base; var cursor = 0
        let timer = TickTimer(countAllocations: countAllocations)
        while !game.isComplete && game.tick < 30_000 {
            while cursor < witness.inputs.count && witness.inputs[cursor].tick == game.tick {
                guard L3Replay.apply(witness.inputs[cursor], to: &game) else { throw Failure("L3 input refused") }
                cursor += 1
            }
            game.step()
        }
        let (wall, cpu, count) = timer.stop()
        let outcome = L3Replay.Outcome(game)
        guard game.isComplete, cursor == witness.inputs.count else { throw Failure("L3 route did not consume its inputs") }
        var result = TickSample(ticks: game.tick, wallSeconds: wall, cpuSeconds: cpu, allocations: count,
            stateHash: outcome.stateHash, saved: game.saved, width: game.configuration.width,
            height: game.configuration.height, population: game.configuration.total)
        result.recordedOutcomeMatches = outcome == witness.expected
        return result
    }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
