import Foundation
import CryptoKit
import NxlvKit

let simulationRevision = ProcessInfo.processInfo.environment["DIFFICULTY_SIMULATION_REVISION"] ?? DifficultyModel.simulationVersion
let args = CommandLine.arguments
if args.count != 5 { print("Usage: OfficialDifficultyDiagnostics CLASSIC_ROOT SOLUTIONS_JSON COMMUNITY_PROFILES OUTPUT"); exit(2) }
let root = URL(fileURLWithPath: args[1])
let dataSet = try ClassicDataSet.detect(directory: root)
let records = try JSONDecoder().decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let assets = try ClassicMainDATAssets.load(from: root)
var grounds: [Int: ClassicGroundSet] = [:]
var candidates: [ProgressionCandidate] = []
var failures: [String] = []
for (index, level) in dataSet.campaign.levels.enumerated() {
    let identity = LevelCatalogueIdentity(engine: .classic, packID: dataSet.identifierKey, levelID: "\(index):\(level.rank):\(level.number)")
    do {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let revision = SHA256.hash(data: try encoder.encode(level.level.properties)).map { String(format: "%02x", $0) }.joined()
        var key = DifficultyCacheKey(identity: identity, levelRevision: revision, simulationVersion: simulationRevision)
        let metadata = DifficultyMetadataEvidence(availableSkills: Dictionary(uniqueKeysWithValues: level.level.skills.map { ($0.key.rawValue, $0.value) }),
            population: level.level.lemmingCount, rescueRequirement: level.level.saveRequirement,
            timeLimitFrames: level.level.timeLimitMinutes * 60 * 17,
            interactingSystems: Set(level.level.objects.map(\.id)).count, rank: level.rank)
        var profile = DifficultyScorer.analyse(key: key, metadata: metadata)
        do {
            let ground: ClassicGroundSet
            if let cached = grounds[level.level.groundStyle] { ground = cached }
            else { ground = try ClassicGroundSet.load(style: level.level.groundStyle, from: root); grounds[level.level.groundStyle] = ground }
            let special = level.level.specialStyle > 0 ? try ClassicSpecialGraphic.load(index: level.level.specialStyle - 1, from: root) : nil
            let rendered = try ClassicLevelRenderer.render(level.level, groundSet: ground, specialGraphic: special)
            let initial = try ClassicDOSSimulation(level: level.level, renderedLevel: rendered, mainDATAssets: assets)
            let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
            if let replay = records[hash] {
                let replayHash = SHA256.hash(data: try encoder.encode(replay)).map { String(format: "%02x", $0) }.joined()
                key = DifficultyCacheKey(identity: identity, levelRevision: revision, replayRevision: replayHash, assetsRevision: hash, simulationVersion: simulationRevision)
                profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: replay, key: key, maximumProbeRuns: 10)
            }
        } catch { failures.append("\(level.rank) \(level.number): \(error)") }
        let entry = try LevelPlaylistEntry(identity: identity, catalogueRevision: "diagnostic-v1", sourceRevision: revision,
            packNameSnapshot: dataSet.name, levelNameSnapshot: level.level.title, levelNumberSnapshot: index + 1)
        candidates.append(.init(entry: entry, profile: profile, isOfficial: dataSet.kind != .scanned && dataSet.title != nil,
            campaignOrder: index))
        if index % 10 == 0 { print("Official \(index + 1)/\(dataSet.campaign.levels.count)"); fflush(stdout) }
    } catch { failures.append("\(identity.levelID): \(error)") }
}
let community = try JSONDecoder().decode([DifficultyProfile].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
let communityReportURL = URL(fileURLWithPath: args[3]).deletingLastPathComponent().appendingPathComponent("report.json")
if let data = try? Data(contentsOf: communityReportURL),
   let report = try? JSONDecoder().decode(DifficultyCorpusReport.self, from: data) {
    failures.append(contentsOf: report.failures.map { "NeoLemmix: " + $0 })
}
for (index, profile) in community.enumerated() {
    let entry = try LevelPlaylistEntry(identity: profile.key.identity, catalogueRevision: "diagnostic-v1", sourceRevision: profile.key.levelRevision,
        packNameSnapshot: profile.key.identity.packID, levelNameSnapshot: profile.key.identity.levelID, levelNumberSnapshot: index + 1)
    candidates.append(.init(entry: entry, profile: profile, isOfficial: false))
}
let report = try DifficultyCorpusReport(candidates: candidates, failures: failures,
    limitations: ["Ten perturbation runs per replay in this bounded corpus audit.", "Classic retail provenance comes from ClassicDataSet; NXLV provenance remains community/unverified.", "Deduction is a proxy. Metadata-only grades remain weak priors."])
let output = URL(fileURLWithPath: args[4])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: output.appendingPathComponent("report.json"), options: .atomic)
try encoder.encode(candidates.map(\.profile)).write(to: output.appendingPathComponent("profiles.json"), options: .atomic)
print("Completed \(candidates.count) combined levels; \(failures.count) failures.")
