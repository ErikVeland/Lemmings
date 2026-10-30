#if os(iOS) || os(tvOS)
import Testing
import UIKit
import LemmingsGameArt
@testable import LemmingsMobileUI

@MainActor struct MobileMenuPreviewTargetTests {
    @Test func previewHitTargetsDispatchTheVisibleForwardActionAndRejectStaleTaps() throws {
        let canvas = MobileMenuCanvas()
        var actions: [String] = []
        canvas.onAction = { actions.append($0) }
        for size in [CGSize(width: 390, height: 700), .init(width: 465, height: 610),
                     .init(width: 589, height: 794), .init(width: 834, height: 549)] {
            for action in [GameFrontEnd.Action("play", "Play", primary: true),
                           .init("0", "Ready", primary: true), .init("0", "Next level", primary: true)] {
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
