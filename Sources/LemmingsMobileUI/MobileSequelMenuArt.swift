import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

public enum MobileSequelMenuArt {
    public static func practice(choice: Int, skills selected: [Lemmings2Runtime.Skill], subtitle: String) -> GameFrontEnd.Page {
        let maps = Lemmings2Practice.tribes.enumerated().map { index, tribe in
            GameFrontEnd.Action("practiceMap.\(index)", Lemmings2Campaign.tribeNames[tribe], selected: choice == index)
        }
        let skills = Lemmings2Runtime.Skill.allCases.filter { $0 != .unused }.map { skill in
            let order = selected.firstIndex(of: skill)
            return GameFrontEnd.Action("practiceSkill.\(skill.rawValue)",
                (order.map { "\($0 + 1)  " } ?? "") + SkillVocabulary.title(skill.name),
                enabled: order != nil || selected.count < 8, selected: order != nil)
        }
        return .init(title: L10n.text("Practice"), subtitle: subtitle, rows: maps + skills,
            details: [L10n.text("\(selected.count) of 8 selected")],
            footer: [.init("practiceBack", L10n.text("Back")),
                     .init("practicePlay", L10n.text("Play"), enabled: selected.count == 8, primary: true)])
    }
    public static func movies(engine: String, failure: String? = nil) -> GameFrontEnd.Page {
        .init(title: L10n.text("Original movies"), subtitle: failure ?? "",
            rows: MobileOriginalMedia.Item.all(engine: engine).enumerated().map { .init("movie.\($0.offset)", $0.element.title) },
            footer: [.init("back", L10n.text("Back"))])
    }
    public static func movie(_ item: MobileOriginalMedia.Item, paused: Bool, finished: Bool, failure: String?) -> GameFrontEnd.Page {
        var footer: [GameFrontEnd.Action] = [.init("back", L10n.text("Back")),
            .init("pause", paused ? L10n.text("Play") : L10n.text("Pause"), enabled: !finished && failure == nil)]
        if item.needsContinue { footer.append(.init("continue", L10n.text("Continue"), enabled: !finished && failure == nil, primary: true)) }
        var page = GameFrontEnd.Page(title: item.title, subtitle: failure ?? (finished ? L10n.text("Movie ended") : ""), footer: footer, preview: true)
        page.previewFitsImage = true
        return page
    }
}
