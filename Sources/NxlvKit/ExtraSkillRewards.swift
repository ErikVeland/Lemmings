import Foundation

/// One extra use is earned for every ten distinct three-star levels without assists.
public struct ExtraSkillBalance: Equatable, Sendable {
    public static let threeStarLevelsPerReward = 10
    public let threeStarLevels: Int
    public let spent: Int

    public init(threeStarLevels: Int, spent: Int) {
        self.threeStarLevels = max(0, threeStarLevels)
        self.spent = max(0, spent)
    }

    public var earned: Int { threeStarLevels / Self.threeStarLevelsPerReward }
    public var available: Int { max(0, earned - spent) }
    public var threeStarLevelsToNext: Int {
        Self.threeStarLevelsPerReward - threeStarLevels % Self.threeStarLevelsPerReward
    }
}

/// Immutable spending evidence keeps retries and cloud merges from returning used rewards.
public struct ExtraSkillUse: Codable, Equatable, Sendable, Identifiable {
    public let attemptID: UUID
    public let skill: String
    public let originalConditions: TrolleyConditions
    public let existingLevelSkills: Set<String>
    public let startDate: Date?
    public let parentAttemptID: UUID?
    public let startKind: TrolleyStartKind?
    public var id: UUID { attemptID }
    public var conditions: TrolleyConditions? {
        originalConditions.addingBonusSkill(skill, existingLevelSkills: existingLevelSkills)
    }

    public init(attemptID: UUID, skill: String, originalConditions: TrolleyConditions,
                existingLevelSkills: Set<String> = [], start: TrolleyStart? = nil) {
        self.attemptID = attemptID
        self.skill = skill
        self.originalConditions = originalConditions
        self.existingLevelSkills = existingLevelSkills
        startDate = start?.date
        parentAttemptID = start?.parentAttemptID
        startKind = start?.kind
    }

    func originalStart(profileID: String) -> TrolleyStart {
        .init(id: attemptID, profileID: profileID, conditions: originalConditions,
            date: startDate ?? Date(timeIntervalSince1970: 0), parentAttemptID: parentAttemptID,
            kind: startKind ?? .fresh)
    }
}

extension TrolleyConditions {
    public static let bonusSkillModifier = "bonus-skill-v1"
    private static let bonusToolModifier = "bonus-original-tool-v1"
    private static let bonusToolSkills: Set<String> = ["bricks", "bomb", "spade", "shimmy", "sucker", "umbrella", "hadoken", "grenade", "swimmer"]

    public var bonusSkillID: String? { modifiers[Self.bonusSkillModifier] }

    /// Lemmings 3 supplies tools through pickups, so its engine supplies the original tool palette.
    public func addingBonusSkill(_ skill: String, existingLevelSkills: Set<String> = []) -> Self? {
        guard isValid, bonusSkillID == nil, !skill.isEmpty else { return nil }
        var stock = startingSkills
        var flags = modifiers
        if let original = stock[skill], original > 0, original < 1_000_000 {
            stock[skill] = original + 1
        } else if gameID == "lemmings3", stock.isEmpty, Self.bonusToolSkills.contains(skill), existingLevelSkills.contains(skill) {
            flags[Self.bonusToolModifier] = skill
        } else { return nil }
        flags[Self.bonusSkillModifier] = skill
        return .init(gameID: gameID, packID: packID, levelID: levelID, levelFingerprint: levelFingerprint,
            rulesetVersion: rulesetVersion, physicsMode: physicsMode, population: population,
            rescueRequirement: rescueRequirement, startingSkills: stock, timeLimitSeconds: timeLimitSeconds,
            modifiers: flags, rewindPolicy: rewindPolicy)
    }

    /// A stored start can change only by the single earned skill grant.
    func isBonusUpgrade(of original: Self) -> Bool {
        guard let skill = bonusSkillID else { return false }
        let tools: Set<String> = modifiers[Self.bonusToolModifier] == skill ? [skill] : []
        return original.addingBonusSkill(skill, existingLevelSkills: tools) == self
    }

    var hasValidBonusSkill: Bool {
        guard let skill = bonusSkillID else { return modifiers[Self.bonusToolModifier] == nil }
        guard !skill.isEmpty else { return false }
        if gameID == "lemmings3", startingSkills.isEmpty {
            return Self.bonusToolSkills.contains(skill) && modifiers[Self.bonusToolModifier] == skill
        }
        return modifiers[Self.bonusToolModifier] == nil && (startingSkills[skill] ?? 0) > 1
    }
}

