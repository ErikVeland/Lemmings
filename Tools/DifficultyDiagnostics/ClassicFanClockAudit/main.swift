import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}

struct EvidenceRow: Decodable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let official: Bool
    let initialHash: String?
}

struct Recheck: Codable {
    let packID: String
    let levelID: String
    let oldHash: String
    let newHash: String?
    let oldSaved: Int?
    let newSaved: Int?
    let oldTicks: Int?
    let newTicks: Int?
    let newWin: Bool?
    let error: String?
}

guard CommandLine.arguments.count == 7 else {
    fatalError("Usage: ClassicFanClockAudit RESOURCES AUDIT FAN_EVIDENCE SOLUTIONS HINTS OUTPUT")
}
let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let ports = resources.appendingPathComponent("Ports")
let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let audit = try decoder.decode([EvidenceRow].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
let supplemental = try decoder.decode([EvidenceRow].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
let solutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[4])))
let hints = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[5])))
let packURLs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
var rows: [String: EvidenceRow] = [:]
for row in audit + supplemental where !row.official && row.profile.confidence != .low {
    rows[row.entry.identity.packID + "\0" + row.entry.identity.levelID] = row
}
let ordered = rows.values.sorted {
    ($0.entry.identity.packID, $0.entry.identity.levelID) < ($1.entry.identity.packID, $1.entry.identity.levelID)
}
let limit = Int(ProcessInfo.processInfo.environment["CLOCK_AUDIT_LIMIT"] ?? "") ?? ordered.count
let selected = Array(ordered.prefix(limit))
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
let masks = try ClassicDOSDestructionMaskSet(mainDATMasks: assets.destructionMasks)
let output = URL(fileURLWithPath: CommandLine.arguments[6])
let previous = (try? decoder.decode([Recheck].self, from: Data(contentsOf: output))) ?? []
let completed = Dictionary(uniqueKeysWithValues: previous.filter { $0.error == nil }.map {
    ($0.packID + "\0" + $0.levelID, $0)
})
var checks: [Recheck] = []
var winCount = 0
var changedHashCount = 0
var oldErrors = 0
var packEntries: [String: [FanLevelLibrary.Entry]] = [:]
for row in selected {
    let id = row.entry.identity
    let oldHash = row.initialHash ?? ""
    if let saved = completed[id.packID + "\0" + id.levelID] {
        checks.append(saved)
        if saved.newWin == true { winCount += 1 }
        if saved.newHash != saved.oldHash { changedHashCount += 1 }
        continue
    }
    do {
        guard let pack = packURLs[id.packID] else { throw NSError(domain: "Audit", code: 1) }
        let section = Int(id.levelID.split(separator: "#").last ?? "") ?? -1
        let file = id.levelID.replacingOccurrences(of: "#\(section)", with: "")
        let entries: [FanLevelLibrary.Entry]
        if let cached = packEntries[id.packID] { entries = cached }
        else {
            entries = try FanLevelLibrary.validatedEntries(in: pack)
            packEntries[id.packID] = entries
        }
        guard let item = entries.first(where: {
            $0.file == file && ($0.section ?? -1) == section
        }) else { throw NSError(domain: "Audit", code: 2) }
        let (level, style) = try FanLevelLibrary.level(item, in: pack)
        let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
        let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
            objectSemantics: .forFanLevel(level, groundSet: ground))
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        guard ClassicDOSReplayRecorder.stateHash(of: initial) == oldHash,
              let replay = solutions[row.profile.key.replayRevision] ?? hints[oldHash] ?? solutions[oldHash],
              replay.initialStateHash == oldHash else { throw NSError(domain: "Audit", code: 3) }
        let old = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
        guard old.didWin else { throw NSError(domain: "Audit", code: 4) }
        let c = initial.configuration
        let configuration = ClassicDOSConfiguration(
            totalLemmings: c.totalLemmings, requiredToSave: c.requiredToSave,
            timeLimitTicks: c.timeLimitTicks.map { $0 + 2 }, initialReleaseRate: c.initialReleaseRate,
            entrances: c.entrances, triggers: c.triggers, initialSkills: c.initialSkills,
            maximumX: c.maximumX, maximumY: c.maximumY, mechanics: c.mechanics)
        let extended = try ClassicDOSSimulation(terrain: initial.terrain,
            configuration: configuration, destructionMasks: masks)
        let newHash = ClassicDOSReplayRecorder.stateHash(of: extended)
        if newHash != oldHash { changedHashCount += 1 }
        let candidate = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
            initialStateHash: newHash, events: replay.events)
        let outcome = try ClassicDOSReplayPlayer.run(candidate, simulation: extended, tickLimit: 20_000)
        if outcome.didWin { winCount += 1 }
        checks.append(Recheck(packID: id.packID, levelID: id.levelID, oldHash: oldHash,
            newHash: newHash, oldSaved: old.saved, newSaved: outcome.saved,
            oldTicks: old.ticks, newTicks: outcome.ticks, newWin: outcome.didWin, error: nil))
    } catch {
        oldErrors += 1
        checks.append(Recheck(packID: id.packID, levelID: id.levelID, oldHash: oldHash,
            newHash: nil, oldSaved: nil, newSaved: nil,
            oldTicks: nil, newTicks: nil, newWin: nil, error: String(describing: error)))
    }
    if checks.count % 100 == 0 {
        print("PROGRESS", checks.count, selected.count, "wins", winCount, "changedHashes", changedHashCount, "errors", oldErrors)
        fflush(stdout)
        try encoder.encode(checks).write(to: output, options: .atomic)
    }
}
try encoder.encode(checks).write(to: output, options: .atomic)
print("DONE", checks.count, "wins", winCount, "changedHashes", changedHashCount, "errors", oldErrors)
if checks.contains(where: { $0.error != nil || $0.newWin != true }) { exit(1) }
