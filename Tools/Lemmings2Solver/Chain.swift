import Foundation
import NxlvKit

/// One level of a tribe run.
struct ChainLevel: Codable, Sendable, Equatable {
    let number: Int
    let population: Int
    let saved: Int?
    let seedSource: String
    let seconds: Double
    /// True when the route came from backtracking, not from the level's best search result.
    var backtracked = false
}

/// The result of one tribe run, written to `.build/l2-solver/tribes/<tribe>.json`.
struct ChainReport: Codable, Sendable {
    let tribe: String
    var levels: [ChainLevel] = []
    /// The level where the chain broke, or nil when it reached level 10.
    var brokeAt: Int?
    /// True when level 10 saves the 30 lemmings that the ark ending needs.
    var arkReady = false
}

/// Solves levels 1 to 10 in order. Each level starts with the saved count of the chosen route
/// before it. When a level cannot pass, the solver retries it with the previous level's other
/// winning routes, most saved first, up to three, and backtracks one level only.
/// `accept` receives each chosen route, and receives a replacement when backtracking changes one.
func runChain(tribe: String, seedSource: (Int, Int) -> String = { _, _ in "" },
              solve: (Int, Int) throws -> LevelResult,
              accept: (Int, Lemmings2ReplayWitness, Bool) throws -> Void) rethrows -> ChainReport {
    var report = ChainReport(tribe: tribe)
    var population = 60
    var previous: LevelResult?
    for number in 1...10 {
        let started = Date()
        var result = try solve(number, population)
        if result.witness == nil, let before = previous, let chosen = report.levels.last {
            for alternative in before.winners.filter({ $0.expectedSaved != population }).prefix(3) {
                let retry = try solve(number, alternative.expectedSaved)
                guard retry.witness != nil else { continue }
                report.levels[report.levels.count - 1] = ChainLevel(number: chosen.number, population: chosen.population,
                    saved: alternative.expectedSaved, seedSource: chosen.seedSource, seconds: chosen.seconds, backtracked: true)
                try accept(number - 1, alternative, true)
                population = alternative.expectedSaved
                result = retry
                break
            }
        }
        report.levels.append(ChainLevel(number: number, population: population, saved: result.witness?.expectedSaved,
                                        seedSource: seedSource(number, population),
                                        seconds: Date().timeIntervalSince(started)))
        guard let route = result.witness else {
            report.brokeAt = number
            return report
        }
        try accept(number, route, false)
        population = route.expectedSaved
        previous = result
    }
    report.arkReady = population >= 30
    return report
}
