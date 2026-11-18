import Foundation
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { "CommunityPreviewTests." + key }
}

private struct Inventory: Decodable {
    struct Summary: Decodable {
        let includedPacks: Int
        let includedLevels: Int
    }
    struct Exclusion: Decodable {
        let archive: String
        let file: String
        let section: Int?
    }
    let summary: Summary
    let entryExclusions: [Exclusion]
}

private enum Failure: Error {
    case invalid(String)
}

private func require(_ condition: Bool, _ text: String) throws {
    if !condition { throw Failure.invalid(text) }
}

@main struct CommunityPreviewTests {
    static func main() {
        do {
            guard let resources = Bundle.main.resourceURL else { throw Failure.invalid("Missing test resources") }
            let root = resources.appendingPathComponent("LevelPacks")
            let inventory = try JSONDecoder().decode(Inventory.self,
                from: Data(contentsOf: root.appendingPathComponent("community-manifest.json")))
            let expected = try JSONDecoder().decode([String: Int].self,
                from: Data(contentsOf: root.appendingPathComponent("level-counts.json")))
            let packs = FanLevelLibrary.packs()
            try require(packs.count == inventory.summary.includedPacks, "The prepared community pack count changed")
            let ports = resources.appendingPathComponent("Ports")
            let original = ports.appendingPathComponent("lemmings_dos_1991-07-30")
            let main = try ClassicMainDATAssets.load(from: original)
            var checked = 0
            var failures: [String] = []
            for pack in packs {
                let entries = try FanLevelLibrary.validatedEntries(in: pack)
                try require(entries.count == expected[pack.lastPathComponent], "A filtered pack count changed: " + pack.lastPathComponent)
                for entry in entries {
                    do {
                        try autoreleasepool {
                            let (level, style) = try FanLevelLibrary.level(entry, in: pack)
                            let ground = try FanLevelLibrary.groundSet(for: level, styleName: style,
                                portsRoot: ports, pack: pack, entry: entry)
                            let special = try FanLevelLibrary.specialGraphic(
                                for: level, entry: entry, pack: pack, portsRoot: ports)
                            let scene = try ClassicLevelRenderer.render(level, groundSet: ground,
                                specialGraphic: special, objectSemantics: .forFanLevel(level, groundSet: ground))
                            var simulation = try ClassicDOSSimulation(level: level, renderedLevel: scene,
                                mainDATAssets: main, mechanics: FanLevelLibrary.mechanics(for: pack, entry: entry))
                            _ = simulation.tick()
                        }
                        checked += 1
                    } catch {
                        failures.append(pack.lastPathComponent + " | " + entry.file
                            + "#\(entry.section ?? -1) | \(error)")
                    }
                }
                if checked.isMultiple(of: 100) {
                    FileHandle.standardOutput.write(Data("CHECKED \(checked) community levels\n".utf8))
                }
            }
            try require(checked + failures.count == inventory.summary.includedLevels,
                        "The filtered community level total changed")
            for entry in inventory.entryExclusions {
                let pack = root.appendingPathComponent(entry.archive)
                if FileManager.default.fileExists(atPath: pack.path) {
                    do {
                        _ = try FanLevelLibrary.level(.init(file: entry.file, section: entry.section, label: "Excluded"), in: pack)
                    } catch { continue }
                    throw Failure.invalid("An excluded official copy can still load: " + entry.archive)
                }
            }
            let report: [String: Any] = [
                "packs": packs.count, "includedLevels": inventory.summary.includedLevels,
                "decodedRenderedAndStarted": checked, "failures": failures,
                "scope": "Load, render and one normal simulation tick. Not winning-route or fidelity proof."
            ]
            if let output = ProcessInfo.processInfo.environment["LEMMIX_CORPUS_REPORT"] {
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                    .write(to: URL(fileURLWithPath: output), options: .atomic)
            }
            if !failures.isEmpty {
                for failure in failures { print("FAIL " + failure) }
                throw Failure.invalid("\(failures.count) community levels did not load, render and start")
            }
            print("PASS \(packs.count) packs / \(checked) community levels decode, render and start; official-copy exclusions enforced")
        } catch {
            FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
            exit(1)
        }
    }
}
