import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.8.3"
    static let subtitle = "Worldwide records, better journeys and clearer rescue goals"
    static let sections = [
        ("Worldwide records", "Compare speedruns, rescues and career records without Game Center. Share under your initials and watch available record replays. Rewind-assisted runs have separate boards. Sharing is optional."),
        ("Your fastest clears", "Results and local boards track fastest clears and fastest 100% rescues. Record movies stay available for playback."),
        ("A better learning journey", "The 294-level journey includes Going their separate ways and All the 6s. Cellbash appears earlier, and two gimmick levels have been replaced. Fan lessons are bundled for offline play."),
        ("Clearer rescue goals", "Checked completion solutions set best-known rescue targets for stars and philosophy assessments. A known winning solution no longer leaves the last star unknown."),
        ("Smoother play and sound", "Pack progression, saved-run resume, tall-level scrolling and Escape navigation are corrected. Solution replays have effects, rewind sounds are reversed and limited, and music transitions are smoother."),
        ("Artwork and compatibility", "The Macintosh snowman now matches its collision shape. Release notes scroll within the window. NeoLemmix remains Beta; Lemmings 2 and 3 remain Preview.")
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
        let scroll = NSScrollView(frame: page.body.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.contentView.copiesOnScroll = false
        scroll.scrollerStyle = .overlay
        scroll.setAccessibilityLabel("Release notes")
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
        page.addPrimaryAction("Continue", action: close)
        self.page = page
        GameScreen.shared.present(page, owner: window)
    }
}
