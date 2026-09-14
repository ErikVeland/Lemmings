import NxlvKit

/// A solver candidate: a runtime snapshot and the recorded input that produced it.
struct Candidate: Sendable {
    var game: Lemmings2Runtime
    var cursor: Lemmings2InputCursor
    var inputs: [Lemmings2ReplayWitness.Input]
    var pointers: [Lemmings2ReplayWitness.Pointer]
    var depth: Int
    var fingerprint: String
    var detector: DecisionDetector
    /// The decision this candidate stopped at, which names the lemmings it may act on.
    var decision: Decision?
}

/// Ranks candidates. The order compares saved lemmings, then lemmings not yet lost,
/// then distance to an exit, then input count, then the fingerprint as a fixed tie break.
struct Score: Comparable, Sendable {
    let saved: Int
    let remaining: Int
    let distance: Int
    let inputs: Int
    let fingerprint: String

    /// `a < b` means that `a` ranks below `b`.
    static func < (a: Score, b: Score) -> Bool {
        if a.saved != b.saved { return a.saved < b.saved }
        if a.remaining != b.remaining { return a.remaining < b.remaining }
        if a.distance != b.distance { return a.distance > b.distance }
        if a.inputs != b.inputs { return a.inputs > b.inputs }
        return a.fingerprint > b.fingerprint
    }
}

extension Score {
    init(_ candidate: Candidate) {
        let game = candidate.game
        let exits = game.configuration.exits
        func toExit(_ x: Int, _ y: Int) -> Int {
            exits.map { abs(x - ($0.x + $0.width / 2)) + abs(y - ($0.y + $0.height / 2)) }.min() ?? 0
        }
        let entrance = game.configuration.entrance
        // Lemmings not yet released count from the entrance, so releasing fewer gains no rank.
        let waiting = max(0, game.configuration.total - game.released)
        let active = game.lemmings.filter(\.active).reduce(0) { $0 + toExit($1.x, $1.y) }
        self.init(saved: game.saved, remaining: game.configuration.total - game.lost,
                  distance: active + waiting * toExit(entrance.x + entrance.width / 2, entrance.y + entrance.height / 2),
                  inputs: candidate.inputs.count, fingerprint: candidate.fingerprint)
    }
}

/// The state fingerprint omits the held pointer, which can move machines later,
/// so the merge key adds the last recorded pointer.
private func mergeKey(_ candidate: Candidate) -> String {
    let pointer = candidate.pointers.last.map { "\($0.x),\($0.y),\($0.fanX),\($0.fanY),\($0.fan)" } ?? "-"
    return candidate.fingerprint + "|" + pointer
}

/// Keeps the highest ranked candidate for each merge key, best first.
func mergeByFingerprint(_ candidates: [Candidate]) -> [Candidate] {
    var best: [String: (score: Score, candidate: Candidate)] = [:]
    for candidate in candidates {
        let key = mergeKey(candidate), score = Score(candidate)
        if let existing = best[key], !(existing.score < score) { continue }
        best[key] = (score, candidate)
    }
    // Sort by rank, then by key, because dictionary order changes between processes.
    return best.sorted {
        if $0.value.score != $1.value.score { return $1.value.score < $0.value.score }
        return $0.key < $1.key
    }.map { $0.value.candidate }
}
