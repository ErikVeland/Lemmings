import Foundation

public enum SolutionReplayMode: String, CaseIterable, Sendable { case game, solution }

/// Move boundaries are successful assignments, including multiple uses at one tick.
public struct ReplayMoveNavigation: Equatable, Sendable {
    public let ticks: [Int]
    public init(ticks: [Int]) { self.ticks = Array(Set(ticks.filter { $0 >= 0 })).sorted() }
    public func target(from tick: Int, direction: Int) -> Int? {
        direction < 0 ? ticks.last(where: { $0 < tick }) : ticks.first(where: { $0 > tick })
    }

    public static func classic(initial: ClassicDOSSimulation, replay: ClassicDOSReplay) -> Self {
        var simulation = initial
        let events = Dictionary(grouping: replay.events, by: \.tick)
        var ticks: [Int] = []
        for event in replay.events where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                _ = simulation.schedule(.init(tick: event.tick, lemmingID: id, skill: skill))
            }
        }
        func apply(_ event: ClassicDOSReplayEvent) {
            switch event.action {
            case let .assign(id, skill):
                if simulation.assign(skill, to: id) == .assigned { ticks.append(simulation.tickCount) }
            case let .releaseRate(value): simulation.setReleaseRate(value)
            case .nuke: simulation.beginNuke()
            case let .bonusSkill(skill): _ = simulation.grantBonusSkill(skill)
            }
        }
        for event in events[simulation.tickCount] ?? [] where event.afterTick == true { apply(event) }
        let requestedEnd = replay.expected?.ticks ?? replay.events.map(\.tick).max() ?? initial.tickCount
        let limit = max(ClassicDOSReplayPlayer.defaultTickLimit, initial.configuration.timeLimitTicks ?? 0)
        let end = min(requestedEnd, initial.tickCount + limit)
        while simulation.tickCount < end, !simulation.isComplete {
            for event in events[simulation.tickCount + 1] ?? [] where event.afterTick != true {
                if case .assign = event.action {} else { apply(event) }
            }
            simulation.tick()
            if simulation.lastTickEvents.contains(where: { if case .skillAssigned = $0 { return true }; return false }) {
                ticks.append(simulation.tickCount)
            }
            for event in events[simulation.tickCount] ?? [] where event.afterTick == true { apply(event) }
        }
        return Self(ticks: ticks)
    }
}
