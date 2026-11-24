import Testing
import LemmingsGameArt

struct HomeContinueTests {
    private let resume: [GameFrontEnd.Action] = [.init("resume", "Resume level - EKV"),
                                                 .init("runResume", "Resume Favourites  2/5")]
    private let journey = GameFrontEnd.Action("journey", "Resume journey (4/120)")
    private let families: [GameFrontEnd.Action] = [.init("family.classic", "Classic Lemmings  0/120")]

    @Test func continueLeadsAndIsTheOnlyPrimary() {
        let page = MobileHomeArt.page(resume: resume, journey: journey, families: families,
                                      continueID: "resume", initials: "EKV")
        #expect(page.rows.first?.id == "resume")
        #expect(page.rows.filter(\.primary).map(\.id) == ["resume"])
    }

    @Test func otherContinuationsStayReachable() {
        let page = MobileHomeArt.page(resume: resume, journey: journey, families: families,
                                      continueID: "runResume", initials: "EKV")
        #expect(page.rows.map(\.id) == ["runResume", "journey", "resume", "family.classic"])
    }

    @Test func missingOrDisabledContinueFallsBackToFirstEnabledRow() {
        let disabled = GameFrontEnd.Action("journey", "Start journey", enabled: false)
        let page = MobileHomeArt.page(resume: [], journey: disabled, families: families,
                                      continueID: "journey", initials: "EKV")
        #expect(page.rows.filter(\.primary).map(\.id) == ["family.classic"])
        let unknown = MobileHomeArt.page(resume: resume, journey: journey, families: families,
                                         continueID: "gone", initials: "EKV")
        #expect(unknown.rows.filter(\.primary).map(\.id) == ["journey"])
    }
}
