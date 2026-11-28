#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit

/// Local heritage credits and server-editable contributors share the bitmap reader.
@MainActor final class AboutWindow {
    static let shared = AboutWindow()
    static let coffeeURL = GameSupport.coffeeURL
    static let contributorsURL = AboutContent.contributorsURL
    private let resources: URL
    private let defaults: UserDefaults
    private let loadContributors: () async throws -> String
    private var task: Task<Void, Never>?
    private var page: GameMenuPage?

    init(resources: URL = Bundle.main.resourceURL ?? Bundle.main.bundleURL,
         defaults: UserDefaults = .standard,
         loadContributors: (() async throws -> String)? = nil) {
        self.resources = resources
        self.defaults = defaults
        self.loadContributors = loadContributors ?? { try await AboutContent.loadContributors() }
    }

    @discardableResult func show(owner: NSWindow? = nil) -> GameMenuPage {
        if let page, GameScreen.shared.contains(page) { GameScreen.shared.present(page); return page }
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? L10n.text("Unknown")
        let build = info["CFBundleVersion"] as? String ?? L10n.text("Unknown")
        let page = GameMenuPage(title: L10n.text("Ultimate Lemmings"), subtitle: "\(version) · \(build)")
        let tabs = GameTabs(frame: page.body.bounds)
        tabs.setAccessibilityLabel(L10n.text("About sections"))
        tabs.autoresizingMask = [.width, .height]
        let content = AboutContent(resources: resources)
        let overview = AboutMarkdownView(markdown: content.heritage
            ?? "# Ultimate Lemmings\n\n" + L10n.text("A rescue worth another try."))
        let history = AboutHistoryView(markdown: content.versionHistory ?? L10n.text("Version history unavailable."))
        let contributors = AboutMarkdownView(markdown: defaults.string(forKey: AboutContent.contributorCacheKey)
            ?? content.contributors ?? L10n.text("No contributors listed yet."))
        for (name, view) in [(L10n.text("About"), overview), (L10n.text("Version history"), history),
                             (L10n.text("Contributors"), contributors)] {
            let item = NSTabViewItem(identifier: name)
            item.label = name; item.view = view
            tabs.addTabViewItem(item)
        }
        page.body.addSubview(tabs)
        page.addSecondaryAction("Lemmings Forums") { NSWorkspace.shared.open(AboutContent.forumsURL) }
        #if !ULTIMATE_LEMMIX_STORE
        page.addPrimaryAction(L10n.text("Buy me a coffee")) { NSWorkspace.shared.open(Self.coffeeURL) }
        #else
        page.addPrimaryAction(DeveloperTipArt.action.title) { [weak page] in
            guard let page, let window = page.window, GameScreen.shared.controllerPage(in: window) === page else { return }
            DeveloperTipWindow.shared.show(owner: page.window)
        }
        #endif
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        page.preferControllerControl(page.controllerBackButton)
        self.page = page
        GameScreen.shared.present(page, owner: owner, onDismiss: { [weak self] in
            self?.task?.cancel(); self?.task = nil; self?.page = nil
        })
        refresh(contributors)
        return page
    }

    private func refresh(_ view: AboutMarkdownView) {
        task?.cancel()
        view.status = L10n.text("Loading...")
        view.onRetry = { [weak self, weak view] in if let view { self?.refresh(view) } }
        task = Task { [weak self, weak view] in
            guard let self else { return }
            do {
                let markdown = try await self.loadContributors()
                guard !Task.isCancelled else { return }
                self.defaults.set(markdown, forKey: AboutContent.contributorCacheKey)
                view?.markdown = markdown
                view?.status = nil
            } catch {
                guard !Task.isCancelled else { return }
                view?.status = L10n.text("Saved list · Offline")
                view?.showsRetry = true
            }
        }
    }
}

@MainActor private final class AboutReleaseButton: GameButton {
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window != nil else { return false }
        performClick(nil)
        return true
    }
}

/// A release index keeps older notes reachable without one continuous wall of text.
@MainActor final class AboutHistoryView: NSView {
    let releases: [AboutContent.Release]
    let detail: AboutMarkdownView
    let indexScroll = NSScrollView()
    private let indexDocument = NSView()
    private var buttons: [GameButton] = []
    private(set) var selectedIndex = 0

