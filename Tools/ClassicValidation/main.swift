import Foundation
import CryptoKit
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}
struct Row: Codable {
    let collection: String
    let source: String
    let title: String
    var initialHash: String? = nil
    var status = "unverified"
    var details: String? = nil
    var witness: String? = nil
}
let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write(Data("Usage: Audit RESOURCES OUTPUT FIXTURE_ROOT\n".utf8)); exit(2)
}
let resources = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let fixtureRoot = URL(fileURLWithPath: args[3])
let ports = resources.appendingPathComponent("Ports")
let original = ports.appendingPathComponent("lemmings_dos_1991-07-30")
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
var witnesses: [String: [(String, ClassicDOSReplay)]] = [:]
for folder in ["Tests/ClassicDOSCompletionTests/Fixtures", "Tests/ClassicFamilyCompletionTests/Fixtures"] {
    let directory = fixtureRoot.appendingPathComponent(folder)
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
        throw NSError(domain: "MissingFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: directory.path])
    }
    for url in enumerator.allObjects.compactMap({ $0 as? URL }).filter({ $0.pathExtension == "json" }).sorted(by: { $0.path < $1.path }) {
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: url))
        witnesses[replay.initialStateHash, default: []].append((url.path.replacingOccurrences(of: fixtureRoot.path + "/", with: ""), replay))
    }
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let destination = output.appendingPathComponent("levels.jsonl")
FileManager.default.createFile(atPath: destination.path, contents: nil)
let handle = try FileHandle(forWritingTo: destination)
var counts: [String: [String: Int]] = [:]
var groundCache: [String: ClassicGroundSet] = [:]
var assetCache: [String: ClassicMainDATAssets] = [:]
var specialCache: [String: ClassicSpecialGraphic] = [:]
@MainActor func audit(_ level: ClassicLevel, collection: String, source: String, directory: URL, fallback: URL? = nil, style: String? = nil, pack: URL? = nil, entry: FanLevelLibrary.Entry? = nil) {
    var row = Row(collection: collection, source: source, title: level.title)
    do {
        var groundDirectory = directory
        var groundIndex = level.groundStyle
        if let style {
            switch ClassicStyleResolver(portsRoot: ports).resolve(styleNamed: style) {
            case let .found(root, index), let .packSupplied(root, index): groundDirectory = root; groundIndex = index
            case .specialGraphic: break
            default: throw NSError(domain: "UnsupportedStyle", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unresolved named style: \(style)"])
            }
        }
        let groundKey = groundDirectory.path + ":\(groundIndex)"
        if collection == "fan" {
            // Audit the same deterministic asset selection used by the app.
            groundCache[groundKey] = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: entry)
        } else if groundCache[groundKey] == nil { groundCache[groundKey] = try ClassicGroundSet.load(style: groundIndex, from: groundDirectory, fallbackDirectory: fallback) }
        let assetDirectory = fallback ?? directory
        if assetCache[assetDirectory.path] == nil { assetCache[assetDirectory.path] = try ClassicMainDATAssets.load(from: assetDirectory) }
        let specialKey = (pack?.path ?? directory.path) + ":" + (entry?.file ?? "") + ":\(level.specialStyle)"
        if level.specialStyle != 0 && specialCache[specialKey] == nil {
            if let pack, let entry {
                specialCache[specialKey] = try FanLevelLibrary.specialGraphic(for: level, entry: entry, pack: pack, portsRoot: ports)
            } else { specialCache[specialKey] = try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory) }
        }
        let rendered = try ClassicLevelRenderer.render(level, groundSet: groundCache[groundKey]!, specialGraphic: level.specialStyle == 0 ? nil : specialCache[specialKey])
        let base = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assetCache[assetDirectory.path]!)
        let hash = ClassicDOSReplayRecorder.stateHash(of: base); row.initialHash = hash
        if let candidates = witnesses[hash] {
            var failures: [String] = []
            for (path, replay) in candidates {
                do {
                    let first = try ClassicDOSReplayPlayer.run(replay, simulation: base)
                    let second = try ClassicDOSReplayPlayer.run(replay, simulation: base)
                    guard first.didWin && first == second else { throw NSError(domain: "ReplayDidNotWin", code: 1) }
                    row.status = "winning-replay"; row.witness = path; break
                } catch { failures.append("\(path): \(error)") }
            }
            if row.witness == nil { row.status = "replay-failed"; row.details = failures.joined(separator: "\n") }
        } else {
            var simulation = base
            for _ in 0..<180 where !simulation.isComplete { _ = simulation.tick() }
            row.status = "rendered-and-smoke-tested-only"
            if simulation.isComplete && !simulation.didWin { row.details = "No-input run ends in failure; no winning route recorded." }
        }
    } catch { row.status = "load-or-render-failed"; row.details = String(describing: error) }
    counts[collection, default: [:]][row.status, default: 0] += 1
    try! handle.write(contentsOf: encoder.encode(row)); try! handle.write(contentsOf: Data([10]))
}
let official = ["lemmings_dos_1991-07-30", "oh_no_more_lemmings_dos-1991-11-14_2232", "xmas_dos_XmasLemmingsV1.9", "xmas_dos_XmasLemmingsV1.9a1", "holiday_native_1993", "holiday_native_1994"]
for folder in official {
    let directory = ports.appendingPathComponent(folder)
    let set = try ClassicDataSet.detect(directory: directory)
    for (index, entry) in set.campaign.levels.enumerated() { audit(entry.level, collection: set.title!.rawValue, source: "\(folder)/\(index)", directory: directory) }
    print("Audited \(folder): \(set.campaign.levels.count)"); fflush(stdout)
}
let converted = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports)
for (index, entry) in (converted?.campaign.levels ?? []).enumerated() {
    audit(entry.level, collection: "ohYesMoreLemmings", source: "conversion/\(index)", directory: PortExclusivePack.artworkDirectory(for: entry, portsRoot: ports), fallback: PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: ports))
}
var packs: [[String: String]] = []
let partCount = Int(ProcessInfo.processInfo.environment["CLASSIC_AUDIT_PARTS"] ?? "1") ?? 0
let part = Int(ProcessInfo.processInfo.environment["CLASSIC_AUDIT_PART"] ?? "0") ?? -1
guard (1...8).contains(partCount), (0..<partCount).contains(part) else { exit(2) }
for (index, pack) in FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")]).enumerated() {
    if index % partCount != part { continue }
    let entries = FanLevelLibrary.entries(in: pack)
    packs.append(["pack": pack.lastPathComponent, "sha256": SHA256.hash(data: try Data(contentsOf: pack)).description, "decodedLevels": String(entries.count)])
    for entry in entries {
        let source = pack.lastPathComponent + "/" + entry.file + "#\(entry.section ?? 0)"
        do {
            let (level, style) = try FanLevelLibrary.level(entry, in: pack)
            audit(level, collection: "fan", source: source, directory: original, style: style, pack: pack, entry: entry)
        } catch { throw error }
    }
    if index % 20 == 0 { print("Audited fan packs \(index + 1), levels \(counts["fan", default: [:]].values.reduce(0,+))"); fflush(stdout) }
    try encoder.encode(counts).write(to: output.appendingPathComponent("summary.json"), options: .atomic)
}
try encoder.encode(packs).write(to: output.appendingPathComponent("packs.json"), options: .atomic)
try encoder.encode(counts).write(to: output.appendingPathComponent("summary.json"), options: .atomic)
try handle.close()
print(String(data: try encoder.encode(counts), encoding: .utf8)!)
// Missing completion evidence is a failed corpus-completion gate, not a passing smoke test.
exit(counts.values.allSatisfy { $0.keys.allSatisfy { $0 == "winning-replay" } } ? 0 : 1)
