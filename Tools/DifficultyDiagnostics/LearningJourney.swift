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
    var startingReleaseRate: Int? = nil
    var rescueRequirementRatio: Double? = nil
    var skillAssignmentCount: Int? = nil
}
let args = CommandLine.arguments
var rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
struct BundledPack: Decodable { let id: Int }
struct SourceEngineFamilies: Decodable { let lemminiPackIDs: [Int] }
let project = URL(fileURLWithPath: args[1]).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let sourceFamilies = try JSONDecoder().decode(SourceEngineFamilies.self,
    from: Data(contentsOf: project.appendingPathComponent("Artifacts/DifficultyEvaluation/source-engine-families.json")))
let lemminiPackIDs = Set(sourceFamilies.lemminiPackIDs.map { "fan:lldb-\($0)" })
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
        guard original.profile.confidence == .low || candidate.profile.overallScore < original.profile.overallScore else {
            return original
        }
        return Row(entry: candidate.entry, profile: candidate.profile, official: candidate.official,
                   order: candidate.order, playable: candidate.playable, initialHash: candidate.initialHash,
                   startingReleaseRate: original.startingReleaseRate,
                   rescueRequirementRatio: original.rescueRequirementRatio,
                   skillAssignmentCount: original.skillAssignmentCount)
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
    // A Classic win from a Lemmini pack cannot establish the intended source behaviour.
    if lemminiPackIDs.contains($0.entry.identity.packID) { return false }
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
// This executable exports evidence only. Production placement is community-curated
// by human_journey.py; the replay-only experimental generator cannot publish it.
print("Exported \(pool.count) candidates for source and human-review audit.")
