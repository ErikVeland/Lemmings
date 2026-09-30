import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.7.4"
    static let subtitle = "Fresh sessions and correct fan artwork"
    static let sections = [
        ("New means new", "New solo and Hot Seat sessions start at the first level. Previous sessions stay saved. Profile achievements and scores are kept."),
        ("Correct fan terrain", "Fan levels use artwork that matches their terrain. Floating Down! now shows its snow landscape. The HUD shows the active journey position."),
        ("Choose your selection effect", "Settings > Gameplay offers None, Obvious and Modern. Modern adds a crisp white outline and subtle green bloom. The choice applies across all three games.")
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
