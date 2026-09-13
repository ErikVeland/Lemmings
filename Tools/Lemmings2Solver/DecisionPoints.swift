import NxlvKit

/// Why the solver may branch at the current tick.
enum DecisionTrigger: String, Sendable, Equatable {
    case wallAhead, edgeAhead, fallStart, turn, fallback

    /// Lower values come first when several lemmings fire on one tick.
    var priority: Int {
        switch self {
        case .wallAhead: return 0
        case .edgeAhead: return 1
        case .fallStart: return 2
        case .turn: return 3
        case .fallback: return 4
        }
    }
}

/// What the detector needs to know about one active lemming on one tick.
struct LemmingObservation: Sendable, Equatable {
    var id: Int
    var x: Int
    var y: Int
    var direction: Int
    var state: Lemmings2Runtime.State
    var wallAhead: Bool
    var edgeAhead: Bool
}

/// What the detector needs to know about one tick.
struct TickObservation: Sendable, Equatable {
    var tick: Int
    var lemmings: [LemmingObservation]
    /// The walking lemming nearest to an exit, which the fallback offers.
    var nearestToExit: Int?
}

extension TickObservation {
    /// Reads every active lemming. Wall and edge probes run only for walking lemmings.
    init(_ game: Lemmings2Runtime) {
        let exits = game.configuration.exits
        func distance(_ x: Int, _ y: Int) -> Int {
            exits.map { abs(x - ($0.x + $0.width / 2)) + abs(y - ($0.y + $0.height / 2)) }.min() ?? 0
        }
        var observed: [LemmingObservation] = []
        var nearest: (distance: Int, id: Int)?
        for lemming in game.lemmings where lemming.active {
            var wall = false, edge = false
            if lemming.state == .walking {
                let ahead = lemming.x + lemming.direction * 8
                wall = ((lemming.y - 8)...(lemming.y - 1)).contains(where: { game.isSolid(ahead, $0) })
                edge = !(lemming.y...(lemming.y + 4)).contains(where: { game.isSolid(ahead, $0) })
                let d = distance(lemming.x, lemming.y)
                if nearest.map({ (d, lemming.id) < ($0.distance, $0.id) }) ?? true { nearest = (d, lemming.id) }
            }
            observed.append(LemmingObservation(id: lemming.id, x: lemming.x, y: lemming.y, direction: lemming.direction,
                                               state: lemming.state, wallAhead: wall, edgeAhead: edge))
        }
        self.init(tick: game.tick, lemmings: observed, nearestToExit: nearest?.id)
    }
}

/// A tick where the solver may branch, and the lemmings it may give skills to.
struct Decision: Sendable, Equatable {
    let trigger: DecisionTrigger
    let lemmings: [Int]
}

/// Reports decision points keyed by location. A crowd that meets one wall fires one
/// decision, not one decision for each lemming.
struct DecisionDetector: Sendable {
    let cell: Int
    let refire: Int
    let fallback: Int
    private var lastDirection: [Int: Int] = [:]
    private var lastState: [Int: Lemmings2Runtime.State] = [:]
    private var lastFired: [String: Int] = [:]
    private var lastDecisionTick = 0

    init(cell: Int = 8, refire: Int = 150, fallback: Int = 150) {
        self.cell = cell
        self.refire = refire
        self.fallback = fallback
    }

    /// Claims a location key. Returns false when the key fired inside the re-fire window.
    private mutating func claim(_ trigger: DecisionTrigger, _ lemming: LemmingObservation, tick: Int) -> Bool {
        let key = "\(trigger.rawValue)|\(lemming.x / cell),\(lemming.y / cell),\(lemming.direction)"
        if let fired = lastFired[key], tick - fired < refire { return false }
        lastFired[key] = tick
        return true
    }

    mutating func update(_ observation: TickObservation) -> Decision? {
        var fired: [(trigger: DecisionTrigger, id: Int)] = []
        for lemming in observation.lemmings {
            let previousDirection = lastDirection[lemming.id]
            let previousState = lastState[lemming.id]
            lastDirection[lemming.id] = lemming.direction
            lastState[lemming.id] = lemming.state
            if previousState == .walking && lemming.state == .falling,
               claim(.fallStart, lemming, tick: observation.tick) {
                fired.append((.fallStart, lemming.id))
            }
            guard lemming.state == .walking else { continue }
            if let previousDirection, previousDirection != lemming.direction,
               claim(.turn, lemming, tick: observation.tick) {
                fired.append((.turn, lemming.id))
            }
            if lemming.wallAhead, claim(.wallAhead, lemming, tick: observation.tick) {
                fired.append((.wallAhead, lemming.id))
            }
            if lemming.edgeAhead, claim(.edgeAhead, lemming, tick: observation.tick) {
                fired.append((.edgeAhead, lemming.id))
            }
        }
        if fired.isEmpty {
            guard observation.tick - lastDecisionTick >= fallback else { return nil }
            lastDecisionTick = observation.tick
            return Decision(trigger: .fallback, lemmings: observation.nearestToExit.map { [$0] } ?? [])
        }
        lastDecisionTick = observation.tick
        let ordered = fired.sorted { ($0.trigger.priority, $0.id) < ($1.trigger.priority, $1.id) }
        var offered: [Int] = []
        for entry in ordered where !offered.contains(entry.id) {
            if offered.count == 3 { break }
            offered.append(entry.id)
        }
        return Decision(trigger: ordered[0].trigger, lemmings: offered)
    }
}
