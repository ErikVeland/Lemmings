import NxlvKit

/// A solver candidate: a runtime snapshot, the events that applied, and the seed events still to come.
struct Candidate: Sendable {
    var game: Lemmings2Runtime
    var cursor = Lemmings2EventCursor()
    /// Events that applied, then events still to come. The lenient cursor removes a refused event.
    var events: [Lemmings2TimedEvent]
    var depth = 0
    var fingerprint = ""
    var detector: DecisionDetector
    /// The decision this candidate stopped at, which names the lemmings it may act on.
    var decision: Decision?
    /// True while the candidate has only waited, so it still follows the seed unchanged.
    var onSeedLine = true

    init(game: Lemmings2Runtime, events: [Lemmings2TimedEvent] = [], detector: DecisionDetector = DecisionDetector()) {
        self.game = game
        self.events = events
        self.detector = detector
    }

    /// The events that have applied so far. A finished candidate's route is exactly this list.
    var applied: [Lemmings2TimedEvent] { Array(events.prefix(cursor.next)) }
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
        let field = DistanceFields.shared.field(for: game.configuration)
        func toExit(_ x: Int, _ y: Int) -> Int {
            let straight = exits.reduce(Int.max) { best, exit in
                let horizontal = abs(x - (exit.x + exit.width / 2))
                let vertical = abs(y - (exit.y + exit.height / 2))
                return min(best, horizontal + vertical)
            }
            return field.distance(x: x, y: y, fallback: straight)
        }
        let entrance = game.configuration.entrance
        // Lemmings not yet released count from the entrance, so releasing fewer gains no rank.
        let waiting = max(0, game.configuration.total - game.released)
        let active = game.lemmings.filter(\.active).reduce(0) { $0 + toExit($1.x, $1.y) }
        let chainPreparation = game.chains.reduce(0) { $0 + (67 - $1.amplitude) * 8 }
        self.init(saved: game.saved, remaining: game.configuration.total - game.lost,
                  distance: active + waiting * toExit(entrance.x + entrance.width / 2, entrance.y + entrance.height / 2) + chainPreparation,
                  inputs: candidate.cursor.next, fingerprint: candidate.fingerprint)
    }
}

/// The runtime fingerprint omits control state, so the merge key keeps the applied control
/// history. It also adds pending events, because two equal states with different seed events
/// still to come can end differently.
private func mergeKey(_ candidate: Candidate) -> String {
    let next = candidate.cursor.next
    var hash = StableHash()
    var fan: (x: Int, y: Int)?
    for control in candidate.events[..<next] {
        switch control.event {
        case .aim, .releasePointer, .machine, .chain:
            hash.add(control)
        case let .fan(x, y, active):
            if active {
                if fan?.x != x || fan?.y != y { hash.add(control) }
                fan = (x, y)
            } else if fan != nil {
                hash.add(control)
                fan = nil
            }
        case .assign, .nuke:
            break
        }
    }
    hash.add(candidate.events.count - next)
    for event in candidate.events[next...] { hash.add(event) }
    return candidate.fingerprint + "|" + String(hash.value, radix: 16)
}

/// FNV-1a over event fields. Swift's Hasher changes between processes, and the merge order must not.
struct StableHash {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325
    mutating func add(_ number: Int) {
        var bits = UInt64(bitPattern: Int64(number))
        for _ in 0..<8 {
            value = (value ^ (bits & 0xff)) &* 0x0000_0100_0000_01b3
            bits >>= 8
        }
    }
    mutating func add(_ timed: Lemmings2TimedEvent) {
        add(timed.tick)
        switch timed.event {
        case let .assign(skill, lemming): add(1); add(skill); add(lemming)
        case let .aim(x, y, held): add(2); add(x); add(y); add(held ? 1 : 0)
        case let .fan(x, y, active): add(3); add(x); add(y); add(active ? 1 : 0)
        case .releasePointer: add(4)
        case let .machine(x, y): add(5); add(x); add(y)
        case let .chain(x, y): add(6); add(x); add(y)
        case .nuke: add(7)
        }
    }
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
