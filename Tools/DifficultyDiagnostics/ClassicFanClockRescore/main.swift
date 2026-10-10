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

struct ClockCheck: Decodable {
    let packID: String
    let levelID: String
    let oldHash: String
    let newHash: String
    let newWin: Bool
}

struct Rescored: Codable {
    let row: EvidenceRow
    let replay: ClassicDOSReplay
    let oldHash: String
    let newHash: String
    let analysisRevision: String?
    let recoveredOldReplayDigest: String?
}

guard CommandLine.arguments.count == 4 else {
    fatalError("Usage: ClassicFanClockRescore PROJECT_ROOT BUNDLED_RESOURCES OUTPUT")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = URL(fileURLWithPath: CommandLine.arguments[2])
let ports = resources.appendingPathComponent("Ports")
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let decoder = JSONDecoder()
let base = try decoder.decode([EvidenceRow].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/ClassicProgression/audit.json")))
let fan = try decoder.decode([EvidenceRow].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/LearningJourney/fan-evidence.json")))
let solutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/LearningJourney/candidate-solutions.json")))
let hints = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf:
    root.appendingPathComponent("Resources/Hints/solutions.json")))
let checks = try decoder.decode([ClockCheck].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/DifficultyEvaluation/classic-fan-clock-audit.json")))
var rows: [String: EvidenceRow] = [:]
for row in base + fan where !row.official && row.profile.confidence != .low {
    rows[row.entry.identity.packID + "\0" + row.entry.identity.levelID] = row
}
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
let output = URL(fileURLWithPath: CommandLine.arguments[3])
let analysisRevision = "golems-clock-2-limit-from-clock-1"
let recoverableReplayKeys: Set<String> = [
    "fan:lldb-88\0Timpack1.dat#1",
    "fan:lldb-88\0Timpack1.dat#5",
    "fan:lldb-90\0Timpack3.dat#5",
]
let previous = (try? decoder.decode([Rescored].self, from: Data(contentsOf: output))) ?? []
let completed = Dictionary(uniqueKeysWithValues: previous.filter { $0.analysisRevision == analysisRevision }.map {
    ($0.row.entry.identity.packID + "\0" + $0.row.entry.identity.levelID, $0)
})
let start = Int(ProcessInfo.processInfo.environment["CLOCK_RESCORE_START"] ?? "") ?? 0
let limit = Int(ProcessInfo.processInfo.environment["CLOCK_RESCORE_LIMIT"] ?? "") ?? checks.count
precondition(start >= 0 && start <= limit && limit <= checks.count)
let selected = Array(checks[start..<limit])
print("RANGE", start, limit, "of", checks.count)
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
var packEntries: [String: [FanLevelLibrary.Entry]] = [:]
var results: [Rescored] = []
var errors: [String] = []
for check in selected {
    let identityKey = check.packID + "\0" + check.levelID
    if let done = completed[identityKey] {
        results.append(done)
        continue
    }
    print("START", results.count + errors.count + 1, check.packID, check.levelID)
    fflush(stdout)
    do {
        guard check.newWin, let old = rows[identityKey], let pack = packs[check.packID],
              let revision = FanLevelLibrary.archiveFingerprint(pack),
              revision == old.entry.sourceRevision else { throw NSError(domain: "Rescore", code: 1) }
        guard let separator = check.levelID.lastIndex(of: "#"),
              let section = Int(check.levelID[check.levelID.index(after: separator)...]) else {
            throw NSError(domain: "Rescore", code: 2)
        }
        let file = String(check.levelID[..<separator])
        let entries: [FanLevelLibrary.Entry]
        if let cached = packEntries[check.packID] { entries = cached }
        else {
            entries = try FanLevelLibrary.validatedEntries(in: pack)
            packEntries[check.packID] = entries
        }
        guard let item = entries.first(where: { $0.file == file && ($0.section ?? -1) == section }) else {
            throw NSError(domain: "Rescore", code: 2)
        }
        let (level, style) = try FanLevelLibrary.level(item, in: pack)
        let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
        let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
            objectSemantics: .forFanLevel(level, groundSet: ground))
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mainDATAssets: assets, clock: .golems)
        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
        guard hash == check.newHash, check.oldHash == old.initialHash,
              let oldReplay = solutions[old.profile.key.replayRevision] ?? hints[check.oldHash] ?? solutions[check.oldHash],
              oldReplay.initialStateHash == check.oldHash else { throw NSError(domain: "Rescore", code: 3) }
        let oldDigest = SHA256.hash(data: try encoder.encode(oldReplay)).description
        let oldDigestMatches = old.profile.key.replayRevision == oldDigest ||
            old.profile.key.replayRevision == String(oldDigest.dropFirst("SHA256 digest: ".count))
        if !oldDigestMatches {
            guard recoverableReplayKeys.contains(identityKey) else { throw NSError(domain: "Rescore", code: 4) }
            let dosInitial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
                mainDATAssets: assets, clock: .dos)
            guard ClassicDOSReplayRecorder.stateHash(of: dosInitial) == check.oldHash else {
                throw NSError(domain: "Rescore", code: 4)
            }
            let oldCandidate = ClassicDOSReplay(rank: oldReplay.rank, number: oldReplay.number,
                title: oldReplay.title, initialStateHash: check.oldHash, events: oldReplay.events)
            guard try ClassicDOSReplayPlayer.run(oldCandidate, simulation: dosInitial,
                tickLimit: 20_000).didWin else { throw NSError(domain: "Rescore", code: 4) }
        }
        let candidate = ClassicDOSReplay(rank: oldReplay.rank, number: oldReplay.number,
            title: oldReplay.title, initialStateHash: hash, events: oldReplay.events)
        let outcome = try ClassicDOSReplayPlayer.run(candidate, simulation: initial, tickLimit: 20_000)
        guard outcome.didWin else { throw NSError(domain: "Rescore", code: 5) }
        let witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number,
            title: candidate.title, initialStateHash: hash, events: candidate.events, expected: outcome)
        let digest = SHA256.hash(data: try encoder.encode(witness)).description
        let key = DifficultyCacheKey(identity: old.entry.identity, levelRevision: old.entry.sourceRevision,
            replayRevision: digest, assetsRevision: hash + ":probes-10",
            simulationVersion: DifficultyModel.simulationVersion + ":" + analysisRevision)
        let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: witness,
            key: key, maximumProbeRuns: 10)
        let row = EvidenceRow(entry: old.entry, profile: profile, official: false, order: old.order,
            playable: old.playable, initialHash: hash, issue: nil)
        results.append(Rescored(row: row, replay: witness, oldHash: check.oldHash,
            newHash: hash, analysisRevision: analysisRevision,
            recoveredOldReplayDigest: oldDigestMatches ? nil : oldDigest))
        print("SCORED", results.count + errors.count, profile.overallScore)
        fflush(stdout)
    } catch {
        errors.append("\(check.packID)/\(check.levelID): \(error)")
    }
    if (results.count + errors.count) % 25 == 0 {
        print("PROGRESS", results.count + errors.count, selected.count, "rescored", results.count, "errors", errors.count)
        fflush(stdout)
        try encoder.encode(results).write(to: output, options: .atomic)
    }
}
try encoder.encode(results).write(to: output, options: .atomic)
print("DONE", results.count, selected.count, "errors", errors.count)
for error in errors { print("ERROR", error) }
if !errors.isEmpty { exit(1) }
