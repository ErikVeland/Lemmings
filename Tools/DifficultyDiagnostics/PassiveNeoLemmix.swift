import CryptoKit
import Foundation
import NxlvKit

struct Result: Codable {
    let path: String
    let status: String
    let ticks: Int?
    let saved: Int?
    let required: Int?
    let score: Double?
    let features: [String]
    let issue: String?
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("Usage: PassiveNeoLemmix LEVELS STYLES OUTPUT\n", stderr)
    exit(2)
}
let levelsRoot = URL(fileURLWithPath: args[1])
let stylesRoot = URL(fileURLWithPath: args[2])
let output = URL(fileURLWithPath: args[3])
let urls = ((FileManager.default.enumerator(at: levelsRoot, includingPropertiesForKeys: nil)?.allObjects as? [URL]) ?? [])
    .filter { $0.pathExtension.lowercased() == "nxlv" }.sorted { $0.path < $1.path }
let resolver = NxlvStyleResolver(stylesRootURL: stylesRoot)
let renderer = NxlvRenderer()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
var results: [Result] = []
var profiles: [DifficultyProfile] = []
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
@MainActor func record(_ item: Result, count: Int) throws {
    results.append(item)
    try encoder.encode(results).write(to: output.appendingPathComponent("results.json"), options: .atomic)
    try encoder.encode(profiles).write(to: output.appendingPathComponent("profiles.json"), options: .atomic)
    print("Passive evaluation \(count)/\(urls.count): \(item.status)")
    fflush(stdout)
}
for (index, url) in urls.enumerated() {
    let path = String(url.path.dropFirst(levelsRoot.path.count + 1))
    do {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8),
              let level = NxlvLevel.decode(text: text).level else {
            throw NSError(domain: "PassiveNeoLemmix", code: 1)
        }
        let resolution = resolver.resolve(level: level)
        let rendering = renderer.render(level: level, resolution: resolution)
        guard let rendered = rendering.renderedLevel, !rendering.hasErrors else {
            throw NSError(domain: "PassiveNeoLemmix", code: 2)
        }
        let features = NeoLemmixRules.unsupportedFeatures(level: level, renderedLevel: rendered)
        if !features.isEmpty {
            try record(Result(path: path, status: "unsupported", ticks: nil, saved: nil,
                              required: level.saveRequirement, score: nil, features: features, issue: nil), count: index + 1)
            continue
        }
        var simulation = try NeoLemmixSimulation(level: level, renderedLevel: rendered)
        while !simulation.isComplete && simulation.tickCount < DifficultyModel.maximumFrames {
            _ = simulation.tick()
        }
        let status = simulation.isComplete ? (simulation.didWin ? "passive-win" : "passive-loss") : "timeout"
        var score: Double?
        if simulation.didWin, let id = level.id {
            let replay = NxrpReplay(metadata: NxrpMetadata(levelID: id,
                levelVersion: level.version ?? 0, expectedCompletionFrame: simulation.tickCount), commands: [])
            let identity = LevelCatalogueIdentity(engine: .classic,
                packID: url.deletingLastPathComponent().lastPathComponent, levelID: path)
            let key = DifficultyCacheKey(identity: identity, levelRevision: digest(data),
                replayRevision: digest(try encoder.encode(replay)), assetsRevision: digest(Data(rendered.solidMask)))
            let profile = try NeoLemmixDifficultyAnalysis.analyse(level: level, rendered: rendered,
                replay: replay, key: key, maximumProbeRuns: 0)
            score = profile.overallScore
            profiles.append(profile)
        }
        try record(Result(path: path, status: status, ticks: simulation.tickCount,
                          saved: simulation.savedCount, required: level.saveRequirement,
                          score: score, features: [], issue: nil), count: index + 1)
    } catch {
        try record(Result(path: path, status: "error", ticks: nil, saved: nil,
                          required: nil, score: nil, features: [], issue: String(describing: error)), count: index + 1)
    }
}
let counts = Dictionary(grouping: results, by: \.status).mapValues(\.count)
print("Evaluated \(results.count): \(counts)")
