import CryptoKit
import Foundation
import NxlvKit
@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}
struct Row: Decodable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let initialHash: String?
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources")
let ports = resources.appendingPathComponent("Ports")
let decoder = JSONDecoder()
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
var selected: [LevelCatalogueIdentity: Row] = [:]
for path in ["Artifacts/ClassicProgression/audit.json", "Artifacts/LearningJourney/fan-evidence.json"] {
    for row in try decoder.decode([Row].self, from: Data(contentsOf: root.appendingPathComponent(path))) {
        selected[row.entry.identity] = row
    }
}
let solutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf:
    root.appendingPathComponent("Artifacts/LearningJourney/candidate-solutions.json")))
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
var entries: [String: [FanLevelLibrary.Entry]] = [:]
var checked = 0
for row in selected.values.sorted(by: { $0.entry.identity.packID + $0.entry.identity.levelID < $1.entry.identity.packID + $1.entry.identity.levelID }) {
    let id = row.entry.identity
    guard let pack = packs[id.packID], let replay = solutions[row.profile.key.replayRevision], replay.expected?.didWin == true else { continue }
    if entries[id.packID] == nil { entries[id.packID] = try FanLevelLibrary.validatedEntries(in: pack) }
    guard let entry = entries[id.packID]?.first(where: { $0.file + "#\($0.section ?? -1)" == id.levelID }) else { fatalError("Missing selected level") }
    guard FanLevelLibrary.mechanics(for: pack, entry: entry) == .golems else { continue }
    precondition(FanLevelLibrary.archiveFingerprint(pack) == row.entry.sourceRevision)
    let digest = SHA256.hash(data: try encoder.encode(replay)).map { String(format: "%02x", $0) }.joined()
    precondition(row.profile.key.replayRevision.hasSuffix(digest))
    let (level, style) = try FanLevelLibrary.level(entry, in: pack)
    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: entry)
    let special = try FanLevelLibrary.specialGraphic(for: level, entry: entry, pack: pack, portsRoot: ports)
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
        objectSemantics: .forFanLevel(level, groundSet: ground))
    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
        mainDATAssets: assets, mechanics: .golems, clock: .golems)
    precondition(ClassicDOSReplayRecorder.stateHash(of: initial) == row.initialHash)
    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, tickLimit: 20_000)
    precondition(outcome.didWin && outcome == replay.expected)
    checked += 1
    print("PASS", id.packID, id.levelID, outcome.saved, outcome.ticks)
}
precondition(checked >= 148)
print("PASS", checked, "selected Golems wins, exact archive, replay digest, starting state and final outcome")
