#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

/// Shared result actions for Classic and both sequel journey engines.
@MainActor struct LearningJourneyResultActions {
    var prepareSkip: () throws -> Void
    var skip: () -> Void
    var later: () -> Void
    var hints: () -> Void
}

@MainActor enum LearningJourneyMenu {
    static func hub(next: LearningJourney.Lesson?, solved: Int, total: Int, later: Int,
                    resume: Bool, restoresCheckpoint: Bool = false, allCompleted: Int? = nil,
                    play: @escaping () -> Void, revisit: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: LearningJourney.title, subtitle: next.map { "\($0.stage.title) • \($0.interfaceFocus)" } ?? L10n.text("Journey explored"))
        let status = allCompleted.map { L10n.text("Completed levels \($0)") + "\n" }
            ?? ""
        let routeStatus = status + L10n.text("Current route \(solved)/\(total)")
            + (later > 0 ? L10n.text("   •   Later \(later)") : "")
        page.setDetail([next?.entry.levelNameSnapshot, routeStatus].compactMap { $0 }.joined(separator: "\n\n"))
        let primary = page.addPrimaryAction(next == nil ? L10n.text("Revisit") : restoresCheckpoint ? L10n.text("Resume") : resume ? L10n.text("Continue") : L10n.text("Start journey")) {
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
