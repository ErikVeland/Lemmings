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
guard (5...7).contains(arguments.count) else { fatalError("Usage: hint-export GAME_DATA TROLLEY_DIRECTORY OUTPUT_JSON ENGINE_FINGERPRINT [PORTS_DIRECTORY [SOLUTIONS_JSON]]") }
let directory = URL(fileURLWithPath: arguments[1]), proofs = URL(fileURLWithPath: arguments[2])
let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
let catalogue = try decoder.decode(TrolleyProofCatalogue.self, from: Data(contentsOf: proofs.appendingPathComponent("verified-maxima.json")))
let ports = arguments.count > 5 ? URL(fileURLWithPath: arguments[5]) : directory.deletingLastPathComponent()
let solutionsURL = arguments.count > 6 ? URL(fileURLWithPath: arguments[6])
    : URL(fileURLWithPath: arguments[3]).deletingLastPathComponent().appendingPathComponent("solutions.json")
let solutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: solutionsURL))
let campaigns: [(game: String, directory: URL)] = [
    ("lemmings", directory),
    ("ohNoMoreLemmings", ports.appendingPathComponent("oh_no_more_lemmings_dos-1991-11-14_2232")),
    ("xmasLemmings1991", ports.appendingPathComponent("xmas_dos_XmasLemmingsV1.9")),
    ("xmasLemmings1992", ports.appendingPathComponent("xmas_dos_XmasLemmingsV1.9a1")),
    ("holidayLemmings1993", ports.appendingPathComponent("holiday_native_1993")),
    ("holidayLemmings1994", ports.appendingPathComponent("holiday_native_1994")),
    ("ohYesMoreLemmings", ports)
]
var levels: [HintExport.Level] = []
var identities = Set<String>()
var originalCount = 0
var verifiedCount = 0
for (game, dataDirectory) in campaigns {
    let campaign: ClassicCampaign
    if game == "ohYesMoreLemmings" {
        guard let converted = try PortExclusivePack.dataSet(
            amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) else {
            throw HintError(message: "Missing conversion campaign")
        }
        campaign = converted.campaign
    } else {
        campaign = game == "lemmings"
            ? try ClassicCampaignDefinition.originalDOSLemmings.load(from: dataDirectory)
            : try ClassicDataSet.detect(directory: dataDirectory).campaign
    }
    try require(campaign.levels.count == ClassicTitle(rawValue: game)?.expectedLevelCount,
                "Incomplete hint campaign: \(game)")
    var assets: [URL: ClassicMainDATAssets] = [:]
    var grounds: [String: ClassicGroundSet] = [:], specials: [String: ClassicSpecialGraphic] = [:]
    for (index, entry) in campaign.levels.enumerated() {
        let level = entry.level
        let artwork = game == "ohYesMoreLemmings"
            ? PortExclusivePack.artworkDirectory(for: entry, portsRoot: ports) : dataDirectory
        let fallback = game == "ohYesMoreLemmings"
            ? PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: ports) : nil
        let assetRoot = fallback ?? artwork
        if assets[assetRoot] == nil { assets[assetRoot] = try ClassicMainDATAssets.load(from: assetRoot) }
        let groundKey = "\(artwork.path)|\(fallback?.path ?? "")|\(level.groundStyle)"
        let specialKey = "\(artwork.path)|\(level.specialStyle)"
        if grounds[groundKey] == nil {
            grounds[groundKey] = try ClassicGroundSet.load(style: level.groundStyle, from: artwork, fallbackDirectory: fallback)
        }
        if level.specialStyle != 0 && specials[specialKey] == nil {
            specials[specialKey] = try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: artwork)
        }
        let rendered = try ClassicLevelRenderer.render(level, groundSet: grounds[groundKey]!, specialGraphic: specials[specialKey])
        var sim = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets[assetRoot]!,
                                           mechanics: ClassicDOSMechanics(title: ClassicTitle(rawValue: game), rank: entry.rank))
        let identity = try fingerprint(sim)
        let replay: ClassicDOSReplay
        if game == "lemmings" {
            guard let proof = catalogue.levels.first(where: { $0.conditions?.gameID == game && $0.conditions?.levelID == "level-\(index)" }),
                  proof.conditions?.levelFingerprint == identity, let witness = proof.witness else {
                throw HintError(message: "No matching proof for \(entry.rank) \(entry.number)")
            }
            let bytes = try Data(contentsOf: proofs.appendingPathComponent(witness.path))
            try require(digest(bytes) == witness.sha256, "Witness digest mismatch")
            replay = try decoder.decode(ClassicDOSReplay.self, from: bytes)
        } else {
            guard let route = solutions[ClassicDOSReplayRecorder.stateHash(of: sim)] else {
                throw HintError(message: "Missing winning route for \(game) \(entry.rank) \(entry.number)")
            }
            replay = route
        }
        try require(replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: sim), "Initial state mismatch")
        try require(replay.events.allSatisfy { $0.tick >= ($0.afterTick == true ? 0 : 1) }, "Unsupported hint event timing")
        for event in replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                try require(sim.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)), "Cannot schedule skill")
            }
        }
        let grouped = Dictionary(grouping: replay.events.filter { $0.afterTick != true }, by: \.tick)
        let live = Dictionary(grouping: replay.events.filter { $0.afterTick == true }, by: \.tick)
        var moves: [HintExport.Move] = [], skillOrder: [String] = [], rates: [HintExport.Rate] = []
        func recordMove(id: Int, skill: ClassicSkill, actor: ClassicDOSLemming, tick: Int) {
            if !skillOrder.contains(skill.rawValue) { skillOrder.append(skill.rawValue) }
            if moves.count < 3 {
                moves.append(.init(skill: skill.rawValue, lemmingID: id, x: actor.foot.x, y: actor.foot.y,
                    tick: tick, facingLeft: actor.direction == .left))
            }
        }
        func applyLive(_ tick: Int) throws {
            for event in live[tick] ?? [] {
                switch event.action {
                case let .assign(id, skill):
                    try require(sim.assign(skill, to: id) == .assigned, "Rejected live skill")
                    guard let actor = sim.lemmings.first(where: { $0.id == id }) else { throw HintError(message: "Missing live worker") }
                    recordMove(id: id, skill: skill, actor: actor, tick: tick)
                case let .releaseRate(value): sim.setReleaseRate(value); rates.append(.init(tick: tick, value: value))
                case .nuke: sim.beginNuke()
                }
            }
        }
        try applyLive(0)
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
                    recordMove(id: id, skill: skill, actor: actor, tick: tick)
                }
            }
            try applyLive(tick)
        }
        let actual = ClassicDOSReplayOutcome(ticks: sim.tickCount, released: sim.releasedCount, saved: sim.savedCount,
            required: sim.configuration.requiredToSave, didWin: sim.didWin, stateHash: ClassicDOSReplayRecorder.stateHash(of: sim))
        try require(sim.isComplete && sim.didWin && replay.expected == actual, "Winning outcome changed for \(replay.title)")
        try require(replay.events.allSatisfy { $0.tick <= sim.tickCount }, "Unconsumed replay inputs")
        if game == "lemmings" { originalCount += 1 }
        verifiedCount += 1
        // Identical installed levels share one deck. Lookup rejects ambiguous identities.
        guard identities.insert(identity).inserted else { continue }
        // DOS permits assignments beyond the terrain canvas. Keep the full replay,
        // but omit markers that the hint map cannot place inside that canvas.
        let visibleMoves = moves.filter {
            $0.x >= 0 && $0.x < rendered.width && $0.y >= 0 && $0.y < rendered.height
        }
        levels.append(.init(fingerprint: identity, title: replay.title, rank: entry.rank, number: entry.number,
            width: rendered.width, height: rendered.height, opening: visibleMoves, skillOrder: skillOrder,
            rates: rates.filter { $0.tick <= (visibleMoves.last?.tick ?? 0) }))
        print("PASS \(game) \(entry.rank) \(entry.number): \(replay.title)")
    }
}
try require(originalCount == 120, "Incomplete original campaign")
try require(verifiedCount == 352, "Incomplete Classic and conversion hints")
let output = HintExport(schemaVersion: 1, engineFingerprint: arguments[4], levels: levels)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(output).write(to: URL(fileURLWithPath: arguments[3]), options: .atomic)
