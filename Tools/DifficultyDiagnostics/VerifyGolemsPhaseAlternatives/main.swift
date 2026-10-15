import CryptoKit
import Darwin
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
let selectedOnly = ProcessInfo.processInfo.environment["LEMMINGS_PHASE_ALTERNATIVES_SELECTED_ONLY"] == "1"
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
    resources.appendingPathComponent("LevelPacks")
]).map { ("fan:" + FanLevelLibrary.catalogueID($0), $0) })
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
var recordFailures: [String] = []
var recordPasses = 0
if !selectedOnly {
    for record in evidences.flatMap(\.records) {
        print("CHECK", record.identity.packID, record.identity.levelID)
        fflush(stdout)
        do {
            guard let pack = packs[record.identity.packID] else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "missing pack \(record.identity.packID)"])
            }
            let archiveData = try Data(contentsOf: pack)
            guard digest(archiveData) == record.bundledArchiveSHA256 else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "bundled archive hash mismatch"])
            }
            let replayData = try Data(contentsOf: root.appendingPathComponent(record.replayPath))
            guard digest(replayData) == record.nativeReplaySHA256 else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "replay hash mismatch"])
            }
            let replay = try decoder.decode(ClassicDOSReplay.self, from: replayData)
            guard replay.rank == record.identity.packID else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "replay pack identity mismatch"])
            }
            let entries = try FanLevelLibrary.validatedEntries(in: pack)
            guard entries.indices.contains(replay.number - 1) else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "replay level number is out of range"])
            }
            let entry = entries[replay.number - 1]
            guard entry.file + "#" + String(entry.section ?? -1) == record.identity.levelID else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "replay level identity mismatch"])
            }
            let (level, style) = try FanLevelLibrary.level(entry, in: pack)
            let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
                portsRoot: ports, pack: pack, entry: entry)
            let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry,
                pack: pack, portsRoot: ports)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground,
                specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
            let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
                mainDATAssets: assets, mechanics: .golems, clock: .golems)
            guard ClassicDOSReplayRecorder.stateHash(of: initial) == record.initialStateHash else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "initial state hash mismatch"])
            }
            let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
            guard outcome.didWin && outcome.saved == record.nativeSaved &&
                outcome.required == record.required && outcome.ticks == record.nativeCompletionTick else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 8,
                    userInfo: [NSLocalizedDescriptionKey: "recorded \(record.nativeSaved)/\(record.required) in \(record.nativeCompletionTick) ticks; replay got \(outcome.saved)/\(outcome.required) in \(outcome.ticks) ticks"])
            }
            let profile = try decoder.decode(DifficultyProfile.self, from: Data(contentsOf:
                root.appendingPathComponent(record.profilePath)))
            guard profile.key.identity == record.identity &&
                profile.key.replayRevision.hasSuffix(record.nativeReplaySHA256) &&
                profile.overallScore == record.difficultyScore else {
                throw NSError(domain: "VerifyGolemsPhaseAlternatives", code: 9,
                    userInfo: [NSLocalizedDescriptionKey: "difficulty profile provenance mismatch"])
            }
            recordPasses += 1
            print("PASS", record.identity.packID, record.identity.levelID,
                outcome.saved, outcome.required, outcome.ticks, profile.overallScore)
        } catch {
            let failure = "\(record.identity.packID) \(record.identity.levelID): \(error)"
            recordFailures.append(failure)
            print("FAIL", failure)
        }
    }
    let recordCount = evidences.reduce(0) { $0 + $1.records.count }
    print("Verified", recordPasses, "of", recordCount, "strict Golems-profile winning replays and scores")

    let profileReplayNames = ["cliffhanger", "its-raining-lemmings-passive",
        "its-raining-lemmings", "pinpoint-accuracy", "the-delivery-service"]
    var profilePasses = 0
    var profileFailures: [String] = []
    for name in profileReplayNames {
        do {
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
            profilePasses += 1
        } catch {
            let failure = "\(name): \(error)"
            profileFailures.append(failure)
            print("FAIL profile", failure)
        }
    }
    print("Verified", profilePasses, "of", profileReplayNames.count,
        "additional Golems-profile winning replays and scores")
    if !profileFailures.isEmpty {
        recordFailures.append(contentsOf: profileFailures)
    }
}

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
    ("fan:lldb-245", "Martin Zurlinden 02.dat#5"),
    ("fan:lldb-496", "MARTPCK2.DAT#4"),
    ("fan:lldb-246", "Martin Zurlinden 03.dat#5"),
    ("fan:lldb-497", "MARTPCK3.DAT#5"),
]
let replayEncoder = JSONEncoder()
replayEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
var selectedFailures: [String] = []
var selectedPasses = 0
for (packID, levelID) in selectedIDs {
    do {
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
        let mechanics = FanLevelLibrary.mechanics(for: pack, entry: entry)
        precondition(mechanics == .golems)
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mainDATAssets: assets, mechanics: mechanics, clock: .golems)
        precondition(ClassicDOSReplayRecorder.stateHash(of: initial) == row.initialHash)
        precondition(replay.sourceRules == nil)
        let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
        precondition(outcome.didWin && replay.expected == outcome)
        print("PASS selected", levelID, outcome.saved, outcome.required, outcome.ticks,
            row.profile.overallScore)
        selectedPasses += 1
    } catch {
        let failure = "\(packID) \(levelID): \(error)"
        selectedFailures.append(failure)
        print("FAIL selected", failure)
    }
}
print("Replayed", selectedIDs.count, "selected Golems-pack rows:", selectedPasses,
    "passed,", selectedFailures.count, "failed")
if !recordFailures.isEmpty {
    FileHandle.standardError.write(Data(("\(recordFailures.count) Golems-profile replay records failed.\n" +
        recordFailures.joined(separator: "\n") + "\n").utf8))
    exit(1)
}
if !selectedFailures.isEmpty {
    FileHandle.standardError.write(Data(("\(selectedFailures.count) selected Golems-pack replay records failed.\n" +
        selectedFailures.joined(separator: "\n") + "\n").utf8))
    exit(1)
}
