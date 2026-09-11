import CryptoKit
import Foundation
import NxlvKit

// Export locations only after the saved solution wins with its exact recorded outcome.
struct HintExport: Codable {
    struct Move: Codable {
        let skill: String, lemmingID: Int, x: Int, y: Int, tick: Int
        let facingLeft: Bool
    }
    struct Rate: Codable { let tick: Int, value: Int }
    struct Level: Codable {
        let fingerprint: String, title: String, rank: String
        let number: Int, width: Int, height: Int
        let opening: [Move], skillOrder: [String], rates: [Rate]
    }
    let schemaVersion: Int, engineFingerprint: String, levels: [Level]
}
struct HintError: Error { let message: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw HintError(message: message) }
}
func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
func fingerprint(_ sim: ClassicDOSSimulation) throws -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    var bytes = Data(ClassicDOSReplayRecorder.stateHash(of: sim).utf8)
    bytes.append(try encoder.encode(sim.configuration.entrances))
    bytes.append(try encoder.encode(sim.configuration.triggers))
    bytes.append(try encoder.encode(sim.comparisonDestructionMasks))
    return digest(bytes)
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else { fatalError("Usage: hint-export GAME_DATA TROLLEY_DIRECTORY OUTPUT_JSON") }
let directory = URL(fileURLWithPath: arguments[1]), proofs = URL(fileURLWithPath: arguments[2])
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let catalogue = try decoder.decode(TrolleyProofCatalogue.self, from: Data(contentsOf: proofs.appendingPathComponent("verified-maxima.json")))
let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
let assets = try ClassicMainDATAssets.load(from: directory)
var grounds: [Int: ClassicGroundSet] = [:], specials: [Int: ClassicSpecialGraphic] = [:]
var levels: [HintExport.Level] = []
for (index, entry) in campaign.levels.enumerated() {
    let level = entry.level
    if grounds[level.groundStyle] == nil { grounds[level.groundStyle] = try ClassicGroundSet.load(style: level.groundStyle, from: directory) }
    if level.specialStyle != 0 && specials[level.specialStyle] == nil {
        specials[level.specialStyle] = try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory)
    }
    let rendered = try ClassicLevelRenderer.render(level, groundSet: grounds[level.groundStyle]!, specialGraphic: specials[level.specialStyle])
    var sim = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
    let identity = try fingerprint(sim)
    guard let proof = catalogue.levels.first(where: { $0.conditions?.gameID == "lemmings" && $0.conditions?.levelID == "level-\(index)" }),
          proof.conditions?.levelFingerprint == identity, let witness = proof.witness else {
        throw HintError(message: "No matching proof for \(entry.rank) \(entry.number)")
    }
    let bytes = try Data(contentsOf: proofs.appendingPathComponent(witness.path))
    try require(digest(bytes) == witness.sha256, "Witness digest mismatch")
    let replay = try decoder.decode(ClassicDOSReplay.self, from: bytes)
    try require(replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: sim), "Initial state mismatch")
    for event in replay.events {
        if case let .assign(id, skill) = event.action {
            try require(sim.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)), "Cannot schedule skill")
        }
    }
    let grouped = Dictionary(grouping: replay.events, by: \.tick)
    var moves: [HintExport.Move] = [], skillOrder: [String] = [], rates: [HintExport.Rate] = []
    while !sim.isComplete && sim.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
        let tick = sim.tickCount + 1
        for event in grouped[tick] ?? [] {
            switch event.action {
            case let .releaseRate(value): sim.setReleaseRate(value); rates.append(.init(tick: tick, value: value))
            case .nuke: sim.beginNuke()
            case .assign: break
            }
        }
        var applied = sim.tick()
        for event in grouped[tick] ?? [] {
            if case let .assign(id, skill) = event.action {
                guard let appliedIndex = applied.firstIndex(of: .skillAssigned(lemmingID: id, skill: skill)),
                      let actor = sim.lemmings.first(where: { $0.id == id }) else { throw HintError(message: "Rejected skill") }
                applied.remove(at: appliedIndex)
                if !skillOrder.contains(skill.rawValue) { skillOrder.append(skill.rawValue) }
                if moves.count < 3 {
                    moves.append(.init(skill: skill.rawValue, lemmingID: id, x: actor.foot.x, y: actor.foot.y,
                                       tick: tick, facingLeft: actor.direction == .left))
                }
            }
        }
    }
    let actual = ClassicDOSReplayOutcome(ticks: sim.tickCount, released: sim.releasedCount, saved: sim.savedCount,
        required: sim.configuration.requiredToSave, didWin: sim.didWin, stateHash: ClassicDOSReplayRecorder.stateHash(of: sim))
    try require(sim.isComplete && sim.didWin && replay.expected == actual, "Winning outcome changed for \(replay.title)")
    levels.append(.init(fingerprint: identity, title: replay.title, rank: entry.rank, number: entry.number,
        width: rendered.width, height: rendered.height, opening: moves, skillOrder: skillOrder,
        rates: rates.filter { $0.tick <= (moves.last?.tick ?? 0) }))
    print("PASS \(entry.rank) \(entry.number): \(replay.title)")
}
try require(levels.count == 120, "Incomplete original campaign")
let output = HintExport(schemaVersion: 1, engineFingerprint: catalogue.engineSourceFingerprint, levels: levels)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(output).write(to: URL(fileURLWithPath: arguments[3]), options: .atomic)
