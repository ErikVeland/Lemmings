import Foundation
import CryptoKit
import NxlvKit

struct Row: Codable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let official: Bool
    let order: Int
    let playable: Bool
    let initialHash: String?
}
let args = CommandLine.arguments
var rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
struct BundledPack: Decodable { let id: Int }
let project = URL(fileURLWithPath: args[1]).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let bundledPacks = try Set(JSONDecoder().decode([BundledPack].self,
    from: Data(contentsOf: project.appendingPathComponent("Content/LevelPacks/packs.json")))
    .map { "fan:lldb-\($0.id)" })
rows.removeAll { $0.entry.identity.packID.hasPrefix("fan:lldb-") && !bundledPacks.contains($0.entry.identity.packID) }
if args.count > 3 {
    let extra = try JSONDecoder().decode([Row].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
    let byID = Dictionary(uniqueKeysWithValues: extra.map { ($0.entry.identity, $0) })
    rows = rows.map { original in
        guard let candidate = byID[original.entry.identity], !original.official,
              candidate.entry.sourceRevision == original.entry.sourceRevision,
              candidate.initialHash == original.initialHash,
              candidate.profile.confidence != .low else { return original }
        return original.profile.confidence == .low || candidate.profile.overallScore < original.profile.overallScore ? candidate : original
    }
}
// Reviewed corrections can raise a score. Do not keep an older underestimate
// merely because it has a lower score than the corrected evidence.
let reviewedURL = project.appendingPathComponent("Artifacts/LearningJourney/reviewed-evidence.json")
if let data = try? Data(contentsOf: reviewedURL) {
    let reviewed = try JSONDecoder().decode([Row].self, from: data)
    for correction in reviewed {
        guard let index = rows.firstIndex(where: { $0.entry.identity == correction.entry.identity }),
              rows[index].entry.sourceRevision == correction.entry.sourceRevision,
              rows[index].initialHash == correction.initialHash,
              correction.profile.confidence != .low else { throw LevelPlaylistError.invalidEntry }
        rows[index] = correction
    }
}
struct Scenarios: Decodable { let official: [String]; let fan: [String: String] }
let scenarios = try JSONDecoder().decode(Scenarios.self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
var usedScenarios = Set(scenarios.official)
let official = rows.filter { $0.official && LearningJourney.isSinglePlayer($0.entry, sourceRank: $0.profile.sourceRank) }
guard official.allSatisfy({ $0.initialHash != nil }) else { throw LevelPlaylistError.invalidPool }
func title(_ row: Row) -> String {
    row.entry.levelNameSnapshot.lowercased().filter { $0.isLetter || $0.isNumber }
}
// Prefer the mainline release when the same official puzzle also appeared in a seasonal pack.
func officialPriority(_ row: Row) -> Int {
    switch row.entry.packNameSnapshot {
    case "Lemmings": return 0
    case "Oh No! More Lemmings": return 1
    default: return 2
    }
}
var officialHashes = Set<String>()
var officialTitlesByPack = Set<String>()
let uniqueOfficial = official.sorted {
    let left = officialPriority($0), right = officialPriority($1)
    return left == right ? $0.order < $1.order : left < right
}.filter { row in
    let packTitle = row.entry.packNameSnapshot + "\0" + title(row)
    guard let hash = row.initialHash, !officialHashes.contains(hash), !officialTitlesByPack.contains(packTitle) else { return false }
    officialHashes.insert(hash)
    officialTitlesByPack.insert(packTitle)
    return true
}
var hashes = officialHashes
let officialTitles = Set(uniqueOfficial.map(title))
var titlesByPack = officialTitlesByPack
let selectionOrder = rows.sorted {
    if $0.profile.overallScore != $1.profile.overallScore { return $0.profile.overallScore < $1.profile.overallScore }
    return $0.entry.identity.packID + $0.entry.identity.levelID < $1.entry.identity.packID + $1.entry.identity.levelID
}
let officialIDs = Set(uniqueOfficial.map { $0.entry.identity })
let pool = selectionOrder.filter {
    guard LearningJourney.isSinglePlayer($0.entry, sourceRank: $0.profile.sourceRank), $0.playable, $0.profile.confidence != .low else { return false }
    if $0.official { return officialIDs.contains($0.entry.identity) }
    // Port packs with numbered ranks are alternate presentations of the main Classic campaign.
    let pack = $0.entry.packNameSnapshot
    if ["Amiga Fun", "Amiga Tricky", "Amiga Taxing", "Amiga Mayhem"].contains(where: { pack.hasPrefix($0) }) { return false }
    if officialTitles.contains(title($0)) { return false }
    // Empty or hands-free fan records do not teach a bridge concept.
    guard !$0.profile.detectedTechniques.isEmpty,
          let scenario = scenarios.fan[$0.entry.identity.packID + "\0" + $0.entry.identity.levelID],
          let hash = $0.initialHash,
          !usedScenarios.contains(scenario), !hashes.contains(hash),
          !titlesByPack.contains(pack + "\0" + title($0)) else { return false }
    usedScenarios.insert(scenario)
    hashes.insert(hash)
    titlesByPack.insert(pack + "\0" + title($0))
    return true
}
guard pool.filter(\.official).count == uniqueOfficial.count else { throw LevelPlaylistError.invalidPool }
let poolEncoder = JSONEncoder(); poolEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let poolURL = project.appendingPathComponent(".build/learning-journey/pool.json")
try poolEncoder.encode(pool).write(to: poolURL, options: .atomic)
if ProcessInfo.processInfo.environment["LEARNING_EXPORT_POOL"] == "1" { exit(0) }
struct Curriculum: Decodable {
    struct Goal: Decodable { let identity: LevelCatalogueIdentity; let objective: String; let lesson: String }
    let lessons: [Goal]
}
let curriculum = try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: project.appendingPathComponent("Artifacts/LearningJourney/curriculum.json")))
let goals = Dictionary(uniqueKeysWithValues: curriculum.lessons.map { ($0.identity, $0) })
guard Set(curriculum.lessons.map(\.objective)).count == curriculum.lessons.count else { throw LevelPlaylistError.invalidPool }
let selected = pool.filter { goals[$0.entry.identity] != nil }
guard selected.count == goals.count else { throw LevelPlaylistError.invalidPool }
let candidates = selected.map { ProgressionCandidate(entry: $0.entry, profile: $0.profile, isOfficial: $0.official, campaignOrder: $0.order) }
let focuses = goals.mapValues(\.lesson)
let objectives = goals.mapValues(\.objective)
let journey = try LearningJourney.generate(candidates, focuses: focuses, objectives: objectives)
let repeated = try LearningJourney.generate(candidates.reversed(), focuses: focuses, objectives: objectives)
guard journey == repeated else { throw LevelPlaylistError.invalidSequence }
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
// Keep each profile tied to the exact replay that produced its measurements.
let indexURL = URL(fileURLWithPath: args[3]).deletingLastPathComponent().appendingPathComponent("candidate-solutions.json")
var witnesses = try JSONDecoder().decode([String: ClassicDOSReplay].self, from: Data(contentsOf: indexURL))
let legacyURL = URL(fileURLWithPath: args[1]).deletingLastPathComponent().appendingPathComponent("verified-fan-replays.json")
if let data = try? Data(contentsOf: legacyURL), let legacy = try? JSONDecoder().decode([ClassicDOSReplay].self, from: data) {
    for replay in legacy {
        let digest = SHA256.hash(data: try encoder.encode(replay))
        witnesses[digest.description] = replay
        witnesses[digest.map { String(format: "%02x", $0) }.joined()] = replay
    }
}
for row in selected where !row.official {
    guard let replay = witnesses[row.profile.key.replayRevision], replay.expected?.didWin == true,
          replay.initialStateHash == row.initialHash else { throw LevelPlaylistError.invalidEntry }
    let digest = SHA256.hash(data: try encoder.encode(replay))
    guard row.profile.key.replayRevision == digest.description || row.profile.key.replayRevision == digest.map({ String(format: "%02x", $0) }).joined() else {
        throw LevelPlaylistError.invalidEntry
    }
}
try encoder.encode(witnesses).write(to: indexURL, options: .atomic)
let output = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try encoder.encode(journey).write(to: output, options: .atomic)
let jumps = zip(journey.lessons, journey.lessons.dropFirst()).map { $1.demand - $0.demand }
print("\(journey.lessons.count) lessons; \(selected.filter(\.official).count) official; \(selected.filter { !$0.official }.count) fan. Largest curriculum demand step: \(jumps.max() ?? 0). Support flags: \(journey.lessons.filter(\.needsSupport).count).")
for lesson in journey.lessons.prefix(20) { print("\(Int(lesson.score)): \(lesson.entry.levelNameSnapshot) — \(lesson.focus)") }
