#if os(macOS)
import AppKit

/// Local notes also appear after an update installs without an update alert.
@MainActor final class ReleaseWelcome {
    static let seenKey = "WhatsNewSeenBuild"
    /// The release these notes describe. A test fails when Info.plist moves on
    /// to a new version and these notes stay behind.
    static let notesVersion = "1.9.4"
    static let subtitle = "Calmer celebrations and smoother play"
    static let sections = [
        ("Calmer celebrations", "Solved levels get a faint golden haze around scenery. The lemming aura is much softer. Full-rescue levels keep their brief glow and current music."),
        ("Smoother play", "Background glow renders off the main thread. Both sequels reuse bitmap draws, and The Tribes avoids rebuilding unchanged skill panels."),
        ("Resume Golden Path", "Continue finds your saved journey after you play another solo or Hot Seat session. It restores the saved players and turn."),
        ("Clearer replays", "The upper-right panel shows remaining skills and the last three successful skill uses with exact ticks."),
        ("Controls and level order", "Command-Z rewinds one step. Time waits for no Lemming and This Corrosion now appear near the end of Golden Path, including their known fan variants."),
        ("Compatibility", "Universal macOS app for Apple silicon and Intel, macOS 12.3 or later. The Tribes remains Complete. Chronicles and NeoLemmix remain Beta.")
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
#endif
