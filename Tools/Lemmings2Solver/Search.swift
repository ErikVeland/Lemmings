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
    var peakPendingCandidates = 0
    var seconds = 0.0
}

/// Runs a candidate through its events until the next decision point. Refused events are
/// removed. Returns nil when the level ends or the optional deadline expires.
func advance(_ candidate: inout Candidate, until deadline: Date? = nil) -> Decision? {
    while !candidate.game.isComplete {
        if let deadline, Date() >= deadline { return nil }
        var cursor = candidate.cursor
        _ = cursor.applyDroppingRefused(eventsAt: &candidate.game, events: &candidate.events)
        candidate.cursor = cursor
        candidate.game.step()
        if let decision = candidate.detector.update(TickObservation(candidate.game)) { return decision }
    }
    return nil
}

/// Runs a candidate without further decisions, stopping at the optional deadline.
func finish(_ candidate: Candidate, until deadline: Date? = nil) -> Candidate {
    var tail = candidate
    while advance(&tail, until: deadline) != nil {}
    return tail
}

/// Counts the decision points on a run that follows the seed without changes.
func decisionCount(start: Lemmings2Runtime, seed: [Lemmings2TimedEvent], limits: SearchLimits,
                   until deadline: Date? = nil) -> (points: Int, ticks: Int) {
    var run = Candidate(game: start, events: seed, detector: DecisionDetector(cell: limits.cell, refire: limits.refire))
    var points = 0
    while advance(&run, until: deadline) != nil { points += 1 }
    return (points, run.game.tick)
}

/// Searches for the crowd route that saves the most lemmings. A seed's events follow every change.
func search(from start: Lemmings2Runtime, seed: [Lemmings2TimedEvent] = [], bounds: AimBounds,
            limits: SearchLimits) -> SearchReport {
    let started = Date()
    let deadline = started.addingTimeInterval(limits.budgetSeconds)
    var report = SearchReport()
    var winners: [Int: Candidate] = [:]
    func elapsed() -> Double { Date().timeIntervalSince(started) }
    func timeExpired() -> Bool { Date() >= deadline }
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
    let firstDecision = advance(&root, until: deadline)
    settle(&root, firstDecision)
    consider(root)
    if !root.game.isComplete {
        // The unchanged seed is a result in its own right.
        var tail = finish(root, until: deadline)
        settle(&tail, nil)
        consider(tail)
    }
    var beam = root.game.isComplete ? [] : [root]
    let pendingCandidateLimit = max(1, limits.beamWidth) * 2

    search: while !beam.isEmpty && !timeExpired() {
        var next: [Candidate] = []
        var seedLineFallback: Candidate?
        for node in beam {
            if timeExpired() { break search }
            if node.depth >= limits.maxDepth {
                var tail = finish(node, until: deadline)
                settle(&tail, nil)
                consider(tail)
                continue
            }
            let choices = actions(in: node.game, candidates: node.decision?.lemmings ?? [], bounds: bounds,
                                  pending: node.events, from: node.cursor.next)
            for action in choices {
                if timeExpired() { break search }
                var child = node
                apply(action, to: &child)
                if action != .wait { child.onSeedLine = false }
                child.depth += 1
                report.expanded += 1
                let decision = advance(&child, until: deadline)
                settle(&child, decision)
                consider(child)
                if timeExpired() { break search }
                if !child.game.isComplete {
                    if child.onSeedLine && seedLineFallback == nil { seedLineFallback = child }
                    next.append(child)
                    report.peakPendingCandidates = max(report.peakPendingCandidates, next.count)
                    if next.count >= pendingCandidateLimit {
                        next = Array(mergeByFingerprint(next).prefix(limits.beamWidth))
                    }
                }
            }
        }
        if timeExpired() { break }
        beam = Array(mergeByFingerprint(next).prefix(limits.beamWidth))
        // A seed line that scores no better than harmful variants would otherwise leave the beam
        // long before the decision point where one change improves it.
        if !beam.contains(where: \.onSeedLine), let line = seedLineFallback {
            if beam.count == limits.beamWidth { beam.removeLast() }
            beam.append(line)
        }
    }
    if let partial = report.bestPartial, !partial.game.isComplete {
        var tail = finish(partial, until: deadline)
        settle(&tail, nil)
        consider(tail)
    }
    report.winners = winners.keys.sorted(by: >).compactMap { winners[$0] }
    report.seconds = elapsed()
    return report
}
