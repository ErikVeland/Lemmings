import Foundation
import NxlvKit

struct SearchLimits: Sendable {
    var beamWidth = 64
    var maxDepth = 40
    var budgetSeconds = 900.0
    var cell = 8
    var refire = 150
}

struct SearchReport: Sendable {
    var best: Candidate?
    var bestPartial: Candidate?
    /// The best winning candidate for each saved count, most saved first.
    var winners: [Candidate] = []
    var decisionPoints = 0
    var fallbackPoints = 0
    var expanded = 0
    var seconds = 0.0
}

/// Runs a candidate through its events until the next decision point. Refused events are
/// removed. Returns nil when the level ends.
func advance(_ candidate: inout Candidate) -> Decision? {
    while !candidate.game.isComplete {
        var cursor = candidate.cursor
        _ = cursor.applyDroppingRefused(eventsAt: &candidate.game, events: &candidate.events)
        candidate.cursor = cursor
        candidate.game.step()
        if let decision = candidate.detector.update(TickObservation(candidate.game)) { return decision }
    }
    return nil
}

/// Runs a candidate to the end of the level without taking further decisions.
func finish(_ candidate: Candidate) -> Candidate {
    var tail = candidate
    while advance(&tail) != nil {}
    return tail
}

/// Counts the decision points on a run that follows the seed without changes.
func decisionCount(start: Lemmings2Runtime, seed: [Lemmings2TimedEvent], limits: SearchLimits) -> (points: Int, ticks: Int) {
    var run = Candidate(game: start, events: seed, detector: DecisionDetector(cell: limits.cell, refire: limits.refire))
    var points = 0
    while advance(&run) != nil { points += 1 }
    return (points, run.game.tick)
}

/// Searches for the crowd route that saves the most lemmings. A seed's events follow every change.
func search(from start: Lemmings2Runtime, seed: [Lemmings2TimedEvent] = [], bounds: AimBounds,
            limits: SearchLimits) -> SearchReport {
    let started = Date()
    var report = SearchReport()
    var winners: [Int: Candidate] = [:]
    func elapsed() -> Double { Date().timeIntervalSince(started) }
    func settle(_ candidate: inout Candidate, _ decision: Decision?) {
        candidate.fingerprint = candidate.game.stateFingerprint
        candidate.decision = decision
        if let decision {
            report.decisionPoints += 1
            if decision.trigger == .fallback { report.fallbackPoints += 1 }
        }
    }
    func consider(_ candidate: Candidate) {
        let score = Score(candidate)
        if candidate.game.isComplete && candidate.game.didWin {
            if report.best.map({ Score($0) < score }) ?? true { report.best = candidate }
            if winners[candidate.game.saved].map({ Score($0) < score }) ?? true { winners[candidate.game.saved] = candidate }
        }
        if report.bestPartial.map({ Score($0) < score }) ?? true { report.bestPartial = candidate }
    }

    var root = Candidate(game: start, events: seed, detector: DecisionDetector(cell: limits.cell, refire: limits.refire))
    let firstDecision = advance(&root)
    settle(&root, firstDecision)
    consider(root)
    if !root.game.isComplete {
        // The unchanged seed is a result in its own right.
        var tail = finish(root)
        settle(&tail, nil)
        consider(tail)
    }
    var beam = root.game.isComplete ? [] : [root]

    while !beam.isEmpty {
        if elapsed() >= limits.budgetSeconds {
            if let top = beam.first {
                var tail = finish(top)
                settle(&tail, nil)
                consider(tail)
            }
            break
        }
        var next: [Candidate] = []
        for node in beam {
            if node.depth >= limits.maxDepth {
                var tail = finish(node)
                settle(&tail, nil)
                consider(tail)
                continue
            }
            let choices = actions(in: node.game, candidates: node.decision?.lemmings ?? [], bounds: bounds,
                                  pending: node.events, from: node.cursor.next)
            for action in choices {
                var child = node
                apply(action, to: &child)
                if action != .wait { child.onSeedLine = false }
                child.depth += 1
                report.expanded += 1
                let decision = advance(&child)
                settle(&child, decision)
                consider(child)
                if !child.game.isComplete { next.append(child) }
            }
            if elapsed() >= limits.budgetSeconds { break }
        }
        beam = Array(mergeByFingerprint(next).prefix(limits.beamWidth))
        // A seed line that scores no better than harmful variants would otherwise leave the beam
        // long before the decision point where one change improves it.
        if !beam.contains(where: \.onSeedLine), let line = next.first(where: \.onSeedLine) {
            if beam.count == limits.beamWidth { beam.removeLast() }
            beam.append(line)
        }
    }
    report.winners = winners.keys.sorted(by: >).compactMap { winners[$0] }
    report.seconds = elapsed()
    return report
}
