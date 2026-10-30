#if os(macOS)
import AppKit
import LemmingsGameArt
#if canImport(NxlvKit)
import NxlvKit
#endif

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "2.3.1"
    static var subtitle: String { L10n.text("Your next level is ready.") }
    static var sections: [(String, String)] {
        [
            (L10n.text("Find your way back"), L10n.text("Start or resume your Journey from Home. Saved Hot Seats keep their players and turns, and a level preview opens the level you chose.")),
            (L10n.text("Play with clearer controls"), L10n.text("Joined stone controls bring skills, pause and replay into clearer groups. Back and Main menu stay in the bottom action row.")),
            (L10n.text("Keep the moment"), L10n.text("Classic rewind keeps recent moments close for shorter steps. Level scenes use less work outside the view while you play.")),
            (L10n.text("Compatibility"), L10n.text("macOS 12.3 or later, on Apple silicon and Intel. Classic and The Tribes are Complete; Chronicles and NeoLemmix remain Beta."))
        ]
    }
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
