import NxlvKit

/// One move the solver can make at a decision point.
enum SolverAction: Sendable, Hashable {
    case wait
    case assign(slot: Int, lemming: Int)
    case aimedAssign(slot: Int, lemming: Int, x: Int, y: Int)
    /// Edits of the next pending seed assignment, by its index in the candidate's events.
    case retime(index: Int, tick: Int)
    case retarget(index: Int, lemming: Int)
    case drop(index: Int)
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

/// Skills whose assignment reads the aim point and that the solver branches on.
let aimedSkills: Set<Lemmings2Runtime.Skill> = [.roper]

/// Seed edits move an assignment by this many ticks.
let retimeStep = 8

/// Lists the actions at a decision point. Skills go to the given candidate lemmings,
/// never to the whole crowd. Wait is always first. When pending seed events follow,
/// the next pending assignment can also be moved, given to another offered lemming, or dropped.
func actions(in game: Lemmings2Runtime, candidates: [Int], bounds: AimBounds,
             pending events: [Lemmings2TimedEvent] = [], from next: Int = 0) -> [SolverAction] {
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
    let pendingAssign = events.indices.dropFirst(next).first { index in
        if case .assign = events[index].event { return true }
        return false
    }
    if let index = pendingAssign, case let .assign(_, lemming) = events[index].event {
        let tick = events[index].tick
        add(.retime(index: index, tick: tick + retimeStep))
        let earlier = max(game.tick, tick - retimeStep)
        if earlier != tick { add(.retime(index: index, tick: earlier)) }
        for id in candidates where id != lemming { add(.retarget(index: index, lemming: id)) }
        add(.drop(index: index))
    }
    return result
}

/// The events that an assignment action adds on `tick`.
func events(for action: SolverAction, tick: Int, skills: [Lemmings2Runtime.Skill]) -> [Lemmings2TimedEvent] {
    switch action {
    case let .assign(slot, lemming):
        return [.init(tick: tick, event: .assign(skill: skills[slot].rawValue, lemming: lemming))]
    case let .aimedAssign(slot, lemming, x, y):
        return [.init(tick: tick, event: .aim(x: x, y: y, held: true)),
                .init(tick: tick, event: .fan(x: x, y: y, active: false)),
                .init(tick: tick, event: .assign(skill: skills[slot].rawValue, lemming: lemming))]
    case .wait, .retime, .retarget, .drop:
        return []
    }
}

/// Applies an action at the candidate's current tick. New events go before the pending events
/// of that tick, so the rest of the seed follows the change.
func apply(_ action: SolverAction, to candidate: inout Candidate) {
    let next = candidate.cursor.next
    func insertSorted(_ event: Lemmings2TimedEvent) {
        let index = candidate.events.indices.dropFirst(next).first { candidate.events[$0].tick > event.tick }
            ?? candidate.events.count
        candidate.events.insert(event, at: index)
    }
    switch action {
    case .wait:
        break
    case .assign, .aimedAssign:
        candidate.events.insert(contentsOf: events(for: action, tick: candidate.game.tick,
                                                   skills: candidate.game.configuration.skills), at: next)
    case let .retime(index, tick):
        let old = candidate.events.remove(at: index)
        insertSorted(.init(tick: tick, event: old.event))
    case let .retarget(index, lemming):
        if case let .assign(skill, _) = candidate.events[index].event {
            candidate.events[index] = .init(tick: candidate.events[index].tick, event: .assign(skill: skill, lemming: lemming))
        }
    case let .drop(index):
        candidate.events.remove(at: index)
    }
}
