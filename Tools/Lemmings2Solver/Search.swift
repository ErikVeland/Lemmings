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
    var decisionPoints = 0
    var fallbackPoints = 0
    var expanded = 0
    var seconds = 0.0
}

/// Runs a candidate through its recorded input until the next decision point.
/// Returns nil when the level ends. Throws when a recorded input is rejected.
func advance(_ candidate: inout Candidate) throws -> Decision? {
    let inputs = candidate.inputs, pointers = candidate.pointers
    while !candidate.game.isComplete {
        var cursor = candidate.cursor
        try cursor.apply(inputsAt: &candidate.game, inputs: inputs, pointers: pointers)
        candidate.cursor = cursor
        candidate.game.step()
        let observation = TickObservation(candidate.game)
        if let decision = candidate.detector.update(observation) { return decision }
    }
    return nil
}

/// Runs a candidate to the end of the level without taking further decisions.
func finish(_ candidate: Candidate) -> Candidate {
    var tail = candidate
    while !tail.game.isComplete {
        do { _ = try advance(&tail) } catch { break }
    }
    return tail
}

/// Searches for the crowd route that saves the most lemmings.
func search(from start: Lemmings2Runtime, bounds: AimBounds, limits: SearchLimits) -> SearchReport {
    let started = Date()
    var report = SearchReport()
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
        if candidate.game.isComplete && candidate.game.didWin,
           report.best.map({ Score($0) < score }) ?? true {
            report.best = candidate
        }
        if report.bestPartial.map({ Score($0) < score }) ?? true { report.bestPartial = candidate }
    }

    var root = Candidate(game: start, cursor: Lemmings2InputCursor(), inputs: [], pointers: [],
                         depth: 0, fingerprint: "", detector: DecisionDetector(cell: limits.cell, refire: limits.refire),
                         decision: nil)
    let firstDecision = try? advance(&root)
    settle(&root, firstDecision)
    consider(root)
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
            for action in actions(in: node.game, candidates: node.decision?.lemmings ?? [], bounds: bounds) {
                var child = node
                let recorded = record(action, tick: child.game.tick, skills: child.game.configuration.skills)
                child.inputs += recorded.inputs
                child.pointers += recorded.pointers
                child.depth += 1
                report.expanded += 1
                let decision: Decision?
                do { decision = try advance(&child) } catch { continue }
                settle(&child, decision)
                consider(child)
                if !child.game.isComplete { next.append(child) }
            }
            if elapsed() >= limits.budgetSeconds { break }
        }
        beam = Array(mergeByFingerprint(next).prefix(limits.beamWidth))
    }
    report.seconds = elapsed()
    return report
}
