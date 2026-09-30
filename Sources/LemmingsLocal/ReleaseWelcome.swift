import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.7.5"
    static let subtitle = "Better sound, clearer controls, reliable sessions"
    static let sections = [
        ("Music and spatial sound", "Modern centres drums and softens stereo in Adaptive DJ. Sounds follow the camera. HD nuke countdowns hollow out music and add restrained bass."),
        ("Home and Goal", "H centres Home; G centres Goal. In Lemmings 2, G selects Glider first when available. Press G again for Goal. Use / for hints and ? for controls."),
        ("Fresh sessions and selection", "New sessions start at the beginning. Earlier progress stays saved. Fan artwork matches its terrain. Choose None, Obvious or Modern selection in Gameplay.")
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
