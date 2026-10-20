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
    static let notesVersion = "2.1"
    static var subtitle: String { L10n.text("Comfortable play, original character") }
    static var sections: [(String, String)] { [
        (L10n.text("Comfortable play"), L10n.text("Basic 2× Zoom is free in Classic, The Tribes and Chronicles. Original and Modern presentation preserve your control preferences. Results keep detailed rewards in optional review.")),
        (L10n.text("Individual lemmings"), L10n.text("Pause to inspect names and recorded assignments. On Mac, hover over a lemming or press Command-I for its longer history. Character details have no effect on gameplay.")),
        (L10n.text("Extra skills"), L10n.text("Earn one Extra skill for every ten qualifying three-star clears. Use at most one per attempt. Bonus clears have separate records and cannot earn rewards or enter online rankings.")),
        (L10n.text("Short games and heritage"), L10n.text("Browse optional five-level Classic and The Tribes openings. About includes original-team and port credits. Missing exact hints are labelled General coaching.")),
        (L10n.text("Journey"), L10n.text("Journey Map and Resume keep your selected player, roster and turn. Solo and Hot Seat lesson progress stay separate. Shared handovers wait for Ready.")),
        (L10n.text("Smoother sync"), L10n.text("Cloud saves work in the background. Journey queues, fan completion and supported campaign progress sync with their owning session. Tester Sync shows whether saves are synced, waiting or offline.")),
        (L10n.text("Find your next level"), L10n.text("Start an official level from Play Insights. Normal level availability and campaign unlocks still apply.")),
        (L10n.text("Clearer controls"), L10n.text("Browse individual releases in About. Zoom and skip counters fade with the gameplay menu in Classic, The Tribes and Chronicles. Amiga Versus shows its two-controller requirement before play.")),
        (L10n.text("Earlier updates"), L10n.text("Original Macintosh 1-bit artwork, restored journeys and playlists, Classic solution ghosts, Hot Seat ghosts, controller stepping and safer count resets remain available. Find the full history in About > Version history.")),
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
