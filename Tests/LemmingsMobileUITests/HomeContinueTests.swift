import Testing
import LemmingsGameArt

struct HomeContinueTests {
    private let resume: [GameFrontEnd.Action] = [.init("resume", "Resume level - EKV"),
                                                 .init("runResume", "Resume Favourites  2/5")]
    private let journey = GameFrontEnd.Action("journey", "Resume journey (4/120)")
    private let families: [GameFrontEnd.Action] = [.init("family.classic", "Classic Lemmings  0/120"),
                                                   .init("l2", "Lemmings 2", gameLogo: .lemmings2)]

    @Test func homeIsContinueThenFourDestinations() {
        let page = MobileHomeArt.page(continueAction: resume[0], initials: "EKV")
        #expect(page.rows.map(\.id) == ["resume"] + MobileHomeArt.destinationIDs)
        #expect(page.rows.filter(\.primary).map(\.id) == ["resume"])
        #expect(page.footer.map(\.id) == ["settings"])
    }

    @Test func withoutContinuePlayIsPrimary() {
        let page = MobileHomeArt.page(continueAction: nil, initials: "EKV")
        #expect(page.rows.map(\.id) == MobileHomeArt.destinationIDs)
        #expect(page.rows.filter(\.primary).map(\.id) == ["play"])
    }

    @Test func gamesAndCommunityCountersStayOffHome() {
        let page = MobileHomeArt.page(resume: resume, journey: journey, families: families, initials: "EKV")
        let ids = Set((page.rows + page.footer).map(\.id))
        #expect(ids.isDisjoint(with: families.map(\.id)))
        #expect(ids.isDisjoint(with: ["players", "records", "collections", "donate", "whatsNew", "deskClock"]))
    }

    @Test func hotSeatNamesTheNextPlayer() {
        let page = MobileHomeArt.page(continueAction: nil, hotSeatTurn: "UVA", initials: "EKV v UVA")
        #expect(page.rows.first { $0.id == "hotSeat" }?.title == "Hot Seat: UVA")
    }

    @Test func playKeepsEveryRouteAndGame() {
        let page = MobileHomeArt.playPage(journey: journey, resume: resume, families: families)
        #expect(page.rows.map(\.id) == ["journey", "resume", "runResume", "family.classic", "l2"])
        #expect(page.rows.filter(\.primary).map(\.id) == ["journey"])
        #expect(page.footer.map(\.id) == ["playBack", "collections"])
        #expect(page.backAction?.id == "playBack")
    }

    @Test func adapterPicksTheRequestedContinue() {
        let page = MobileHomeArt.page(resume: resume, journey: journey, continueID: "runResume", initials: "EKV")
        #expect(page.rows.first?.id == "runResume")
        let disabled = GameFrontEnd.Action("journey", "Start journey", enabled: false)
        let fallback = MobileHomeArt.page(resume: [], journey: disabled, continueID: "journey", initials: "EKV")
        #expect(fallback.rows.map(\.id) == MobileHomeArt.destinationIDs)
    }
}
