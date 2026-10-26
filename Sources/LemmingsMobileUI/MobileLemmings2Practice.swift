#if os(iOS) || os(tvOS)
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MobileLibraryViewController {
    func showOriginalMovies() {
        let engine = library is Lemmings3MobileLibrary ? "lemmings3" : "lemmings2"
        guard let directory = store?.resolvedDataDirectory(for: engine == "lemmings2" ? .lemmings2 : .lemmings3) else { return }
        let player = MobileOriginalMediaController(engine: engine, directory: directory)
        player.onClose = { MobileMusic.shared.resume() }
        present(player, animated: false)
    }

    func l2PracticePage(subtitle: String) -> GameFrontEnd.Page {
        MobileSequelMenuArt.practice(choice: practiceChoice, skills: practiceSkills, subtitle: subtitle)
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
                let directory = source.directory, storage = learningStorage
                let choice = practiceChoice, skills = practiceSkills
                previewLoader = MobileMenuPreviewLoader {
                    let source = try Lemmings2MobileLibrary(directory: directory, storage: storage)
                    return try Lemmings2PracticeMobileLibrary(source: source, choice: choice, skills: skills)
                }
                levelsBackRoute = .l2Practice; selectedIndex = 0; selectedPreview = nil
                startLevel(0, checkpoint: nil)
            } catch { notice = error.localizedDescription; rebuild() }
        } else { return false }
        return true
    }
}
#endif
