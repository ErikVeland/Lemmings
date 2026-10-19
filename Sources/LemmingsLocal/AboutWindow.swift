#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit

/// Credits remain server-editable. Only plain Markdown text is displayed.
@MainActor final class AboutWindow {
    static let shared = AboutWindow()
    static let coffeeURL = GameSupport.coffeeURL
    static let contributorsURL = URL(string: "https://glasscode.academy/lemmings-api/v1/contributors.md")!
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
        self.loadContributors = loadContributors ?? {
            let config = URLSessionConfiguration.ephemeral
            config.httpShouldSetCookies = false
            config.urlCache = nil
            let session = URLSession(configuration: config)
            defer { session.finishTasksAndInvalidate() }
            let request = URLRequest(url: Self.contributorsURL, cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 8)
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.url?.scheme == "https", data.count <= 65_536,
                  let markdown = String(data: data, encoding: .utf8), !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw URLError(.badServerResponse) }
            return markdown
        }
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
        let overview = AboutMarkdownView(markdown: "# Ultimate Lemmings\n\n" + L10n.text("A rescue worth another try."))
        let history = AboutMarkdownView(markdown: bundled("VersionHistory.md") ?? L10n.text("Version history unavailable."))
        let contributors = AboutMarkdownView(markdown: defaults.string(forKey: "ContributorsMarkdownV1")
            ?? bundled("Contributors.md") ?? L10n.text("No contributors listed yet."))
        for (name, view) in [(L10n.text("About"), overview), (L10n.text("Version history"), history),
                             (L10n.text("Contributors"), contributors)] {
            let item = NSTabViewItem(identifier: name)
            item.label = name; item.view = view
            tabs.addTabViewItem(item)
        }
        page.body.addSubview(tabs)
        page.addPrimaryAction(L10n.text("Buy me a coffee")) { NSWorkspace.shared.open(Self.coffeeURL) }
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        page.preferControllerControl(page.controllerBackButton)
        self.page = page
        GameScreen.shared.present(page, owner: owner, onDismiss: { [weak self] in
            self?.task?.cancel(); self?.task = nil; self?.page = nil
        })
        refresh(contributors)
        return page
    }

    private func bundled(_ name: String) -> String? {
        try? String(contentsOf: resources.appendingPathComponent("About").appendingPathComponent(name), encoding: .utf8)
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
                self.defaults.set(markdown, forKey: "ContributorsMarkdownV1")
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

/// Measures each paragraph at the current width, retaining the shipped bitmap type.
@MainActor final class AboutMarkdownView: NSView {
    let scroll = NSScrollView()
    private let document = NSView()
    private let statusLabel = GameLabel(labelWithString: "")
    private let retry = GameButton(title: L10n.text("Retry"), target: nil, action: nil)
    private var rows: [GameLabel] = []
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
        rows.forEach { $0.removeFromSuperview() }
        rows = markdown.components(separatedBy: "\n\n").compactMap { paragraph in
            let text = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let heading = text.hasPrefix("#")
            let plain = text.replacingOccurrences(of: "(?m)^#{1,6} +", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "**", with: "")
            let label = GameLabel(labelWithString: plain)
            label.role = heading ? .heading : .body
            label.alignment = .left
            label.cell?.wraps = true
            document.addSubview(label)
            return label
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let footer: CGFloat = status == nil ? 0 : 42
        statusLabel.isHidden = status == nil; retry.isHidden = !showsRetry
        statusLabel.frame = CGRect(x: 16, y: 4, width: max(0, bounds.width - 150), height: 32)
        retry.frame = CGRect(x: max(0, bounds.width - 120), y: 4, width: 104, height: 32)
        scroll.frame = CGRect(x: 0, y: footer, width: bounds.width, height: max(0, bounds.height - footer))
        let width = max(1, scroll.contentSize.width - 40)
        let heights = rows.map { row -> CGFloat in
            row.preferredMaxLayoutWidth = width
            row.frame.size.width = width
            return max(28, row.intrinsicContentSize.height + 4)
        }
        let oldHeight = document.frame.height
        let oldY = scroll.contentView.bounds.minY
        let height = max(scroll.contentSize.height, heights.reduce(16) { $0 + $1 + 16 })
        document.frame = CGRect(x: 0, y: 0, width: scroll.contentSize.width, height: height)
        var top = height - 8
        for (row, rowHeight) in zip(rows, heights) {
            row.frame = CGRect(x: 16, y: top - rowHeight, width: width, height: rowHeight)
            top -= rowHeight + 16
        }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, min(height - scroll.contentSize.height,
            oldHeight == 0 ? height : oldY + height - oldHeight))))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
#endif
