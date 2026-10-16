import Foundation
import NxlvKit

struct CorpusResult: Codable {
    let level: String
    let stateHash: String
    let ticks: Int
    let saved: Int
    let recordedOutcomeMatches: Bool
    var error: String? = nil
}

@main enum CorpusMain {
    static func main() {
        do { try execute() }
        catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
    }
    static func execute() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 4 else { throw Failure("Usage: corpus SOURCE ASSETS ENGINE OUTPUT") }
        let source = URL(fileURLWithPath: args[0]), assets = URL(fileURLWithPath: args[1])
        let engine = args[2], output = URL(fileURLWithPath: args[3])
        var items: [BaselineCase] = []
        if engine == "neo" {
            let root = assets.appendingPathComponent("neo/levels")
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
            items = files.compactMap { $0 as? URL }.filter { $0.pathExtension == "nxlv" }.map {
                let relative = String($0.path.dropFirst(root.path.count + 1))
                return BaselineCase(id: relative, engine: engine, purpose: "320-tick no-input continuation",
                    level: relative, replay: nil, initialHash: nil)
            }.sorted { $0.id < $1.id }
            guard items.count == 794 else { throw Failure("Expected 794 NeoLemmix levels") }
        } else {
            let folder = engine == "l2" ? "Tests/Lemmings2CompletionTests/Fixtures" : "Tests/Lemmings3CompletionTests/Fixtures"
            let files = try FileManager.default.contentsOfDirectory(at: source.appendingPathComponent(folder), includingPropertiesForKeys: nil)
            items = files.filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }.map {
                .init(id: $0.lastPathComponent, engine: engine, purpose: "recorded route",
                    level: $0.deletingPathExtension().lastPathComponent,
                    replay: folder + "/" + $0.lastPathComponent, initialHash: nil)
            }
            guard items.count == (engine == "l2" ? 120 : 90) else { throw Failure("Unexpected fixture count") }
        }
        var results: [CorpusResult] = []
        for item in items {
            do {
            let hash: String, ticks: Int, saved: Int, matches: Bool
            if engine == "neo" {
                let input = try NeoInput(item, assets: assets)
                var original = input.base
                original.run(ticks: 256)
                var restored = try JSONDecoder().decode(NeoLemmixSimulation.self, from: JSONEncoder().encode(original))
                for _ in 0..<64 where !original.isComplete {
                    let a = original.tick(), b = restored.tick()
                    guard a == b, original == restored else { throw Failure("Neo continuation differs: \(item.id)") }
                }
                hash = try canonical(original); ticks = original.tickCount; saved = original.savedCount; matches = true
            } else {
                let first: TickSample, second: TickSample
                if engine == "l2" {
                    let input = try L2Input(item, source: source, assets: assets)
                    first = try input.run(countAllocations: false); second = try input.run(countAllocations: false)
                } else {
                    let input = try L3Input(item, source: source, assets: assets)
                    first = try input.run(countAllocations: false); second = try input.run(countAllocations: false)
                }
                guard first.stateHash == second.stateHash, first.ticks == second.ticks, first.saved == second.saved else { throw Failure("Route differs: \(item.id)") }
                hash = first.stateHash; ticks = first.ticks; saved = first.saved
                matches = first.recordedOutcomeMatches
            }
            results.append(.init(level: item.level, stateHash: hash, ticks: ticks, saved: saved, recordedOutcomeMatches: matches))
            } catch {
                results.append(.init(level: item.level, stateHash: "", ticks: 0, saved: 0,
                    recordedOutcomeMatches: false, error: String(describing: error)))
                print("FAIL \(engine) \(item.level): \(error)"); fflush(stdout)
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(results).write(to: output, options: .atomic)
            if results.count.isMultiple(of: 25) || results.count == items.count {
                print("PASS \(engine) \(results.count)/\(items.count)"); fflush(stdout)
            }
        }
    }
}
