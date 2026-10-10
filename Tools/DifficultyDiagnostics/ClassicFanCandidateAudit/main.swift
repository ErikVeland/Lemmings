import CryptoKit
import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}

struct EvidenceRow: Codable {
    let entry: LevelPlaylistEntry
    var profile: DifficultyProfile
    let official: Bool
    let order: Int
    let playable: Bool
    let initialHash: String?
    let issue: String?
}

struct SourceRecord: Decodable {
    let hash: String
    let identity: LevelCatalogueIdentity
    let sourceReplaySHA256: String?
    let sourceSaved: Int?
    let sourceTicks: Int?
}

struct CandidateCheck: Codable {
    let entry: LevelPlaylistEntry
    let sourceReplaySHA256: String?
    let sourceSaved: Int?
    let sourceTicks: Int?
    let clock: ClassicDOSClock
    let initialHash: String
    let saved: Int?
    let required: Int?
    let ticks: Int?
    let row: EvidenceRow?
    let replay: ClassicDOSReplay?
    let error: String?
}

guard CommandLine.arguments.count == 5 else {
    fatalError("Usage: ClassicFanCandidateAudit PROJECT_ROOT BUNDLED_RESOURCES INPUT_DIRECTORY OUTPUT")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = URL(fileURLWithPath: CommandLine.arguments[2])
let input = URL(fileURLWithPath: CommandLine.arguments[3])
let output = URL(fileURLWithPath: CommandLine.arguments[4])
let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let rows = try decoder.decode([EvidenceRow].self, from: Data(contentsOf: input.appendingPathComponent("input.json")))
let records = try decoder.decode([SourceRecord].self, from: Data(contentsOf: input.appendingPathComponent("fetch-results.json")))
let byIdentity = Dictionary(uniqueKeysWithValues: records.map { ($0.identity, $0) })
precondition(rows.count == records.count && byIdentity.count == records.count)
let baseline = try decoder.decode([EvidenceRow].self, from: Data(contentsOf:
    root.appendingPathComponent(".build/full-difficulty-evaluation/clock-rescore/baseline/audit.json")))
let sourceRows = Dictionary(uniqueKeysWithValues: baseline.map { ($0.entry.identity, $0) })
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
let ports = resources.appendingPathComponent("Ports")
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
var packEntries: [String: [FanLevelLibrary.Entry]] = [:]
var checks: [CandidateCheck] = []
for row in rows {
    let id = row.entry.identity
    guard !row.official, row.profile.confidence == .low,
          let source = byIdentity[id], source.hash == row.initialHash,
          let pack = packs[id.packID], FanLevelLibrary.archiveFingerprint(pack) == row.entry.sourceRevision,
          let sourceRow = sourceRows[id], sourceRow.entry == row.entry,
          let separator = id.levelID.lastIndex(of: "#"),
          let section = Int(id.levelID[id.levelID.index(after: separator)...]) else {
        fatalError("Candidate source identity or archive changed: \(id.packID)/\(id.levelID)")
    }
    let file = String(id.levelID[..<separator])
    let entries: [FanLevelLibrary.Entry]
    if let cached = packEntries[id.packID] { entries = cached }
    else {
        entries = try FanLevelLibrary.validatedEntries(in: pack)
        packEntries[id.packID] = entries
    }
    guard let item = entries.first(where: { $0.file == file && ($0.section ?? -1) == section }) else {
        fatalError("Candidate level is absent from its archive: \(id.packID)/\(id.levelID)")
    }
    let replayURL = input.appendingPathComponent("replays").appendingPathComponent(source.hash + ".json")
    let sourceReplay = try decoder.decode(ClassicDOSReplay.self, from: Data(contentsOf: replayURL))
    guard sourceReplay.initialStateHash == source.hash else { fatalError("Source replay hash changed") }
    let (level, style) = try FanLevelLibrary.level(item, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
    let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
        objectSemantics: .forFanLevel(level, groundSet: ground))
    for clock in [ClassicDOSClock.dos, .golems] {
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mainDATAssets: assets, clock: clock)
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        guard hash == (clock == .dos ? row.initialHash : sourceRow.initialHash) else {
            fatalError("Candidate initial state changed: \(id.packID)/\(id.levelID)")
        }
        let candidate = ClassicDOSReplay(rank: id.packID, number: row.entry.levelNumberSnapshot,
            title: row.entry.levelNameSnapshot, initialStateHash: hash, events: sourceReplay.events)
        do {
            let tickLimit = max(20_000, initial.configuration.timeLimitTicks ?? 0)
            let outcome = try ClassicDOSReplayPlayer.run(candidate, simulation: initial, tickLimit: tickLimit)
            var scored: EvidenceRow?
            var witness: ClassicDOSReplay?
            if outcome.didWin {
                let replay = ClassicDOSReplay(rank: candidate.rank, number: candidate.number,
                    title: candidate.title, initialStateHash: hash, events: candidate.events, expected: outcome)
                _ = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: tickLimit)
                let digest = SHA256.hash(data: try encoder.encode(replay)).description
                let revision = clock == .golems
                    ? DifficultyModel.simulationVersion + ":golems-clock-2-limit-from-clock-1"
                    : DifficultyModel.simulationVersion
                let key = DifficultyCacheKey(identity: id, levelRevision: row.entry.sourceRevision,
                    replayRevision: digest, assetsRevision: hash + ":probes-10", simulationVersion: revision)
                let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: replay,
                    key: key, maximumProbeRuns: 10)
                scored = EvidenceRow(entry: row.entry, profile: profile, official: false,
                    order: row.order, playable: true, initialHash: hash, issue: nil)
                witness = replay
            }
            checks.append(CandidateCheck(entry: row.entry, sourceReplaySHA256: source.sourceReplaySHA256,
                sourceSaved: source.sourceSaved, sourceTicks: source.sourceTicks,
                clock: clock, initialHash: hash, saved: outcome.saved, required: outcome.required,
                ticks: outcome.ticks, row: scored, replay: witness, error: nil))
            print("CHECK", id.packID, id.levelID, clock.rawValue, outcome.saved, outcome.required,
                outcome.didWin ? "WIN" : "LOSS")
        } catch {
            checks.append(CandidateCheck(entry: row.entry, sourceReplaySHA256: source.sourceReplaySHA256,
                sourceSaved: source.sourceSaved, sourceTicks: source.sourceTicks,
                clock: clock, initialHash: hash, saved: nil, required: nil, ticks: nil,
                row: nil, replay: nil, error: String(describing: error)))
            print("CHECK", id.packID, id.levelID, clock.rawValue, "ERROR", error)
        }
        fflush(stdout)
        try encoder.encode(checks).write(to: output, options: .atomic)
    }
}
print("DONE", checks.count, "native wins", checks.filter { $0.row != nil }.count)
