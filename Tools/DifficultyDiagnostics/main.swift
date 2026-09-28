import Foundation
import CryptoKit
import NxlvKit

func files(_ root: URL, extension suffix: String) -> [URL] {
    (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
        .filter { $0.pathExtension.lowercased() == suffix }.sorted { $0.path < $1.path }
}
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
let simulationRevision = ProcessInfo.processInfo.environment["DIFFICULTY_SIMULATION_REVISION"] ?? DifficultyModel.simulationVersion
let args = CommandLine.arguments
if args.count < 5 {
    print("Usage: DifficultyDiagnostics LEVELS REPLAYS STYLES OUTPUT [MAX_PROBES]")
    exit(2)
}
let levelsRoot = URL(fileURLWithPath: args[1])
let replaysRoot = URL(fileURLWithPath: args[2])
let stylesRoot = URL(fileURLWithPath: args[3])
let output = URL(fileURLWithPath: args[4])
let maxProbes = args.count > 5 ? Int(args[5]) ?? 10 : 10
let resolver = NxlvStyleResolver(stylesRootURL: stylesRoot)
let renderer = NxlvRenderer()
var replayByID: [UInt64: [(NxrpReplay, String)]] = [:]
for url in files(replaysRoot, extension: "nxrp") {
    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8),
       let replay = NxrpReplayDecoder.decode(text).replay, let id = replay.metadata.levelID {
        replayByID[id, default: []].append((replay, digest(data)))
    }
}
var candidates: [ProgressionCandidate] = []
var failures: [String] = []
let levelFiles = files(levelsRoot, extension: "nxlv")
for (index, url) in levelFiles.enumerated() {
    do {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8), let level = NxlvLevel.decode(text: text).level else { continue }
        let relative = String(url.path.dropFirst(levelsRoot.path.count + 1))
        let identity = LevelCatalogueIdentity(engine: .neolemmix, packID: url.deletingLastPathComponent().lastPathComponent, levelID: relative)
        let revision = digest(data)
        var key = DifficultyCacheKey(identity: identity, levelRevision: revision, simulationVersion: simulationRevision)
        var profile = DifficultyScorer.analyse(key: key, metadata: DifficultyMetadataEvidence(level: level))
        if let id = level.id, let matches = replayByID[id],
           let pair = matches.first(where: { $0.0.metadata.levelVersion == (level.version ?? 0) }) ?? matches.first {
            do {
                let versionMismatch = pair.0.metadata.levelVersion != (level.version ?? 0)
                let source = pair.0.metadata
                let replay = versionMismatch ? NxrpReplay(
                    metadata: NxrpMetadata(user: source.user, title: source.title, author: source.author,
                        game: source.game, group: source.group, levelPosition: source.levelPosition,
                        levelID: source.levelID, levelVersion: level.version ?? 0),
                    commands: pair.0.commands, commandEvidence: pair.0.commandEvidence) : pair.0
                let resolution = resolver.resolve(level: level)
                let result = renderer.render(level: level, resolution: resolution)
                guard let rendered = result.renderedLevel, !result.hasErrors else {
                    throw NSError(domain: "Styles unavailable", code: 1)
                }
                // Content digest of rendered collision data invalidates style/mask changes.
                let terrain = try NeoLemmixTerrain(width: rendered.width, height: rendered.height,
                    solidMask: rendered.solidMask, steelMask: rendered.steelMask, oneWayMask: rendered.oneWayMask)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                var assetData = try encoder.encode(terrain)
                assetData.append(try encoder.encode(NeoLemmixConfiguration(level: level, renderedLevel: rendered).zones))
                key = DifficultyCacheKey(identity: identity, levelRevision: revision,
                    replayRevision: pair.1 + (versionMismatch ? ":source-compatible" : ""),
                    assetsRevision: digest(assetData) + "-probes-\(maxProbes)", simulationVersion: simulationRevision)
                profile = try NeoLemmixDifficultyAnalysis.analyse(level: level, rendered: rendered, replay: replay,
                    key: key, maximumProbeRuns: maxProbes)
            } catch { failures.append("\(relative): \(error)") }
        }
        let entry = try LevelPlaylistEntry(identity: identity, catalogueRevision: "diagnostic-v1", sourceRevision: revision,
            packNameSnapshot: identity.packID, levelNameSnapshot: level.title.isEmpty ? url.lastPathComponent : level.title,
            levelNumberSnapshot: index + 1)
        // This imported corpus carries no authoritative retail provenance. Do not guess.
        candidates.append(.init(entry: entry, profile: profile, isOfficial: false, campaignOrder: index))
        if index % 25 == 0 { print("Analysed \(index + 1)/\(levelFiles.count)"); fflush(stdout) }
    } catch { failures.append("\(url.lastPathComponent): \(error)") }
}
let profiles = candidates.map(\.profile)
let stats = DifficultyCorpusStatistics(profiles: profiles)
let report = try DifficultyCorpusReport(candidates: candidates, failures: failures,
    limitations: ["Retail provenance is unavailable in this NXLV corpus. Official distributions and campaign jumps are unverified.",
                  "Deduction is a proxy. Metadata-only levels do not establish grade calibration."])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: output.appendingPathComponent("report.json"), options: .atomic)
try encoder.encode(profiles).write(to: output.appendingPathComponent("profiles.json"), options: .atomic)
try encoder.encode(stats).write(to: output.appendingPathComponent("concepts.json"), options: .atomic)
print("Analysed \(profiles.count); replay analysis failures \(failures.count). Report: \(output.path)")
