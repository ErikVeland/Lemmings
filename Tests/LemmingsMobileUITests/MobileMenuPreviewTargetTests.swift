#if os(iOS) || os(tvOS)
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileMenuPreviewTargetTests {
    @Test func browserRequiresAPreparedPreviewForButtonAndCoverActivation() throws {
        let browser = MobileLevelBrowserView(frame: CGRect(x: 0, y: 0, width: 834, height: 549))
        browser.artworkLoadingEnabled = false
        let levels = [MobileLevelSummary(index: 7, rank: "Fun", number: 1, title: "First level"),
                      MobileLevelSummary(index: 12, rank: "Fun", number: 2, title: "Next level")]
        var played: [Int] = []
        browser.onPlay = { played.append($0) }
        browser.configure(levels: levels, selected: 7)
        browser.layoutIfNeeded()
        let play = try #require(browser.subviews.compactMap { $0 as? MobilePixelButton }.first { $0.isPrimary })
        let cover = try #require(browser.subviews.compactMap { $0 as? MobileCoverFlowView }.first)

        func expectUnavailable() {
            let before = played
            #expect(!play.isEnabled)
            #expect(!play.accessibilityActivate())
            #expect(!cover.accessibilityActivate())
            play.sendActions(for: .touchUpInside)
            #expect(played == before)
        }

        expectUnavailable()
        browser.canPlay = true
        #expect(play.isEnabled)
        #expect(play.accessibilityActivate())
        #expect(cover.accessibilityActivate())
        #expect(played == [7, 7])

        browser.isLoading = true
        expectUnavailable()
        browser.isLoading = false
        #expect(play.isEnabled)

        browser.canPlay = false
        browser.configure(levels: levels, selected: 12)
        browser.setPlayTitle("Resume")
        expectUnavailable()
        browser.canPlay = true
        #expect(play.isEnabled)
        #expect(play.accessibilityActivate())
        #expect(cover.accessibilityActivate())
        #expect(played == [7, 7, 12, 12])

        browser.canPlay = false
        expectUnavailable()
    }

    @Test func previewHitTargetsDispatchTheVisibleForwardActionAndRejectStaleTaps() throws {
        let canvas = MobileMenuCanvas()
        var actions: [String] = []
        canvas.onAction = { actions.append($0) }
        for size in [CGSize(width: 390, height: 700), .init(width: 465, height: 610),
                     .init(width: 589, height: 794), .init(width: 834, height: 549)] {
            for action in [GameFrontEnd.Action("play", "Play", primary: true),
                           .init("play", "Resume", primary: true), .init("0", "Ready", primary: true),
                           .init("0", "Retry", primary: true), .init("0", "Next level", primary: true)] {
                canvas.page = .init(title: "Level", footer: [.init("back", "Back"), action], preview: true)
                canvas.frame = CGRect(origin: .zero, size: canvas.size(width: size.width, minimumHeight: size.height))
                canvas.layoutIfNeeded()
                let button = try #require(canvas.subviews.first { $0.accessibilityIdentifier == "menu.preview.play" } as? UIButton)
                let point = CGPoint(x: button.frame.midX, y: button.frame.midY)
                #expect(canvas.hitTest(point, with: nil) === button)
                #expect(button.accessibilityLabel == action.title)
                button.sendActions(for: .gameActivation)
                #expect(actions.last == action.id)
                let count = actions.count
                canvas.page.footer[1].enabled = false
                button.sendActions(for: .gameActivation)
                #expect(actions.count == count)
                canvas.layoutIfNeeded()
                #expect(!button.isEnabled)
                canvas.page = .init(title: "Main menu")
                button.sendActions(for: .gameActivation)
                #expect(actions.count == count)
                canvas.layoutIfNeeded()
                #expect(button.isHidden)
            }
        }
    }
}
#endif
