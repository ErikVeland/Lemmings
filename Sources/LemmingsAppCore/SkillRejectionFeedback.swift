import NxlvKit

/**
 * Converts rejected skill assignments into messages for the shared game interface.
 */
public enum SkillRejectionFeedback {
    public enum MiningState: Sendable {
        case mining, falling
    }

    public static func classicOrNeoLemmix(_ reason: String, skill: String, miningState: MiningState? = nil) -> String {
        if let outcome = ClassicDOSAssignmentResult(rawValue: reason) {
            return classic(outcome, skill: skill, miningState: miningState)
        }
        if let outcome = NeoLemmixAssignmentRejection(rawValue: reason) {
            return neoLemmix(outcome, skill: skill, miningState: miningState)
        }
        return generalRejection
    }

    public static func classic(_ reason: ClassicDOSAssignmentResult, skill: String, miningState: MiningState? = nil) -> String {
        switch reason {
        case .assigned: return generalRejection
        case .noSuchLemming: return L10n.text("No lemming is selected.")
        case .inactiveLemming: return L10n.text("This lemming is no longer active.")
        case .noSkillRemaining: return noUsesRemain(skill)
        case .alreadyHasSkill: return alreadyHasSkill(skill)
        case .invalidAction: return invalidAction(skill, miningState: miningState)
        case .steel: return L10n.text("Steel blocks this skill.")
        case .wrongOneWayDirection: return L10n.text("The one-way wall blocks this direction.")
        case .overlappingBlockerField: return L10n.text("This blocker would overlap another blocker.")
        case .destructionMasksUnavailable: return L10n.text("The terrain data for this skill is unavailable.")
        }
    }

    public static func neoLemmix(_ reason: NeoLemmixAssignmentRejection, skill: String, miningState: MiningState? = nil) -> String {
        switch reason {
        case .unsupportedSkill: return L10n.text("This level does not support this skill.")
        case .noSuchLemming: return L10n.text("No lemming is selected.")
        case .removedLemming: return L10n.text("This lemming is no longer active.")
        case .cannotReceiveSkills: return generalRejection
        case .noSkillAvailable: return noUsesRemain(skill)
        case .invalidCurrentAction: return invalidAction(skill, miningState: miningState)
        case .duplicatePermanentSkill: return alreadyHasSkill(skill)
        case .conflictingPermanentSkill: return L10n.text("This skill conflicts with one the lemming already has.")
        case .blockedBySteelOrOneWay: return L10n.text("Steel or a one-way wall blocks this skill.")
        case .noCeiling: return L10n.text("This skill needs a ceiling within reach.")
        case .overlappingBlockerField: return L10n.text("This blocker would overlap another blocker.")
        }
    }

    public static func lemmings2(slot: Int, target: Int, in game: Lemmings2Runtime) -> String {
        guard let lemming = game.lemmings.first(where: { $0.id == target }) else {
            return L10n.text("No lemming is selected.")
        }
        guard lemming.active else { return L10n.text("This lemming is no longer active.") }
        guard !game.isComplete, !game.isNuking, game.configuration.skills.indices.contains(slot),
              game.supplies.indices.contains(slot) else { return generalRejection }
        let skill = game.configuration.skills[slot]
        guard skill != .unused else { return generalRejection }
        guard game.supplies[slot] > 0 else { return noUsesRemain(skill.name) }
        guard !Lemmings2SkillRules.permits(skill, during: lemming.state) else { return generalRejection }
        let miningState: MiningState? = switch lemming.state {
        case .mining: .mining
        case .falling: .falling
        default: nil
        }
        return invalidAction(skill.name, miningState: miningState)
    }

    public static func lemmings3(_ action: Lemmings3Runtime.Action, lemming: Lemmings3Runtime.Lemming,
                                 onSolidGround: Bool, direction: Lemmings3Runtime.Direction) -> String {
        guard lemming.active else { return L10n.text("This lemming is no longer active.") }
        if action == .walker && lemming.state == .swimming {
            return L10n.text("Turning while swimming needs two uses of Swimmer.")
        }
        guard onSolidGround else { return L10n.text("This lemming needs solid ground.") }
        if action == .blocker && lemming.state == .blocking {
            return L10n.text("This lemming is already blocking.")
        }
        if action == .use || action == .drop {
            guard let tool = lemming.tool else { return L10n.text("This lemming has no tool.") }
            if action == .use {
                guard lemming.quantity > 0 else { return L10n.text("This tool has no uses left.") }
                if tool == .bricks && direction == .down {
                    return L10n.text("Bricks cannot build straight down.")
                }
            }
        }
        return L10n.text("That lemming cannot use this action now.")
    }

    private static var generalRejection: String { L10n.text("This lemming cannot take this skill now.") }

    private static func invalidAction(_ skill: String, miningState: MiningState?) -> String {
        guard skill.lowercased() == "miner" else { return generalRejection }
        switch miningState {
        case .mining: return L10n.text("This lemming is already mining.")
        case .falling: return L10n.text("Wait for this lemming to land.")
        case nil: return generalRejection
        }
    }

    private static func noUsesRemain(_ skill: String) -> String {
        let skillName = SkillVocabulary.title(skill)
        return L10n.text("No uses of \(skillName) remain.")
    }

    private static func alreadyHasSkill(_ skill: String) -> String {
        let skillName = SkillVocabulary.title(skill)
        return L10n.text("This lemming already has \(skillName).")
    }
}
