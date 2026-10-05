import NxlvKit

/**
 * Selects the verified opening movie for a fresh Lemmings 3 title entry.
 */
struct Lemmings3StoryFlow: Sendable {
    let restoring: Bool
    let selectedLevel: Bool
    let recordsCampaignProgress: Bool
    let hotSeat: Bool

    var playsOpeningIntroduction: Bool {
        !restoring && !selectedLevel && recordsCampaignProgress && !hotSeat
    }

    static func playsEnding(afterLevel level: Int, finalLevel: Int, survivors: Int,
                            wasTribeCompleted: Bool, wasCampaignCompleted: Bool,
                            isCampaignCompleted: Bool) -> Bool {
        level == finalLevel
            && survivors >= Lemmings3ClassicCampaign.requiredTribeSurvivors
            && !wasTribeCompleted && !wasCampaignCompleted && isCampaignCompleted
    }
}
