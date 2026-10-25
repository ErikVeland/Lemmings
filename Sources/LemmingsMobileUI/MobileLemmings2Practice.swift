#if os(iOS) || os(tvOS)
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MobileLibraryViewController {
    func l2PracticePage(subtitle: String) -> GameFrontEnd.Page {
        let maps = Lemmings2Practice.tribes.enumerated().map { index, tribe in
            GameFrontEnd.Action("practiceMap.\(index)", Lemmings2Campaign.tribeNames[tribe], selected: practiceChoice == index)
        }
        let skills = Lemmings2Runtime.Skill.allCases.filter { $0 != .unused }.map { skill in
            let order = practiceSkills.firstIndex(of: skill)
            return GameFrontEnd.Action("practiceSkill.\(skill.rawValue)",
                (order.map { "\($0 + 1)  " } ?? "") + SkillVocabulary.title(skill.name),
                enabled: order != nil || practiceSkills.count < 8, selected: order != nil)
        }
        return .init(title: L10n.text("Practice"), subtitle: subtitle,
            rows: maps + skills, details: [L10n.text("\(practiceSkills.count) of 8 selected")],
            footer: [.init("practiceBack", L10n.text("Back")),
                     .init("practicePlay", L10n.text("Play"), enabled: practiceSkills.count == 8, primary: true)])
    }
    func handleL2Practice(_ id: String) -> Bool {
        if id == "l2Practice" { navigate(.l2Practice) }
        else if id == "practiceBack" { handle("l2") }
        else if id.hasPrefix("practiceMap."), let choice = Int(id.dropFirst(12)), Lemmings2Practice.tribes.indices.contains(choice) {
            practiceChoice = choice; rebuild()
        } else if id.hasPrefix("practiceSkill."), let raw = Int(id.dropFirst(14)), let skill = Lemmings2Runtime.Skill(rawValue: raw), skill != .unused {
            if let index = practiceSkills.firstIndex(of: skill) { practiceSkills.remove(at: index) }
            else if practiceSkills.count < 8 { practiceSkills.append(skill) }
            rebuild()
        } else if id == "practicePlay", let source = (library as? Lemmings2MobileLibrary) ?? (library as? Lemmings2PracticeMobileLibrary)?.source {
            do {
                library = try Lemmings2PracticeMobileLibrary(source: source, choice: practiceChoice, skills: practiceSkills)
                levelsBackRoute = .l2Practice; selectedIndex = 0; selectedPreview = nil; previewLoader = nil
                startLevel(0, checkpoint: nil)
            } catch { notice = error.localizedDescription; rebuild() }
        } else { return false }
        return true
    }
}
#endif
