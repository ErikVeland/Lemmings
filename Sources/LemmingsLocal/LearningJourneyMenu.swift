#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

@MainActor enum LearningJourneyMenu {
    static func hub(next: LearningJourney.Lesson?, solved: Int, total: Int, later: Int,
                    resume: Bool, play: @escaping () -> Void, revisit: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: LearningJourney.title, subtitle: next.map { "\($0.stage.rawValue) • \($0.focus)" } ?? L10n.text("Journey explored"))
        let status = "Solved \(solved)/\(total)" + (later > 0 ? L10n.text("   •   Later \(later)") : "")
        page.setDetail([next?.entry.levelNameSnapshot, status].compactMap { $0 }.joined(separator: "\n\n"))
        let primary = page.addPrimaryAction(next == nil ? L10n.text("Revisit") : resume ? L10n.text("Continue") : L10n.text("Let's play")) {
            if next == nil { revisit() } else { play() }
        }
        primary.isEnabled = next != nil || later > 0
        if next != nil, later > 0 { page.addSecondaryAction(L10n.text("Revisit (\(later))"), action: revisit) }
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        return page
    }

    static func pause(title: String, resume: @escaping () -> Void, hints: @escaping () -> Void,
                      later: @escaping () -> Void, leave: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: L10n.text("Take your time"), subtitle: title)
        page.addListAction(L10n.text("Hints"), at: 0, action: hints)
        page.addListAction(L10n.text("Try later"), at: 1, action: later)
        page.addListAction(L10n.text("Back to journey"), at: 2, action: leave)
        page.addPrimaryAction(L10n.text("Resume"), action: resume)
        page.onBack = resume
        return page
    }
}
#endif
