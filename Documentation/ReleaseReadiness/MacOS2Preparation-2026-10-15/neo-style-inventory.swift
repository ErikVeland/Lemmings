import Foundation
import NxlvKit
struct Missing: Codable { let pack: String; let level: String; let title: String; let styles: [String] }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let packs = try NeoLemmixPackLibrary.discover(in: root.appendingPathComponent("levels"))
let styles = Set(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("styles").path).map { $0.lowercased() })
var missing: [Missing] = []
for pack in packs {
    for level in pack.levels {
        guard let parsed = NxlvLevel(text: try String(contentsOf: level.url, encoding: .utf8)) else {
            throw NeoLemmixPackError.malformedLevel(level.relativePath)
        }
        let scan = parsed.scanStyleAssetReferences()
        let needed = Set(scan.references.map { $0.style.lowercased() }).subtracting(styles)
        if !needed.isEmpty { missing.append(.init(pack: pack.id, level: level.levelID, title: level.title, styles: needed.sorted())) }
    }
}
struct Report: Codable { let levelCount: Int; let missingStyleLevels: Int; let missing: [Missing]; let limitation: String }
let report = Report(levelCount: packs.reduce(0) { $0 + $1.levels.count }, missingStyleLevels: missing.count, missing: missing,
    limitation: "Checks native decoded style references against directories in the frozen content baseline. Does not prove rendering, mechanics, routes or distribution rights.")
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(report).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Native pack inventory: \(report.levelCount) levels, \(missing.count) levels with missing style directories")
