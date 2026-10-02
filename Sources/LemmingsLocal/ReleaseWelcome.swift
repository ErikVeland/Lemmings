import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.7.8"
    static let subtitle = "Balanced cursor badges, a sharper nuke finish and more fan solutions"
    static let sections = [
        ("Balanced cursor badges", "Skill icons, the red X and the optional count now match in height at both 1x and 2x. Sprite padding no longer makes an icon look smaller."),
        ("A sharper nuke finish", "After the final pop, the music filter rapidly opens back up. The return continues through the explosion tails and results screen."),
        ("More fan solutions", "The ledger now records 2,305 Classic fan wins. Golems compatibility and the learning path improve. Lemmings 2 and 3 remain Preview.")
    ]
    private let defaults: UserDefaults
    private let build: Int
    private let version: String
    private var page: GameMenuPage?

    init(defaults: UserDefaults = .standard,
        build: Int = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ReleaseWelcome.notesVersion) {
        self.defaults = defaults; self.build = build; self.version = version
    }
    func showIfNeeded(in window: NSWindow, existingPlayer: Bool, completion: @escaping () -> Void) {
        guard existingPlayer, build > defaults.integer(forKey: Self.seenKey) else {
            defaults.set(max(build, defaults.integer(forKey: Self.seenKey)), forKey: Self.seenKey)
            completion(); return
        }
        show(in: window) { [weak self] in
            guard let self else { return }
            self.defaults.set(self.build, forKey: Self.seenKey)
            completion()
        }
    }
    func show(in window: NSWindow, completion: @escaping () -> Void = {}) {
        if let page, GameScreen.shared.contains(page) { GameScreen.shared.present(page, owner: window); return }
        let page = GameMenuPage(title: "What's new in \(version)", subtitle: Self.subtitle)
        let sections = Self.sections
        for (index, section) in sections.enumerated() {
            let y = CGFloat(344 - index * 108)
            let heading = GameLabel(labelWithString: section.0)
            heading.role = .heading; heading.frame = CGRect(x: 0, y: y + 62, width: 992, height: 28)
            let body = GameLabel(labelWithString: section.1)
            body.cell?.wraps = true; body.frame = CGRect(x: 0, y: y, width: 992, height: 58)
            // The body uses AppKit's unflipped coordinates.
            page.body.addSubview(heading); page.body.addSubview(body)
        }
        let close = { [weak self, weak page] in
            guard let self, let page else { return }
            GameScreen.shared.dismiss(page); self.page = nil; completion()
        }
        page.controllerBackButton.isHidden = true
        page.onBack = close
        page.addPrimaryAction("Continue", action: close)
        self.page = page
        GameScreen.shared.present(page, owner: window)
    }
}