extension ArcadeRun {
    public var usedBonusSkill: Bool { level.conditions?.bonusSkillID != nil }
    public var earnsConsumableRewards: Bool { qualifies && !assisted && !usedBonusSkill }
}

extension ArcadeLevel {
    public func addingBonusSkill(_ skill: String, existingLevelSkills: Set<String> = []) -> Self? {
        guard let bonus = conditions?.addingBonusSkill(skill, existingLevelSkills: existingLevelSkills) else { return nil }
        return .init(id: id, title: title, game: game, rules: rules, total: total, required: required, conditions: bonus)
    }
}

extension ArcadeRecords {
    func bonusSkillUseMatches(_ run: ArcadeRun) -> Bool {
        if let use = extraSkillUse(attemptID: run.id, profileID: run.profileID) {
            return use.conditions == run.level.conditions
        }
        return !run.usedBonusSkill && !extraSkillUses.values.joined().contains { $0.attemptID == run.id }
    }

    func extraSkillUsesAreValid() -> Bool {
        var ids = Set<UUID>()
        for (owner, uses) in extraSkillUses {
            guard profile(owner) != nil else { return false }
            for use in uses {
                guard ids.insert(use.attemptID).inserted, let conditions = use.conditions,
                      trolley.starts.contains(where: {
                          $0.id == use.attemptID && $0.profileID == owner && $0.conditions == conditions
                              && (use.startDate == nil || ($0.date == use.startDate && $0.parentAttemptID == use.parentAttemptID && $0.kind == use.startKind))
                      }),
                      trolley.attempts.filter({ $0.id == use.attemptID }).allSatisfy({ $0.run.profileID == owner && $0.run.level.conditions == conditions })
                else { return false }
            }
        }
        return runs.allSatisfy(bonusSkillUseMatches)
            && trolley.attempts.allSatisfy { bonusSkillUseMatches($0.run) }
            && trolley.starts.filter { $0.conditions.bonusSkillID != nil }.allSatisfy {
                extraSkillUse(attemptID: $0.id, profileID: $0.profileID)?.conditions == $0.conditions
            }
    }

    public func extraSkillUse(attemptID: UUID, profileID: String) -> ExtraSkillUse? {
        extraSkillUses[profileID]?.first { $0.attemptID == attemptID }
    }

    public func extraSkillSpent(attemptID: UUID, profileID: String) -> String? {
        extraSkillUse(attemptID: attemptID, profileID: profileID)?.skill
    }

    public func extraSkills(profileID: String) -> ExtraSkillBalance {
        let score = TrolleyCareerScore(profileID: profileID, attempts: trolley.attempts, assisted: false)
        return .init(threeStarLevels: score.threeStarLevels, spent: extraSkillUses[profileID]?.count ?? 0)
    }

    /// Restore a charge from a validated checkpoint before its records reach this device.
    /// Missing earnings remain a debt, so recovery cannot return the spent reward.
    @discardableResult public mutating func recoverExtraSkillUse(_ use: ExtraSkillUse, profileID: String) -> Bool {
        guard profile(profileID) != nil, let bonus = use.conditions else { return false }
        if let existing = extraSkillUse(attemptID: use.attemptID, profileID: profileID) { return existing == use }
        guard !extraSkillUses.values.joined().contains(where: { $0.attemptID == use.attemptID }),
              !runs.contains(where: { $0.id == use.attemptID }),
              !trolley.attempts.contains(where: { $0.id == use.attemptID }),
              upgradeTrolleyStartForBonusSkill(id: use.attemptID, profileID: profileID,
                original: use.originalConditions, bonus: bonus, originalStart: use.originalStart(profileID: profileID)) else { return false }
        extraSkillUses[profileID, default: []].append(use)
        return true
    }

    /// Spend before changing the simulation. A saved use is never returned by a retry or rewind.
    @discardableResult public mutating func spendExtraSkill(attemptID: UUID, profileID: String,
        skill: String, conditions: TrolleyConditions, existingLevelSkills: Set<String> = []) -> Bool {
        let start = trolley.starts.first { $0.id == attemptID }
            ?? TrolleyStart(id: attemptID, profileID: profileID, conditions: conditions)
        let use = ExtraSkillUse(attemptID: attemptID, skill: skill, originalConditions: conditions,
            existingLevelSkills: existingLevelSkills, start: start)
        guard profile(profileID) != nil, extraSkills(profileID: profileID).available > 0,
              !extraSkillUses.values.joined().contains(where: { $0.attemptID == attemptID }),
              !trolley.attempts.contains(where: { $0.id == attemptID }), use.conditions != nil else { return false }
        return recoverExtraSkillUse(use, profileID: profileID)
    }
}
