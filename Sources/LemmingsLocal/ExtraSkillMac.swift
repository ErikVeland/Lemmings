#if os(macOS)
import Foundation
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor enum ExtraSkillMac {
    struct Choice {
        let id: Int
        let title: String
    }

    @discardableResult static func choose(_ choices: [Choice], selected: Int? = nil,
        owner: NSWindow?, onDismiss: @escaping () -> Void = {}, apply: @escaping (Int) -> Void) -> GameMenuPage? {
        guard !choices.isEmpty else { return nil }
        let page = GameMenuPage(title: L10n.text("EXTRA SKILL"),
            subtitle: L10n.text("Bonus runs keep separate records and earn no rewards."))
        var selection = choices.first(where: { $0.id == selected })?.id ?? choices[0].id
        let scroll = NSScrollView(frame: page.body.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let list = NSView(frame: CGRect(x: 0, y: 0, width: 992, height: max(480, choices.count * 52)))
        var buttons: [ExtraSkillChoiceButton] = []
        for (index, choice) in choices.enumerated() {
            let button = ExtraSkillChoiceButton(title: "+1 " + choice.title, primary: false)
            button.setButtonType(.radio)
            button.frame = CGRect(x: 16, y: list.bounds.height - CGFloat(index + 1) * 52,
                width: 960, height: 44)
            button.state = choice.id == selection ? .on : .off
            button.setAccessibilityElement(true)
            button.setAccessibilityRole(.radioButton)
            button.setAccessibilityLabel(button.title)
            button.setAccessibilityValue(choice.id == selection ? 1 : 0)
            button.onPress = {
                selection = choice.id
                for (index, peer) in buttons.enumerated() {
                    let selected = choices[index].id == selection
                    peer.state = selected ? .on : .off
                    peer.setAccessibilityValue(selected ? 1 : 0); peer.needsDisplay = true
                }
            }
            list.addSubview(button); buttons.append(button)
        }
        scroll.documentView = list; page.body.addSubview(scroll)
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        let use = page.addPrimaryAction(L10n.text("Use extra skill")) { [weak page] in
            if let page { GameScreen.shared.dismiss(page) }
            apply(selection)
        }
        for button in [page.controllerBackButton, use] {
            button.setAccessibilityElement(true)
            button.setAccessibilityRole(.button)
            button.setAccessibilityLabel(button.title)
        }
        page.preferControllerControl(page.controllerBackButton)
        guard GameScreen.shared.present(page, owner: owner, focus: page.controllerBackButton, onDismiss: {
            buttons.forEach { $0.onPress = nil }
            onDismiss()
        }) else { buttons.forEach { $0.onPress = nil }; onDismiss(); return nil }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, list.bounds.height - scroll.contentSize.height)))
        return page
    }
    /// Spending stays with the attempt when its timeline moves before the grant.
    static func level(_ original: ArcadeLevel, attemptID: UUID, profileID: String) -> ArcadeLevel {
        guard let use = ArcadeStore.shared.records.extraSkillUse(attemptID: attemptID, profileID: profileID),
              let conditions = use.conditions,
              original.conditions == use.originalConditions || original.conditions == conditions else { return original }
        return ArcadeLevel(id: original.id, title: original.title, game: original.game, rules: original.rules,
            total: original.total, required: original.required, conditions: conditions)
    }

    static func restore(_ checkpoint: RunRecovery, level: ArcadeLevel?) throws {
        guard let use = checkpoint.extraSkillUse else { return }
        guard level?.conditions == use.originalConditions || level?.conditions == use.conditions else {
            throw RunRecoveryError.differentGame
        }
        guard ArcadeStore.shared.recoverExtraSkillUse(use, profileID: checkpoint.profileID) else {
            throw RunRecoveryError.invalid
        }
    }
}

@MainActor private final class ExtraSkillChoiceButton: GameActionButton {
    override func draw(_ dirtyRect: NSRect) {
        GameStoneButton.draw(bounds, selected: state == .on || isHighlighted, pixel: 1)
        GameControlText.draw(title, in: bounds.insetBy(dx: 12, dy: 2), enabled: isEnabled)
        if state == .on {
            GameStyle.accent.setFill()
            CGRect(x: 12, y: bounds.maxY - 5, width: bounds.width - 24, height: 2).fill()
        }
        GameControlText.focus(self)
    }
}
#endif
