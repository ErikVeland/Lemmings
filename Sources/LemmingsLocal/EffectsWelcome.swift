import AppKit

/// Offers the effects choice once, including on the first launch after an upgrade.
@MainActor final class EffectsWelcome {
    static let choiceKey = "HDEffectsChoiceV1"
    private let defaults: UserDefaults
    private var page: GameMenuPage?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func showIfNeeded(in window: NSWindow, onChoose: @escaping (Bool) -> Void) {
        guard !defaults.bool(forKey: Self.choiceKey), page == nil else { return }
        let page = GameMenuPage(title: "Choose your play style")
        page.setDetail("Modern defaults add HD effects, variable speed and hold-to-boost controls.\n\nPrefer original controls and effects? Choose Old school. Change this later in Settings > Gameplay.")
        page.backTitle = "Old school"
        let choose: (Bool) -> Void = { [weak self, weak page] enabled in
            guard let self, let page, self.page === page else { return }
            GameScreen.shared.dismiss(page)
            self.page = nil
            onChoose(enabled)
            self.defaults.set(true, forKey: Self.choiceKey)
        }
        page.onBack = { choose(false) }
        let hd = page.addPrimaryAction("Play with modern defaults") { choose(true) }
        hd.keyEquivalent = "\r"
        hd.toolTip = "Default: modern controls, variable speed, HD effects and pointer capture."
        self.page = page
        if !GameScreen.shared.present(page, owner: window) { self.page = nil }
    }
}
