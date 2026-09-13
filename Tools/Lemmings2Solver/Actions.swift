import NxlvKit

/// One move the solver can make at a decision point.
enum SolverAction: Sendable, Hashable {
    case wait
    case assign(slot: Int, lemming: Int)
    case aimedAssign(slot: Int, lemming: Int, x: Int, y: Int)
}

/// Pointer limits that the replay witness accepts.
struct AimBounds: Sendable, Equatable {
    let x: ClosedRange<Int>
    let y: ClosedRange<Int>

    init(x: ClosedRange<Int>, y: ClosedRange<Int>) {
        self.x = x
        self.y = y
    }

    init(level: Lemmings2Level) {
        x = level.minimumScreenX...(level.maximumScreenX + 319)
        y = level.minimumScreenY...(level.maximumScreenY + 159)
    }

    func clamp(x: Int, y: Int) -> (x: Int, y: Int) {
        (min(max(x, self.x.lowerBound), self.x.upperBound), min(max(y, self.y.lowerBound), self.y.upperBound))
    }
}

/// Skills whose assignment reads the aim point during the spike.
let aimedSkills: Set<Lemmings2Runtime.Skill> = [.roper]

/// Lists the actions at a decision point. Skills go to the given candidate lemmings,
/// never to the whole crowd. Wait is always first.
func actions(in game: Lemmings2Runtime, candidates: [Int], bounds: AimBounds) -> [SolverAction] {
    var result: [SolverAction] = [.wait]
    var added: Set<SolverAction> = [.wait]
    func add(_ action: SolverAction) {
        if added.insert(action).inserted { result.append(action) }
    }
    for id in candidates {
        guard let lemming = game.lemmings.first(where: { $0.id == id }) else { continue }
        for (slot, skill) in game.configuration.skills.enumerated() where game.canAssign(slot: slot, to: id) {
            if aimedSkills.contains(skill) {
                for direction in [-1, 1] {
                    for offset in [-48, -24, 0, 24, 48] {
                        let target = bounds.clamp(x: lemming.x + 64 * direction, y: lemming.y + offset)
                        add(.aimedAssign(slot: slot, lemming: id, x: target.x, y: target.y))
                    }
                }
            } else {
                add(.assign(slot: slot, lemming: id))
            }
        }
    }
    return result
}

/// The witness input that replays an action taken on `tick`.
func record(_ action: SolverAction, tick: Int, skills: [Lemmings2Runtime.Skill])
    -> (inputs: [Lemmings2ReplayWitness.Input], pointers: [Lemmings2ReplayWitness.Pointer]) {
    switch action {
    case .wait:
        return ([], [])
    case let .assign(slot, lemming):
        return ([.init(tick: tick, lemming: lemming, skill: skills[slot].rawValue)], [])
    case let .aimedAssign(slot, lemming, x, y):
        return ([.init(tick: tick, lemming: lemming, skill: skills[slot].rawValue)],
                [.init(tick: tick, x: x, y: y, fanX: x, fanY: y, fan: false)])
    }
}
