import CryptoKit
import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}

private struct Evidence: Decodable {
    let records: [Record]
}

private struct SelectedRow: Decodable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let initialHash: String?
}

private struct Record: Decodable {
    let identity: LevelCatalogueIdentity
    let bundledArchiveSHA256: String
    let initialStateHash: String
    let nativeReplaySHA256: String
    let nativeSaved: Int
    let required: Int
    let nativeCompletionTick: Int
    let difficultyScore: Double
    let replayPath: String
    let profilePath: String
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = URL(fileURLWithPath: CommandLine.arguments[2])
let ports = resources.appendingPathComponent("Ports")
let decoder = JSONDecoder()
private let evidenceNames = [
    "classic-golems-phase-shift-alternatives.json",
    "classic-golems-phase-shift-targeted.json",
    "classic-golems-phase-shift-second.json",
    "classic-golems-phase-shift-third.json",
    "classic-golems-local-basher-timing-recovery.json",
]
private let evidences = try evidenceNames.map { name in
    try decoder.decode(Evidence.self, from: Data(contentsOf: root.appendingPathComponent(
        "Artifacts/DifficultyEvaluation/" + name)))
}
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [
    root.appendingPathComponent("Content/LevelPacks")
]).map { ("fan:" + FanLevelLibrary.catalogueID($0), $0) })
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))

for record in evidences.flatMap(\.records) {
    print("CHECK", record.identity.packID, record.identity.levelID)
    fflush(stdout)
    guard let pack = packs[record.identity.packID] else { fatalError("Missing pack: \(record.identity.packID)") }
    let archiveData = try Data(contentsOf: pack)
    precondition(digest(archiveData) == record.bundledArchiveSHA256)
    let replayData = try Data(contentsOf: root.appendingPathComponent(record.replayPath))
    precondition(digest(replayData) == record.nativeReplaySHA256)
    let replay = try decoder.decode(ClassicDOSReplay.self, from: replayData)
    precondition(replay.rank == record.identity.packID)
    let entries = try FanLevelLibrary.validatedEntries(in: pack)
    precondition(entries.indices.contains(replay.number - 1))
    let entry = entries[replay.number - 1]
    precondition(entry.file + "#" + String(entry.section ?? -1) == record.identity.levelID)
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
        portsRoot: ports, pack: pack, entry: entry)
    let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry,
        pack: pack, portsRoot: ports)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
        specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
        mainDATAssets: assets, mechanics: .golems, clock: .golems)
    precondition(ClassicDOSReplayRecorder.stateHash(of: initial) == record.initialStateHash)
    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
    precondition(outcome.didWin && outcome.saved == record.nativeSaved &&
        outcome.required == record.required && outcome.ticks == record.nativeCompletionTick)
    let profile = try decoder.decode(DifficultyProfile.self, from: Data(contentsOf:
        root.appendingPathComponent(record.profilePath)))
    precondition(profile.key.identity == record.identity &&
        profile.key.replayRevision.hasSuffix(record.nativeReplaySHA256) &&
        profile.overallScore == record.difficultyScore)
    print("PASS", record.identity.packID, record.identity.levelID,
        outcome.saved, outcome.required, outcome.ticks, profile.overallScore)
}
print("Verified", evidences.reduce(0) { $0 + $1.records.count },
    "strict Golems-profile winning replays and scores")

let profileReplayNames = ["cliffhanger", "its-raining-lemmings-passive",
    "its-raining-lemmings", "pinpoint-accuracy", "the-delivery-service"]
for name in profileReplayNames {
    let base = root.appendingPathComponent("Artifacts/DifficultyEvaluation/golems-profile-replays/" + name)
    let replayData = try Data(contentsOf: base.appendingPathExtension("json"))
    let replay = try decoder.decode(ClassicDOSReplay.self, from: replayData)
    let profile = try decoder.decode(DifficultyProfile.self, from: Data(contentsOf:
        base.appendingPathExtension("profile.json")))
    precondition(profile.key.identity.packID == replay.rank)
    guard let pack = packs[replay.rank] else { fatalError("Missing pack: \(replay.rank)") }
    let archiveData = try Data(contentsOf: pack)
    precondition(digest(archiveData) == profile.key.levelRevision)
    precondition(profile.key.replayRevision.hasSuffix(digest(replayData)))
    let entries = try FanLevelLibrary.validatedEntries(in: pack)
    precondition(entries.indices.contains(replay.number - 1))
    let entry = entries[replay.number - 1]
    precondition(entry.file + "#" + String(entry.section ?? -1) == profile.key.identity.levelID)
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
        portsRoot: ports, pack: pack, entry: entry)
    let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry,
        pack: pack, portsRoot: ports)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
        specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
        mainDATAssets: assets, mechanics: .golems, clock: .golems)
    precondition(ClassicDOSReplayRecorder.stateHash(of: initial) == replay.initialStateHash)
    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
    precondition(outcome.didWin && outcome.saved >= outcome.required)
    print("PASS profile", name, outcome.saved, outcome.required, outcome.ticks,
        profile.overallScore)
}
print("Verified", profileReplayNames.count, "additional Golems-profile winning replays and scores")

private let selectedRows = try decoder.decode([SelectedRow].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/LearningJourney/fan-evidence.json")))
private let auditRows = try decoder.decode([SelectedRow].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/ClassicProgression/audit.json")))
let selectedSolutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/LearningJourney/candidate-solutions.json")))
let selectedIDs = [
    ("fan:lldb-433", "LDChallenge04.dat#0"),
    ("fan:lldb-433", "LDChallenge04.dat#1"),
    ("fan:lldb-290", "JUANJO1N.DAT#9"),
]
let replayEncoder = JSONEncoder()
replayEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
for (packID, levelID) in selectedIDs {
    let overlayMatches = selectedRows.filter {
        $0.entry.identity.packID == packID && $0.entry.identity.levelID == levelID
    }
    let matches = overlayMatches.isEmpty ? auditRows.filter {
        $0.entry.identity.packID == packID && $0.entry.identity.levelID == levelID
    } : overlayMatches
    precondition(matches.count == 1)
    let row = matches[0]
    guard let pack = packs[row.entry.identity.packID],
          let replay = selectedSolutions[row.profile.key.replayRevision] else {
        fatalError("Missing selected Golems replay")
    }
    let archiveData = try Data(contentsOf: pack)
    precondition(digest(archiveData) == row.entry.sourceRevision)
    let replayData = try replayEncoder.encode(replay)
    precondition(row.profile.key.replayRevision.hasSuffix(digest(replayData)))
    let entries = try FanLevelLibrary.validatedEntries(in: pack)
    let entry = entries[row.entry.levelNumberSnapshot - 1]
    precondition(entry.file + "#" + String(entry.section ?? -1) == levelID)
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
        portsRoot: ports, pack: pack, entry: entry)
    let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry,
        pack: pack, portsRoot: ports)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
        specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
    precondition(FanLevelLibrary.mechanics(for: pack) == .golems)
    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
        mainDATAssets: assets, mechanics: FanLevelLibrary.mechanics(for: pack), clock: .golems)
    precondition(ClassicDOSReplayRecorder.stateHash(of: initial) == row.initialHash)
    precondition(replay.sourceRules == nil)
    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
    precondition(outcome.didWin && replay.expected == outcome)
    print("PASS selected", levelID, outcome.saved, outcome.required, outcome.ticks,
        row.profile.overallScore)
}
print("Verified", selectedIDs.count, "selected Golems-pack winning replays and scores")
