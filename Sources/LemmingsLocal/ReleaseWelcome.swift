import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.8.1"
    static let subtitle = "The full journey, sharper pixels and steadier effects"
    static let sections = [
        ("The full journey", "Oh My! All Lemmings! returns to 294 curated levels, official and fan, in a Redux-anchored order. Your history and progress carry over."),
        ("Explosions stay on the terrain", "Pan, zoom, resize or use CRT curvature and each blast stays where it happened, in Classic, NeoLemmix, Lemmings 2 and Lemmings 3."),
        ("Sharper pixel artwork", "Game artwork, controls, previews and original movies keep crisp pixels when scaled."),
        ("The music comes back", "After the last nuke explosion, the funeral dirge spins back up to normal speed, even on a failed result."),
        ("NeoLemmix sound and controls", "Hatches, assignments, rescues, deaths and nukes play sound effects. The - and + keys match the on-screen buttons, and each level opens on the first hatch. NeoLemmix remains Beta."),
        ("Closer Lemmings 3", "Hatch order, Bricks, Shimmy wear and Mole wall patrols follow the original more closely. Lemmings 2 and 3 remain Preview.")
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
