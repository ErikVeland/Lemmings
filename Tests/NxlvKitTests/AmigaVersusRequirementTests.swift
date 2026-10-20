import Testing
@testable import NxlvKit

struct AmigaVersusRequirementTests {
    @Test func bothAmigaVersusRanksRequireSimultaneousControllers() {
        for rank in ["Lemmings Versus", "Oh No! More Lemmings Versus"] {
            #expect(AmigaVersusCampaign.controllerRequirement(rank: rank) == "Two controllers required. Keep both connected at the same time.")
        }
        for rank in ["Fun", "Tricky", "Mega Drive Sunsoft", "Lemmings 2", "Lemmings 3"] {
            #expect(AmigaVersusCampaign.controllerRequirement(rank: rank) == nil)
        }
    }
}
