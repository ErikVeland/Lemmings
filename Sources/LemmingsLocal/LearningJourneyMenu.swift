import AppKit
import NxlvKit

enum LearningJourneyLibrary {
    struct Exclusion: Decodable { let identity: LevelCatalogueIdentity }
    static let excludedIdentities: Set<LevelCatalogueIdentity> = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Progression/exclusions.json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Exclusion].self, from: data) else { return [] }
        return Set(rows.map(\.identity))
    }()
    static let journey: LearningJourney? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Progression/learning.json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(LearningJourney.self, from: data),
              value.placementPolicy == LearningJourney.communityPlacementPolicy else { return nil }
        return try? value.excluding(excludedIdentities).validated()
    }()
}

@MainActor enum LearningJourneyMenu {
    static func hub(next: LearningJourney.Lesson?, solved: Int, total: Int, later: Int,
                    resume: Bool, play: @escaping () -> Void, revisit: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: LearningJourney.title, subtitle: next.map { "\($0.stage.rawValue) • \($0.focus)" } ?? "Journey explored")
        let status = "Solved \(solved)/\(total)" + (later > 0 ? "   •   Later \(later)" : "")
        page.setDetail([next?.entry.levelNameSnapshot, status].compactMap { $0 }.joined(separator: "\n\n"))
        let primary = page.addPrimaryAction(next == nil ? "Revisit" : resume ? "Continue" : "Let's play") {
            if next == nil { revisit() } else { play() }
        }
        primary.isEnabled = next != nil || later > 0
        if next != nil, later > 0 { page.addSecondaryAction("Revisit (\(later))", action: revisit) }
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        return page
    }

    static func pause(title: String, resume: @escaping () -> Void, hints: @escaping () -> Void,
                      later: @escaping () -> Void, leave: @escaping () -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: "Take your time", subtitle: title)
        page.addListAction("Hints", at: 0, action: hints)
        page.addListAction("Try later", at: 1, action: later)
        page.addListAction("Back to journey", at: 2, action: leave)
        page.addPrimaryAction("Resume", action: resume)
        page.onBack = resume
        return page
    }
}
