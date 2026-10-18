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
    static let notesVersion = "2.0.6"
    static var subtitle: String { L10n.text("Smoother play and shining arrows") }
    // A patch describes the whole 2.0 line, so players who skip patches see every change.
    static var sections: [(String, String)] { [
        (L10n.text("Smoother play"), L10n.text("Results, records and the career leaderboard no longer pause the game. The playfield and minimap draw faster, and the menu music no longer crackles at startup. Chronicles Moles follow the original game more closely at steel.")),
        (L10n.text("Shining arrows"), L10n.text("On an HDR display, one-way arrows in Macintosh colour artwork catch the light on their upper and left edges.")),
        (L10n.text("Menu themes"), L10n.text("Most launches play the Amiga or Macintosh title theme. Sometimes the menu plays the title theme from another version of the game.")),
        (L10n.text("The art of one bit"), L10n.text("Original Macintosh black-and-white artwork brings its intricate dithering to modern Macs. Choose Macintosh (1-bit) in Graphics settings for Classic artwork and matching monochrome gameplay controls.")),
        (L10n.text("Resume your journey"), L10n.text("Supported journeys and sequence playlists restore the saved attempt, selected action and camera. Classic, The Tribes and Chronicles resume paused. Hot Seat waits for Ready.")),
        (L10n.text("Ghost solutions"), L10n.text("Classic can overlay a recorded solution as blue lemming silhouettes. The optional overlay follows play, pause and rewind without changing your attempt.")),
        (L10n.text("Hot Seat ghosts"), L10n.text("Earlier players' latest attempts appear as coloured ghosts during Hot Seat retries. Ghosts follow rewind and appear in replay movies.")),
        (L10n.text("Leaderboards"), L10n.text("Worldwide leaderboard entries for Classic levels now identify the exact level, including traps and objects.")),
        (L10n.text("Journey"), L10n.text("A revised journey no longer repeats its opening levels. It resumes after the furthest level you reached. Skipped levels appear in Come back to these.")),
        (L10n.text("Language"), L10n.text("Choose a language in Settings > Gameplay > Language. Choose Apply to save the preview or Back to cancel.")),
        (L10n.text("Compatibility"), L10n.text("Universal macOS app for Apple silicon and Intel, macOS 12.3 or later. Classic and The Tribes retain their Complete classifications. Chronicles and NeoLemmix remain Beta, with known content and engine limits in the release notes."))
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
        let scroll = NSScrollView(frame: page.body.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.contentView.copiesOnScroll = false
        scroll.scrollerStyle = .overlay
        scroll.setAccessibilityLabel(L10n.text("Release notes"))
        let document = NSView()
        let width = page.body.bounds.width - 32
        var rows: [(GameLabel, GameLabel, CGFloat)] = []
        for section in Self.sections {
            let heading = GameLabel(labelWithString: section.0)
            heading.role = .heading
            let body = GameLabel(labelWithString: section.1)
            body.cell?.wraps = true
            body.frame = CGRect(x: 0, y: 0, width: width, height: 58)
            let height = max(58, body.intrinsicContentSize.height)
            rows.append((heading, body, height))
        }
        let height = max(page.body.bounds.height, rows.reduce(CGFloat(16)) { $0 + $1.2 + 58 })
        document.frame = CGRect(x: 0, y: 0, width: page.body.bounds.width, height: height)
        var top = height - 8
        for (heading, body, height) in rows {
            heading.frame = CGRect(x: 16, y: top - 28, width: width, height: 28)
            body.frame = CGRect(x: 16, y: top - 34 - height, width: width, height: height)
            document.addSubview(heading); document.addSubview(body)
            top -= height + 58
        }
        scroll.documentView = document
        page.body.addSubview(scroll)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, height - scroll.contentSize.height)))
        scroll.reflectScrolledClipView(scroll.contentView)
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
