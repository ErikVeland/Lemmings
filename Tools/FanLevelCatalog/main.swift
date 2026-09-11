import Foundation

// This build tool reuses the game's decoder. It never records player progress.
@MainActor final class ArcadeStore {
  static let shared = ArcadeStore()
  func progressKey(_ key: String) -> String { key }
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let packs = FanLevelLibrary.packs(in: [folder])
var counts: [String: Int] = [:]
for pack in packs { counts[pack.lastPathComponent] = FanLevelLibrary.entries(in: pack).count }
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(counts)
try data.write(to: folder.appendingPathComponent("level-counts.json"), options: .atomic)
print("Indexed \(counts.values.reduce(0, +)) readable levels in \(packs.count) packs")
