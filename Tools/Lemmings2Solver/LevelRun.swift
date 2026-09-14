import Foundation
import NxlvKit

enum SolverError: Error, CustomStringConvertible {
    case replayMismatch(String)
    var description: String {
        switch self {
        case let .replayMismatch(level): return "the written route does not replay to the solver's outcome on \(level)"
        }
    }
}

/// The result of one level search. Every route in it is a version 2 witness.
struct LevelResult: Sendable {
    enum Status: Sendable { case solved, unsolved }
    let status: Status
    let witness: Lemmings2ReplayWitness?
    let partial: Lemmings2ReplayWitness?
    /// The best winning route for each saved count, most saved first.
    let winners: [Lemmings2ReplayWitness]
    let summary: String
}

func witness(_ candidate: Candidate, level: Lemmings2Level, population: Int) -> Lemmings2ReplayWitness {
    Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population, expectedSaved: candidate.game.saved,
        expectedTicks: candidate.game.tick, events: candidate.applied)
}

/// Searches one level, optionally from a seed, and accepts the best route only after the written
/// file replays twice to the solver's outcome.
func solveLevel(level: Lemmings2Level, style: Lemmings2Style, masks: Lemmings2TerrainMasks, population: Int,
                seed: [Lemmings2TimedEvent], limits base: SearchLimits, depth: Int? = nil) throws -> LevelResult {
    let start = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
    var limits = base
    // Decision density on a run that follows the seed, or on a run without input. A dense level
    // points to detector tuning.
    let passive = decisionCount(start: start, seed: seed, limits: limits)
    let density = String(format: "%.1f", Double(passive.points) * 100 / Double(max(1, passive.ticks)))
    // Search from the seed. Each better route becomes the next seed while budget remains, because
    // one search explores changes near one seed line.
    let started = Date()
    var current = seed
    var best: Candidate?, bestPartial: Candidate?
    var winners: [Int: Candidate] = [:]
    var points = 0, fallback = 0, expanded = 0, rounds = 0
    while true {
        rounds += 1
        let line = decisionCount(start: start, seed: current, limits: limits)
        limits.maxDepth = depth ?? line.points + 40
        limits.budgetSeconds = base.budgetSeconds - Date().timeIntervalSince(started)
        guard limits.budgetSeconds > 0 else { break }
        let report = search(from: start, seed: current, bounds: AimBounds(level: level), limits: limits)
        points += report.decisionPoints; fallback += report.fallbackPoints; expanded += report.expanded
        for winner in report.winners where winners[winner.game.saved].map({ Score($0) < Score(winner) }) ?? true {
            winners[winner.game.saved] = winner
        }
        if let partial = report.bestPartial, bestPartial.map({ Score($0) < Score(partial) }) ?? true { bestPartial = partial }
        let improved = report.best.map { found in best.map { found.game.saved > $0.game.saved } ?? true } ?? false
        if let found = report.best, best.map({ Score($0) < Score(found) }) ?? true { best = found }
        if improved, let found = report.best, found.applied != current {
            // Search again from the better route at the same width.
            current = found.applied
            limits.beamWidth = base.beamWidth
        } else if report.seconds < limits.budgetSeconds, limits.beamWidth < 4096 {
            // The beam ran out before the budget. Search the same seed again with a wider beam.
            limits.beamWidth *= 2
        } else {
            break
        }
    }
    let summary = "density \(density) per 100 ticks, decision points \(points) (fallback \(fallback)), expanded \(expanded), \(rounds) rounds to beam \(limits.beamWidth), \(Int(Date().timeIntervalSince(started))) s"
    guard let best else {
        return LevelResult(status: .unsolved, witness: nil,
            partial: bestPartial.map { witness(finish($0), level: level, population: population) },
            winners: [], summary: summary)
    }
    let route = witness(best, level: level, population: population)
    let written = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: JSONEncoder().encode(route))
    let first = try written.run(level: level, style: style, masks: masks)
    let second = try written.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash, first.saved == best.game.saved, first.ticks == best.game.tick else {
        throw SolverError.replayMismatch(level.fingerprint)
    }
    return LevelResult(status: .solved, witness: route, partial: nil,
        winners: winners.keys.sorted(by: >).compactMap { winners[$0] }.map { witness($0, level: level, population: population) },
        summary: summary)
}
