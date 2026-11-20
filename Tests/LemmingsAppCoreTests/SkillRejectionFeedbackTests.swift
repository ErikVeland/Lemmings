import LemmingsAppCore
import NxlvKit
import Testing

struct SkillRejectionFeedbackTests {
    @Test func classicKeepsSteelAndOneWayRejectionsDistinct() {
        #expect(SkillRejectionFeedback.classic(.steel, skill: "miner", miningState: .falling)
            == L10n.text("Steel blocks this skill."))
        #expect(SkillRejectionFeedback.classic(.wrongOneWayDirection, skill: "miner")
            == L10n.text("The one-way wall blocks this direction."))
    }

    @Test func invalidMinerActionExplainsMiningAndFalling() {
        #expect(SkillRejectionFeedback.classic(.invalidAction, skill: "miner", miningState: .mining)
            == L10n.text("This lemming is already mining."))
        #expect(SkillRejectionFeedback.neoLemmix(.invalidCurrentAction, skill: "miner", miningState: .falling)
            == L10n.text("Wait for this lemming to land."))
    }

    @Test func rejectionCodesDoNotAppearInPlayerFeedback() {
        #expect(SkillRejectionFeedback.classicOrNeoLemmix("blockedBySteelOrOneWay", skill: "miner")
            == L10n.text("Steel or a one-way wall blocks this skill."))
        #expect(SkillRejectionFeedback.classicOrNeoLemmix("newEngineReason", skill: "miner")
            == L10n.text("This lemming cannot take this skill now."))
    }

    @Test func chroniclesExplainsWhyAnAirborneLemmingCannotBlock() throws {
        var game = try Lemmings3Runtime(configuration: .init(width: 64, height: 64,
            attributes: [UInt16](repeating: 0, count: 64 * 64), entrance: .init(x: 20, y: 12),
            exits: [.init(x: 56, y: 48)], total: 1, releaseInterval: 1, releaseDelay: 0))
        game.step()
        let lemming = try #require(game.lemmings.first)
        let accepted = game.assign(.blocker, to: lemming.id)
        #expect(!accepted)
        #expect(SkillRejectionFeedback.lemmings3(.blocker, lemming: lemming,
            onSolidGround: game.isSolid(lemming.x, lemming.y), direction: .right)
            == L10n.text("This lemming needs solid ground."))
    }
}