    init(markdown: String) {
        let entries = AboutContent.releases(markdown: markdown)
        releases = entries
        detail = AboutMarkdownView(markdown: entries.first?.markdown ?? markdown)
        super.init(frame: .zero)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("Version history"))
        indexScroll.hasVerticalScroller = true
        indexScroll.hasHorizontalScroller = false
        indexScroll.drawsBackground = false
        indexScroll.scrollerStyle = .overlay
        indexScroll.documentView = indexDocument
        addSubview(indexScroll); addSubview(detail)
        for (index, entry) in entries.enumerated() {
            let button = AboutReleaseButton(title: indexTitle(index), target: self, action: #selector(selectRelease))
            button.tag = index
            button.setButtonType(.pushOnPushOff)
            button.setAccessibilityLabel(entry.title)
            button.setAccessibilityRole(.radioButton)
            indexDocument.addSubview(button)
            buttons.append(button)
        }
        updateSelection()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    /// The version alone, or with its build when another release shares that version.
    func indexTitle(_ index: Int) -> String {
        releases[index].indexTitle
    }

    @objc private func selectRelease(_ sender: NSButton) {
        selectedIndex = sender.tag
        detail.markdown = releases[selectedIndex].markdown
        updateSelection()
    }
    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            button.state = index == selectedIndex ? .on : .off
            button.setAccessibilityValue(index == selectedIndex ? 1 : 0)
            button.needsDisplay = true
        }
    }
    override func layout() {
        super.layout()
        let indexWidth: CGFloat = 164
        indexScroll.frame = CGRect(x: 0, y: 0, width: indexWidth, height: bounds.height)
        detail.frame = CGRect(x: indexWidth + 20, y: 0,
                              width: max(0, bounds.width - indexWidth - 20), height: bounds.height)
        let oldHeight = indexDocument.frame.height
        let oldY = indexScroll.contentView.bounds.minY
        let height = max(indexScroll.contentSize.height, CGFloat(buttons.count * 52 + 8))
        indexDocument.frame = CGRect(x: 0, y: 0, width: indexScroll.contentSize.width, height: height)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 4, y: height - CGFloat(index + 1) * 52,
                                  width: max(0, indexDocument.bounds.width - 20), height: 44)
        }
        indexScroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, min(height - indexScroll.contentSize.height,
            oldHeight == 0 ? height : oldY + height - oldHeight))))
        indexScroll.reflectScrolledClipView(indexScroll.contentView)
    }
}

/// Paragraphs and list items share a bounded reading column in the shipped bitmap type.
@MainActor final class AboutMarkdownView: NSView {
    let scroll = NSScrollView()
    private let document = NSView()
    private let statusLabel = GameLabel(labelWithString: "")
    private let retry = GameButton(title: L10n.text("Retry"), target: nil, action: nil)
    private struct Row {
        let label: GameLabel
        let marker: GameLabel?
        let heading: Bool
        let title: Bool
    }
    private var rows: [Row] = []
    private var resetScroll = true
    var onRetry: (() -> Void)?
    var status: String? { didSet { statusLabel.stringValue = status ?? ""; needsLayout = true } }
    var showsRetry = false { didSet { needsLayout = true } }
    var markdown: String { didSet { rebuild() } }

    init(markdown: String) {
        self.markdown = markdown
        super.init(frame: .zero)
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false; scroll.scrollerStyle = .overlay
        scroll.documentView = document
        addSubview(scroll); addSubview(statusLabel); addSubview(retry)
        retry.target = self; retry.action = #selector(retryLoad)
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func retryLoad() { showsRetry = false; onRetry?() }

    private func rebuild() {
        document.subviews.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        for paragraph in AboutContent.paragraphs(markdown: markdown) {
            let label = GameLabel(labelWithString: paragraph.text)
            label.role = paragraph.heading ? .heading : .body
            label.alignment = .left
            label.cell?.wraps = true
            let marker = paragraph.bullet ? GameLabel(labelWithString: "-") : nil
            document.addSubview(label)
            if let marker { document.addSubview(marker) }
            rows.append(Row(label: label, marker: marker, heading: paragraph.heading, title: paragraph.title))
        }
        resetScroll = true
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let footer: CGFloat = status == nil ? 0 : 42
        statusLabel.isHidden = status == nil; retry.isHidden = !showsRetry
        statusLabel.frame = CGRect(x: 16, y: 4, width: max(0, bounds.width - 150), height: 32)
        retry.frame = CGRect(x: max(0, bounds.width - 120), y: 4, width: 104, height: 32)
        scroll.frame = CGRect(x: 0, y: footer, width: bounds.width, height: max(0, bounds.height - footer))
        // NSScrollView must finish tiling before the reading column is measured.
        // Otherwise the first visible frame wraps against the previous clip size.
        scroll.tile()
        let width = max(1, min(680, scroll.contentSize.width - 40))
        let left = floor((scroll.contentSize.width - width) / 2)
        let heights = rows.map { row -> CGFloat in
            let rowWidth = width - (row.marker == nil ? 0 : 20)
            row.label.preferredMaxLayoutWidth = rowWidth
            row.label.frame.size.width = rowWidth
            return max(28, row.label.intrinsicContentSize.height + 4)
        }
        let gaps = rows.enumerated().map { index, row -> CGFloat in
            if index == 0 { return 8 }
            if row.title { return 32 }
            if row.heading { return 24 }
            return row.marker == nil ? 12 : 6
        }
        let oldHeight = document.frame.height
        let oldY = scroll.contentView.bounds.minY
        let height = max(scroll.contentSize.height, zip(heights, gaps).reduce(24) { $0 + $1.0 + $1.1 })
        document.frame = CGRect(x: 0, y: 0, width: scroll.contentSize.width, height: height)
        var top = height
        for (index, row) in rows.enumerated() {
            top -= gaps[index] + heights[index]
            let indent: CGFloat = row.marker == nil ? 0 : 20
            row.label.frame = CGRect(x: left + indent, y: top, width: width - indent, height: heights[index])
            row.marker?.frame = CGRect(x: left, y: top + heights[index] - 28, width: 16, height: 28)
        }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, min(height - scroll.contentSize.height,
            resetScroll ? height : oldY + height - oldHeight))))
        resetScroll = false
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
#endif
