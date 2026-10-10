import AppKit
import NxlvKit

@MainActor enum ProgressionMenu {
    static func policies(onSelect: @escaping (ProgressionPolicy) -> Void) -> GameMenuPage {
        let page = GameMenuPage(title: "Progression", subtitle: "Estimated solution burden")
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        for (index, policy) in ProgressionPolicy.allCases.enumerated() {
            let button = page.addListAction(policy.name, at: index) { onSelect(policy) }
            if index == 0 { page.preferControllerControl(button) }
        }
        return page
    }
}
