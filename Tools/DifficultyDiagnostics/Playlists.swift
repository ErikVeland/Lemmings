import Foundation
import NxlvKit

let args = CommandLine.arguments
if args.count != 4 { print("Usage: DifficultyPlaylistDiagnostics PROFILES CLASSIC_ROOT OUTPUT"); exit(2) }
let profilesURL = URL(fileURLWithPath: args[1])
let profiles = try JSONDecoder().decode([DifficultyProfile].self, from: Data(contentsOf: profilesURL))
let campaign = try ClassicDataSet.detect(directory: URL(fileURLWithPath: args[2]))
var candidates: [ProgressionCandidate] = []
for (index, profile) in profiles.enumerated() {
    let identity = profile.key.identity
    let nativeIndex = identity.packID == campaign.identifierKey ? Int(identity.levelID.split(separator: ":").first ?? "") : nil
    let native = nativeIndex.flatMap { campaign.campaign.levels.indices.contains($0) ? campaign.campaign.levels[$0] : nil }
    let official = native != nil && campaign.kind != .scanned && campaign.title != nil
    let entry = try LevelPlaylistEntry(identity: identity, catalogueRevision: "diagnostic-v1",
        sourceRevision: profile.key.levelRevision, packNameSnapshot: official ? campaign.name : identity.packID,
        levelNameSnapshot: native?.level.title ?? identity.levelID, levelNumberSnapshot: (nativeIndex ?? index) + 1)
    candidates.append(.init(entry: entry, profile: profile, isOfficial: official, campaignOrder: nativeIndex ?? index))
}
let priorURL = profilesURL.deletingLastPathComponent().appendingPathComponent("report.json")
let prior = (try? Data(contentsOf: priorURL)).flatMap { try? JSONDecoder().decode(DifficultyCorpusReport.self, from: $0) }
let report = try DifficultyCorpusReport(candidates: candidates, failures: prior?.failures ?? [],
    limitations: (prior?.limitations ?? []) + ["Playlists regenerated from cached profiles with " + ProgressionModel.version + "; no physics rerun."])
let output = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: output, options: .atomic)
print("Regenerated \(report.levels) cached profiles with \(ProgressionModel.version).")
