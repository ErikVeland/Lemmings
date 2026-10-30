import CoreGraphics
import Testing
import LemmingsGameArt

struct LevelPreviewActionTests {
    @Test func previewsFollowTheExistingForwardActionAndItsDisabledState() {
        for action in [GameFrontEnd.Action("play", "Play"), .init("0", "Ready", primary: true),
                       .init("0", "Next level", primary: true), .init("0", "Retry", primary: true),
                       .init("recordPlay", "Play again", primary: true)] {
            var page = GameFrontEnd.Page(title: "Level", footer: [.init("back", "Back"), action], preview: true)
            #expect(page.previewAction == action)
            page.footer[1].enabled = false
            #expect(page.previewAction?.id == action.id && page.previewAction?.enabled == false)
            page.previewFitsImage = true
            #expect(page.previewAction == nil)
            page.previewFitsImage = false
            page.preview = false
            #expect(page.previewAction == nil)
        }
        let backOnly = GameFrontEnd.Page(title: "Unavailable", footer: [.init("back", "Back", primary: true)], preview: true)
        #expect(backOnly.previewAction == nil)
    }

    @Test func levelPreviewBoundsRemainSeparateFromItsNavigationTargets() {
        for size in [CGSize(width: 390, height: 700), .init(width: 465, height: 610),
                     .init(width: 589, height: 794), .init(width: 834, height: 549),
                     .init(width: 1194, height: 794), .init(width: 1920, height: 1080)] {
            let page = GameFrontEnd.Page(title: "Quad Quirks on the Quay!", subtitle: "Loading...",
                details: ["60 Lemmings   Save 1", "Time 9:00"],
                footer: [.init("back", "Back"), .init("play", "Play", enabled: false, primary: true)], preview: true)
            let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
            #expect(layout.preview.width >= 44 && layout.preview.height >= 44)
            #expect(CGRect(origin: .zero, size: layout.size).contains(layout.preview))
            for target in layout.targets {
                #expect(!target.frame.intersects(layout.preview))
            }
        }
    }
}
