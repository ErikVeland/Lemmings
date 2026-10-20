import Foundation
import NxlvKit

extension LeaderboardActionReplay {
    /// Verify a hosted command log before adapting it to the shared Classic replay player.
    public func classicReplay(initial: ClassicDOSSimulation, title: String) throws -> Data {
        guard engine == "classic" else { throw RunRecoveryError.differentGame }
        var checked = try checked(initial: .classic(initial))
        try checked.seek(to: ticks)
        guard case let .classic(final) = checked.state else { throw RunRecoveryError.differentGame }
        let events = try commands.map { command -> ClassicDOSReplayEvent in
            let action: ClassicDOSReplayAction
            switch command.action {
            case "assign":
                guard let lemming = command.lemming, let skill = command.skill,
                      ClassicSkill.allCases.indices.contains(skill) else { throw RunRecoveryError.invalid }
                action = .assign(lemmingID: lemming, skill: ClassicSkill.allCases[skill])
            case "rate":
                guard let value = command.value else { throw RunRecoveryError.invalid }
                action = .releaseRate(value)
            case "bonusSkill":
                guard let skill = command.skill, ClassicSkill.allCases.indices.contains(skill) else { throw RunRecoveryError.invalid }
                action = .bonusSkill(ClassicSkill.allCases[skill])
            case "nuke": action = .nuke
            default: throw RunRecoveryError.invalid
            }
            return .init(tick: command.tick, action: action, afterTick: true)
        }
        return try JSONEncoder().encode(ClassicDOSReplay(rank: "", number: 1, title: title,
            initialStateHash: initialStateHash,
            initialLevelFingerprint: initial.levelSourceFingerprint, events: events,
            expected: .init(ticks: ticks, released: final.releasedCount, saved: saved,
                            required: conditions.rescueRequirement, didWin: won, stateHash: finalStateHash)))
    }
}
