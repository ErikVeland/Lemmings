#if os(tvOS)
import Testing
import UIKit
import LemmingsGameArt
@testable import LemmingsMobileUI

@MainActor private final class MenuSelectPress: UIPress {
    override var type: UIPress.PressType { .select }
}

@MainActor struct MobileTVSelectionTests {
    @Test func firstPlayerKeepsFocusWhenTheWorldwideCountArrives() throws {
        let canvas = MobileMenuCanvas(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        canvas.requiresNeutralActivation = true
        canvas.page = MobileCareerArt.firstPlayer(initials: "", portrait: 0, counter: "—", status: "", busy: false)
        canvas.layoutIfNeeded()
        let buttons = canvas.subviews.compactMap { $0 as? UIButton }
        let name = try #require(buttons.first { $0.accessibilityIdentifier == "menu.nameField" })
        let play = try #require(buttons.first { $0.accessibilityIdentifier == "menu.firstPlay" })
        #expect(!play.isEnabled)
        canvas.focusAction("nameField")
        canvas.page = MobileCareerArt.firstPlayer(initials: "TV", portrait: 2, counter: "123", status: "", busy: false)
        canvas.layoutIfNeeded()
        #expect(canvas.preferredFocusEnvironments.first === name)
        #expect(play.isEnabled)
        var selected: String?
        canvas.onAction = { selected = $0 }
        play.pressesBegan([MenuSelectPress()], with: nil)
        play.sendActions(for: .gameActivation)
        #expect(selected == "firstPlay")
    }

    @Test func menuStartsOnThePrimaryActionInsteadOfCancel() throws {
        let canvas = MobileMenuCanvas(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        canvas.page = GameFrontEnd.Page(title: "Confirm", footer: [
            .init("cancel", "Cancel"), .init("continue", "Continue", primary: true)
        ])
        canvas.layoutIfNeeded()
        let primary = try #require(canvas.subviews.compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "menu.continue" })
        #expect(canvas.preferredFocusEnvironments.first === primary)
    }

    @Test func nativeSelectActivatesReadyAfterRebuildWithoutProfilePolling() throws {
        let canvas = MobileMenuCanvas(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        canvas.requiresNeutralActivation = true
        let ready = GameFrontEnd.Page(title: "Ready", footer: [.init("ready", "Ready", primary: true)])
        canvas.page = ready
        canvas.layoutIfNeeded()
        var starts = 0
        canvas.onAction = { _ in starts += 1; canvas.page = ready }
        let button = try #require(canvas.subviews.compactMap { $0 as? MobileFocusButton }.first)
        button.sendActions(for: .gameActivation)
        #expect(starts == 0)
        button.pressesBegan([MenuSelectPress()], with: nil)
        button.sendActions(for: .gameActivation)
        #expect(starts == 1)
        // A release delivered to the next Ready page cannot start another turn.
        button.sendActions(for: .gameActivation)
        #expect(starts == 1)
        button.pressesBegan([MenuSelectPress()], with: nil)
        button.sendActions(for: .gameActivation)
        #expect(starts == 2)
        #expect(button.accessibilityActivate())
        #expect(starts == 3)
        button.isEnabled = false
        #expect(!button.accessibilityActivate())
        #expect(starts == 3)
    }

    @Test func nativeSelectAlsoArmsTheSolutionAndGhostTargets() throws {
        let selector = MobileSolutionSwitchView(frame: CGRect(x: 0, y: 0, width: 480, height: 168))
        selector.showsGhost = true; selector.isHidden = false
        selector.layoutIfNeeded()
        var switches = 0, ghosts = 0
        selector.onSelect = { _ in switches += 1; selector.resetActivation() }
        selector.onToggleGhost = { ghosts += 1; selector.resetActivation() }
        let buttons = selector.subviews.compactMap { $0 as? MobileFocusButton }
        #expect(buttons.count == 3)
        for (index, button) in buttons.enumerated() {
            button.sendActions(for: .gameActivation)
            #expect(switches + ghosts == index)
            button.pressesBegan([MenuSelectPress()], with: nil)
            button.sendActions(for: .gameActivation)
        }
        #expect(switches == 2 && ghosts == 1)
    }
}
#endif
