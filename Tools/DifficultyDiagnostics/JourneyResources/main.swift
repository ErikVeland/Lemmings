import CryptoKit
import Foundation
import NxlvKit

// The offline loader does not read or update player progress.
@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { "journey-resource-audit." + key }
}
struct Input: Decodable { let entry: LevelPlaylistEntry; let official: Bool }
struct Visibility: Encodable {
    let slot: Int
    let effect: Int
    let visibleFraction: Double
}
struct Source: Encodable {
    let identity: LevelCatalogueIdentity
    let sourceRevision: String
    let levelDigest: String
    let population: Int
    let required: Int
    let releaseRate: Int
    let timeLimitTicks: Int
    let skills: [String: Int]
    let interactiveVisibility: [Visibility]?
}
let args = CommandLine.arguments
precondition(args.count == 4, "Usage: JourneyResources POOL BUNDLED_RESOURCES OUTPUT")
let rows = try JSONDecoder().decode([Input].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let resources = URL(fileURLWithPath: args[2]), ports = resources.appendingPathComponent("Ports")
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
var official: [LevelCatalogueIdentity: (ClassicLevel, String, URL, URL?)] = [:]
var seen = Set<String>()
for root in try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
    guard let set = try? ClassicDataSet.detect(directory: root), set.kind != .scanned,
          set.title != nil, seen.insert(set.identifierKey).inserted,
          let revision = FanLevelLibrary.classicSourceRevision(for: set.title, root: root) else { continue }
    for (index, item) in set.campaign.levels.enumerated() {
        official[.init(engine: .classic, packID: set.identifierKey,
            levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)")] = (item.level, revision, root, nil)
    }
}
if let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports),
   let revision = FanLevelLibrary.classicSourceRevision(for: set.title, root: ports) {
    for (index, item) in set.campaign.levels.enumerated() {
        official[.init(engine: .classic, packID: set.identifierKey,
            levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)")] = (item.level, revision, PortExclusivePack.artworkDirectory(for: item, portsRoot: ports), PortExclusivePack.fallbackArtworkDirectory(for: item, portsRoot: ports))
    }
}
let packs = Dictionary(uniqueKeysWithValues: FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).map {
    ("fan:" + FanLevelLibrary.catalogueID($0), $0)
})
var sources: [Source] = []
var grounds: [String: ClassicGroundSet] = [:]
func visibility(_ level: ClassicLevel, ground: ClassicGroundSet, special: ClassicSpecialGraphic?, fan: Bool = false) throws -> [Visibility] {
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
        objectSemantics: fan ? .forFanLevel(level, groundSet: ground) : .dos)
    return rendered.objects.filter { $0.placement.slot < rendered.interactiveObjectSlotLimit && [1, 4].contains($0.graphic.triggerEffect) }.map { object in
        let p = object.placement, g = object.graphic
        let frame = g.frames[min(max(0, g.firstFrameIndex), g.frames.count - 1)]
        var visible = 0, opaque = 0
        for y in 0..<g.height { for x in 0..<g.width {
            let sourceY = p.draw.isUpsideDown ? g.height - 1 - y : y
            guard frame[sourceY * g.width + x] & 0x80 == 0 else { continue }
            opaque += 1
            let dx = p.x + x, dy = p.y + y
            guard dx >= 0, dx < rendered.width, dy >= 0, dy < rendered.height else { continue }
            let solid = rendered.solidMask[dy * rendered.width + dx] != 0
            if p.draw.noOverwrite && solid || p.draw.onlyOverwrite && !solid { continue }
            visible += 1
        } }
        return Visibility(slot: p.slot, effect: g.triggerEffect,
            visibleFraction: Double(visible) / Double(max(1, opaque)))
    }
}
var failures: [String] = []
for row in rows {
    do {
        let id = row.entry.identity
        let level: ClassicLevel
        var interactiveVisibility: [Visibility]?
        if row.official {
            guard let pair = official[id], pair.1 == row.entry.sourceRevision else { throw LevelPlaylistError.invalidEntry }
            level = pair.0
            interactiveVisibility = try? {
                let cacheKey = pair.2.path + ":" + String(level.groundStyle)
                if grounds[cacheKey] == nil { grounds[cacheKey] = try ClassicGroundSet.load(style: level.groundStyle, from: pair.2, fallbackDirectory: pair.3) }
                let special = level.specialStyle == 0 ? nil : try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: pair.2, fallbackDirectory: pair.3)
                return try visibility(level, ground: grounds[cacheKey]!, special: special)
            }()
        } else {
            guard let pack = packs[id.packID], FanLevelLibrary.archiveFingerprint(pack) == row.entry.sourceRevision,
                  let split = id.levelID.lastIndex(of: "#"), let section = Int(id.levelID[id.levelID.index(after: split)...]) else {
                throw LevelPlaylistError.invalidEntry
            }
            let entry = FanLevelLibrary.Entry(file: String(id.levelID[..<split]), section: section < 0 ? nil : section, label: row.entry.levelNameSnapshot)
            let loaded = try FanLevelLibrary.level(entry, in: pack)
            level = loaded.0
            interactiveVisibility = try? visibility(level,
                ground: FanLevelLibrary.groundSet(for: level, styleName: loaded.1, portsRoot: ports, pack: pack, entry: entry),
                special: FanLevelLibrary.specialGraphic(for: level, entry: entry, pack: pack, portsRoot: ports), fan: true)
        }
        // Enum-keyed dictionaries encode as unordered arrays. Canonicalize skills
        // before hashing so two exports of the same level have the same digest.
        var canonical = try JSONSerialization.jsonObject(with: encoder.encode(level)) as! [String: Any]
        canonical["skills"] = Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) })
        let digest = SHA256.hash(data: try JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys]))
            .map { String(format: "%02x", $0) }.joined()
        sources.append(.init(identity: id, sourceRevision: row.entry.sourceRevision, levelDigest: digest,
            population: level.lemmingCount, required: level.saveRequirement, releaseRate: level.releaseRate,
            timeLimitTicks: level.timeLimitMinutes * 60 * ClassicDOSRules.ticksPerSecond,
            skills: Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) }), interactiveVisibility: interactiveVisibility))
    } catch { failures.append("\(row.entry.identity.packID)/\(row.entry.identity.levelID): \(error)") }
}
let output = URL(fileURLWithPath: args[3])
try encoder.encode(sources).write(to: output, options: .atomic)
try encoder.encode(failures).write(to: output.deletingLastPathComponent().appendingPathComponent("source-resource-failures.json"), options: .atomic)
print("Verified exact source resources for \(sources.count)/\(rows.count) levels; \(failures.count) unavailable.")
