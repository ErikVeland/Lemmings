import CryptoKit
import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: AlternativeLogicSourceClock PROJECT_ROOT BUNDLED_RESOURCES")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = URL(fileURLWithPath: CommandLine.arguments[2])
let ports = resources.appendingPathComponent("Ports")
let pack = FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).first {
    "fan:" + FanLevelLibrary.catalogueID($0) == "fan:lldb-554"
}!
let file = "Lemmings Plus DOS Project - 10 - Danger (Part 1).dat"
let item = try FanLevelLibrary.validatedEntries(in: pack).first { $0.file == file && $0.section == 5 }!
let (level, style) = try FanLevelLibrary.level(item, in: pack)
let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
    objectSemantics: .forFanLevel(level, groundSet: ground))
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets, clock: .golems)
let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
let decoder = JSONDecoder()
let source = try decoder.decode(ClassicDOSReplay.self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/DifficultyEvaluation/source-clock-candidates/alternative-logic.json")))
let replay = ClassicDOSReplay(rank: source.rank, number: source.number, title: source.title,
    initialStateHash: hash, events: source.events)
let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
guard outcome.didWin, outcome.saved == 50, outcome.required == 50, outcome.ticks == 1022 else {
    fatalError("The source-clock candidate did not win on the exact bundled level")
}
let witness = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
    initialStateHash: hash, events: replay.events, expected: outcome)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let digest = SHA256.hash(data: try encoder.encode(witness)).description
let identity = LevelCatalogueIdentity(engine: .classic, packID: "fan:lldb-554", levelID: file + "#5")
let sourceRevision = FanLevelLibrary.archiveFingerprint(pack)!
guard sourceRevision == "bc6910d89e3d4625677d173dd9289ac64e19378a58c5ae9c2f2285875fdfeede" else {
    fatalError("Bundled archive revision changed")
}
let key = DifficultyCacheKey(identity: identity, levelRevision: sourceRevision,
    replayRevision: digest, assetsRevision: hash + ":probes-10",
    simulationVersion: DifficultyModel.simulationVersion + ":golems-clock-2")
let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: witness,
    key: key, maximumProbeRuns: 10)
let output = root.appendingPathComponent("Artifacts/DifficultyEvaluation/source-clock-candidates")
try encoder.encode(witness).write(to: output.appendingPathComponent("alternative-logic-replay.json"), options: .atomic)
try encoder.encode(profile).write(to: output.appendingPathComponent("alternative-logic-profile.json"), options: .atomic)
print("WIN", outcome.saved, outcome.required, outcome.ticks, "HASH", hash,
    "REPLAY", digest, "SCORE", profile.overallScore)
