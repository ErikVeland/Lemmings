#if os(macOS)
import AppKit
#if canImport(NxlvKit)
import NxlvKit
#endif

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "2.1.2"
    static var subtitle: String { L10n.text("Shared progress, safer Resume and clearer controls") }
    static var sections: [(String, String)] { [
        (L10n.text("Journey"), L10n.text("Mac, iPhone, iPad and Apple TV share completed-level counts across campaign and Journey play. Home offers one Resume. Journey Map keeps browsing separate from starting an attempt.")),
        (L10n.text("Recovery"), L10n.text("New mobile Journey and playlist checkpoints retain their exact queue and position. Solo and Hot Seat sequel progress stay separate. First saves keep a backup, and future-version saves remain protected.")),
        (L10n.text("Clearer controls"), L10n.text("Mac wheel zoom is continuous and keeps the pointed terrain in place. Bonus Skill has a clearer name. Stone controls sit at the playfield corner with shared help and fade states.")),
        (L10n.text("Lemmings lettering"), L10n.text("Interface lettering uses a refined 2× display face. Start countdowns use hand-drawn 4× numerals across Classic, The Tribes and Chronicles on Mac, iOS and Apple TV.")),
        (L10n.text("Compatibility"), L10n.text("macOS 12.3 or later, on Apple silicon and Intel. Classic and The Tribes retain their Complete classifications. Chronicles and NeoLemmix remain Beta. Mobile Journey playback remains Classic-only. Existing engine and device validation limits still apply."))
    ] }
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
        let page = GameMenuPage(title: L10n.text("What's new in \(version)"), subtitle: Self.subtitle)
        let notes = AboutMarkdownView(markdown: Self.sections.map {
            "## " + $0.0 + "\n\n" + $0.1
        }.joined(separator: "\n\n"))
        notes.frame = page.body.bounds
        notes.autoresizingMask = [.width, .height]
        notes.scroll.setAccessibilityLabel(L10n.text("Release notes"))
        page.body.addSubview(notes)
        let close = { [weak self, weak page] in
            guard let self, let page else { return }
            GameScreen.shared.dismiss(page); self.page = nil; completion()
        }
        page.controllerBackButton.isHidden = true
        page.onBack = close
        page.addPrimaryAction(L10n.text("Continue"), action: close)
        self.page = page
        GameScreen.shared.present(page, owner: window)
    }
}
#endif
