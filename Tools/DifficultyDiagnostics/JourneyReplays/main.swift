import Foundation
import CryptoKit
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { "journey-proof." + key }
}
struct Manifest: Decodable {
    struct Placement: Decodable { let replayRevision: String }
    struct Lesson: Decodable { let entry: LevelPlaylistEntry; let placement: Placement }
    let lessons: [Lesson]
}
struct Proof: Encodable {
    let identity: LevelCatalogueIdentity
    let title: String
    let sourceRevision: String
    let replayRevision: String
    let passed: Bool
    let detail: String
}
let args = CommandLine.arguments
precondition(args.count == 5, "Usage: JourneyReplays RESOURCES MANIFEST SOLUTIONS OUTPUT")
let resources = URL(fileURLWithPath: args[1]), ports = resources.appendingPathComponent("Ports")
let decoder = JSONDecoder()
let manifest = try decoder.decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let replays = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
var official: [LevelCatalogueIdentity: (ClassicLevel, String, URL, URL?, ClassicDOSMechanics)] = [:]
var seen = Set<String>()
var sets: [(ClassicDataSet, URL)] = []
for root in try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
    if let set = try? ClassicDataSet.detect(directory: root), set.kind != .scanned,
       set.title != nil, seen.insert(set.identifierKey).inserted { sets.append((set, root)) }
}
if let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) { sets.append((set, ports)) }
for (set, root) in sets {
    guard let revision = FanLevelLibrary.classicSourceRevision(for: set.title, root: root) else { continue }
    for (index, item) in set.campaign.levels.enumerated() {
        let art = set.title == .ohYesMoreLemmings ? PortExclusivePack.artworkDirectory(for: item, portsRoot: ports) : root
        let fallback = set.title == .ohYesMoreLemmings ? PortExclusivePack.fallbackArtworkDirectory(for: item, portsRoot: ports) : nil
        official[.init(engine: .classic, packID: set.identifierKey,
            levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)")] =
            (item.level, revision, art, fallback, ClassicDOSMechanics(title: set.title, rank: item.rank))
    }
}
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
var assets: [String: ClassicMainDATAssets] = [:]
var grounds: [String: ClassicGroundSet] = [:]
@MainActor func mainAssets(_ root: URL) throws -> ClassicMainDATAssets {
    if let found = assets[root.path] { return found }
    let value = try ClassicMainDATAssets.load(from: root); assets[root.path] = value; return value
}
var proofs: [Proof] = []
for lesson in manifest.lessons {
    let entry = lesson.entry, id = entry.identity
    do {
        let base: ClassicDOSSimulation
        if let (level, revision, art, fallback, mechanics) = official[id] {
            guard revision == entry.sourceRevision else { throw LevelPlaylistError.invalidEntry }
            let cacheKey = art.path + ":" + String(level.groundStyle)
            if grounds[cacheKey] == nil { grounds[cacheKey] = try ClassicGroundSet.load(style: level.groundStyle, from: art, fallbackDirectory: fallback) }
            let special = level.specialStyle == 0 ? nil : try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: art, fallbackDirectory: fallback)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: grounds[cacheKey]!, specialGraphic: special)
            base = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: mainAssets(fallback ?? art), mechanics: mechanics)
        } else {
            guard let pack = packs[id.packID], FanLevelLibrary.archiveFingerprint(pack) == entry.sourceRevision,
                  let split = id.levelID.lastIndex(of: "#"), let section = Int(id.levelID[id.levelID.index(after: split)...]) else { throw LevelPlaylistError.invalidEntry }
            let item = FanLevelLibrary.Entry(file: String(id.levelID[..<split]), section: section < 0 ? nil : section, label: entry.levelNameSnapshot)
            let loaded = try FanLevelLibrary.level(item, in: pack)
            let ground = try FanLevelLibrary.groundSet(for: loaded.0, styleName: loaded.1, portsRoot: ports, pack: pack, entry: item)
            let special = try FanLevelLibrary.specialGraphic(for: loaded.0, entry: item, pack: pack, portsRoot: ports)
            let rendered = try ClassicLevelRenderer.render(loaded.0, groundSet: ground, specialGraphic: special,
                objectSemantics: .forFanLevel(loaded.0, groundSet: ground))
            base = try ClassicDOSSimulation(level: loaded.0, renderedLevel: rendered,
                mainDATAssets: mainAssets(ports.appendingPathComponent("lemmings_dos_1991-07-30")),
                mechanics: FanLevelLibrary.mechanics(for: pack, entry: item), clock: .golems)
        }
        let hash = ClassicDOSReplayRecorder.stateHash(of: base)
        guard let replay = replays[hash], replay.sourceRules == nil else { throw LevelPlaylistError.invalidEntry }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let digest = SHA256.hash(data: try encoder.encode(replay)).map { String(format: "%02x", $0) }.joined()
        guard lesson.placement.replayRevision == digest || lesson.placement.replayRevision == "SHA256 digest: " + digest else {
            throw LevelPlaylistError.invalidEntry
        }
        let result = try ClassicDOSReplayPlayer.run(replay, simulation: base)
        guard result.didWin else { throw LevelPlaylistError.invalidEntry }
        proofs.append(.init(identity: id, title: entry.levelNameSnapshot, sourceRevision: entry.sourceRevision, replayRevision: lesson.placement.replayRevision, passed: true,
            detail: "\(result.saved)/\(result.required) saved at tick \(result.ticks); exact final state verified"))
    } catch {
        proofs.append(.init(identity: id, title: entry.levelNameSnapshot, sourceRevision: entry.sourceRevision, replayRevision: lesson.placement.replayRevision, passed: false, detail: String(describing: error)))
    }
    if proofs.count % 20 == 0 { print("Verified \(proofs.count)/\(manifest.lessons.count)"); fflush(stdout) }
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
try encoder.encode(proofs).write(to: URL(fileURLWithPath: args[4]), options: .atomic)
let failed = proofs.filter { !$0.passed }
for proof in failed { print("FAIL \(proof.title): \(proof.detail)") }
print("PASS \(proofs.count - failed.count)/\(proofs.count) exact journey replays")
exit(failed.isEmpty ? 0 : 1)
