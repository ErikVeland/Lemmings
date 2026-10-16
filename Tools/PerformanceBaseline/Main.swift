import Foundation
import NxlvKit

struct CaseResult: Codable {
    let scenario: BaselineCase
    let samples: [TickSample]
    let allocationSample: TickSample
}

@main enum PerformanceMain {
    static func main() {
        do { try execute() }
        catch { fputs("ERROR: \(error)\n", stderr); exit(1) }
    }
    static func execute() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 4 else { throw Failure("Usage: baseline SOURCE ASSETS CASES OUTPUT [REPEATS] [FILTER]") }
        let source = URL(fileURLWithPath: args[0])
        let assets = URL(fileURLWithPath: args[1])
        let cases = try JSONDecoder().decode([BaselineCase].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
        let output = URL(fileURLWithPath: args[3])
        let repeats = args.count > 4 ? Int(args[4]) ?? 7 : 7
        guard repeats > 0, repeats <= 100 else { throw Failure("REPEATS must be 1...100") }
        guard allocationsSelftest() == 1 else { throw Failure("Allocation counter self-test must observe exactly one malloc") }
        var results: [CaseResult] = []
        for item in cases where args.count < 6 || item.id.contains(args[5]) || item.engine == args[5] {
            do {
                let run: (Bool) throws -> TickSample
                switch item.engine {
                case "classic":
                    let input = try ClassicInput(item, assets: assets); run = { try input.run(countAllocations: $0) }
                case "neo":
                    let input = try NeoInput(item, assets: assets); run = { try input.run(countAllocations: $0, stress: item.purpose == "scripted-nuke") }
                case "l2":
                    let input = try L2Input(item, source: source, assets: assets); run = { try input.run(countAllocations: $0) }
                case "l3":
                    let input = try L3Input(item, source: source, assets: assets); run = { try input.run(countAllocations: $0) }
                default: throw Failure("Unknown engine")
                }
                let warmup = try run(false)
                let batchRuns = max(1, min(1000, Int(ceil(0.1 / max(0.000001, warmup.wallSeconds)))))
                var samples: [TickSample] = []
                for _ in 0..<repeats {
                    let batch = try (0..<batchRuns).map { _ in try run(false) }
                    guard batch.allSatisfy({ $0.stateHash == warmup.stateHash && $0.ticks == warmup.ticks && $0.saved == warmup.saved }) else {
                        throw Failure("Batched runs diverged: \(item.id)")
                    }
                    var sample = TickSample(ticks: warmup.ticks,
                        wallSeconds: batch.reduce(0) { $0 + $1.wallSeconds } / Double(batchRuns),
                        cpuSeconds: batch.reduce(0) { $0 + $1.cpuSeconds } / Double(batchRuns), allocations: nil,
                        stateHash: warmup.stateHash, saved: warmup.saved, width: warmup.width,
                        height: warmup.height, population: warmup.population)
                    sample.recordedOutcomeMatches = warmup.recordedOutcomeMatches
                    sample.batchRuns = batchRuns
                    samples.append(sample)
                }
                let allocation = try run(true)
                guard (samples + [allocation]).allSatisfy({ $0.stateHash == warmup.stateHash && $0.ticks == warmup.ticks && $0.saved == warmup.saved }) else {
                    throw Failure("Repeated runs diverged: \(item.id)")
                }
                results.append(.init(scenario: item, samples: samples, allocationSample: allocation))
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(results).write(to: output, options: .atomic)
                print("REPEATABLE \(item.id): \(warmup.ticks) ticks, \(warmup.stateHash), recorded outcome matches: \(warmup.recordedOutcomeMatches)"); fflush(stdout)
            } catch {
                fputs("FAIL \(item.id): \(error)\n", stderr)
                throw error
            }
        }
        guard !results.isEmpty else { throw Failure("No matching cases") }
    }
}
