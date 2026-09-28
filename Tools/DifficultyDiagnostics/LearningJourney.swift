import Foundation
import CryptoKit
import NxlvKit

struct Row: Decodable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let official: Bool
    let order: Int
    let playable: Bool
    let initialHash: String?
}
let args = CommandLine.arguments
var rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
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
struct Scenarios: Decodable { let official: [String]; let fan: [String: String] }
let scenarios = try JSONDecoder().decode(Scenarios.self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
var usedScenarios = Set(scenarios.official)
let official = rows.filter(\.official)
var hashes = Set(official.compactMap(\.initialHash))
let selectionOrder = rows.sorted {
    if $0.profile.overallScore != $1.profile.overallScore { return $0.profile.overallScore < $1.profile.overallScore }
    return $0.entry.identity.packID + $0.entry.identity.levelID < $1.entry.identity.packID + $1.entry.identity.levelID
}
let selected = selectionOrder.filter {
    guard $0.playable, $0.profile.confidence != .low else { return false }
    if $0.official { return true }
    // Empty or hands-free fan records do not teach a bridge concept.
    guard !$0.profile.detectedTechniques.isEmpty,
          let scenario = scenarios.fan[$0.entry.identity.packID + "\0" + $0.entry.identity.levelID],
          usedScenarios.insert(scenario).inserted else { return false }
    guard let hash = $0.initialHash else { return false }
    return hashes.insert(hash).inserted
}
guard selected.filter(\.official).count == official.count else { throw LevelPlaylistError.invalidPool }
let candidates = selected.map { ProgressionCandidate(entry: $0.entry, profile: $0.profile, isOfficial: $0.official, campaignOrder: $0.order) }
let journey = try LearningJourney.generate(candidates)
let repeated = try LearningJourney.generate(candidates.reversed())
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
print("\(journey.lessons.count) lessons; \(official.count) official; \(selected.count - official.count) fan. Largest curriculum demand step: \(jumps.max() ?? 0). Support flags: \(journey.lessons.filter(\.needsSupport).count).")
for lesson in journey.lessons.prefix(20) { print("\(Int(lesson.score)): \(lesson.entry.levelNameSnapshot) — \(lesson.focus)") }
