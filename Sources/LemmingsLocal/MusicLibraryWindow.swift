import AppKit
import NxlvKit

@MainActor final class MusicLibraryWindow: NSObject {
    static let shared = MusicLibraryWindow()
    static let welcomeKey = "SoundtrackLibrariesWelcomeV1"
    private let installer = MusicLibraryInstaller()
    private let directory: URL
    private var task: Task<Void, Never>?
    private var page: GameMenuPage?
    private var packs: [MusicLibraryCatalogue.Pack] = []
    private var selected = Set<String>()
    private var activePack: String?
    private var progress = 0.0
    private var failure: String?
    private var rows: [String: GameCheckButton] = [:]
    private var rowStates: [String: GameLabel] = [:]
    private var all: GameCheckButton?
    private var summary: GameLabel?
    private var status: GameLabel?
    private var meter: GameProgressIndicator?
    private var action: NSButton?
    private var cancel: NSButton?
    private var remove: NSButton?
    private var welcome = false
    private var queueBytes: Int64 = 0
    private var completedBytes: Int64 = 0

    init(directory: URL = MusicLibrary.directory) { self.directory = directory; super.init() }

    func showIfNeeded(in window: NSWindow, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.welcomeKey) else { return }
        let available = MusicLibrary.catalogue()?.packs.contains { !bundled($0) && !MusicLibrary.isInstalled($0, in: directory) } == true
        guard available else { defaults.set(true, forKey: Self.welcomeKey); return }
        show(in: window, welcome: true) { defaults.set(true, forKey: Self.welcomeKey) }
    }

    func show(in window: NSWindow? = nil, welcome: Bool = false, onDismiss: (() -> Void)? = nil) {
        if let page, GameScreen.shared.contains(page) { GameScreen.shared.present(page, owner: window); return }
        self.welcome = welcome
        packs = MusicLibrary.catalogue()?.packs.sorted { $0.title < $1.title } ?? []
        if task == nil { selected = Set(packs.filter { !bundled($0) && !MusicLibrary.isInstalled($0, in: directory) }.map(\.id)) }
        rows = [:]; rowStates = [:]
        let page = GameMenuPage(title: "Download soundtracks")
        page.backTitle = welcome ? "Not now" : "Back"
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        let included = GameLabel(labelWithString: "Original soundtracks included")
        included.role = .heading
        included.frame = CGRect(x: 0, y: 426, width: 992, height: 32)
        page.body.addSubview(included)
        let all = GameCheckButton(title: "All extra soundtracks", target: self, action: #selector(toggleAll))
        all.allowsMixedState = true
        all.frame = CGRect(x: 0, y: 382, width: 650, height: 32)
        page.body.addSubview(all); self.all = all
        let scroll = NSScrollView(frame: CGRect(x: 0, y: 122, width: 992, height: 244))
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let list = NSView(frame: CGRect(x: 0, y: 0, width: 970, height: CGFloat(packs.count * 44)))
        for (index, pack) in packs.enumerated() {
            let y = CGFloat((packs.count - index - 1) * 44)
            let row = GameCheckButton(title: pack.title, target: self, action: #selector(toggleLibrary(_:)))
            row.tag = index; row.frame = CGRect(x: 0, y: y + 4, width: 600, height: 36)
            row.setAccessibilityLabel("\(pack.title), \(pack.trackCount) tracks, \(size(pack.bytes))")
            let state = GameLabel(labelWithString: "")
            state.frame = CGRect(x: 612, y: y + 4, width: 330, height: 36)
            state.alignment = .right
            list.addSubview(row); list.addSubview(state)
            rows[pack.id] = row; rowStates[pack.id] = state
        }
        scroll.documentView = list
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, list.bounds.height - scroll.contentSize.height)))
        page.body.addSubview(scroll)
        let summary = GameLabel(labelWithString: "")
        summary.frame = CGRect(x: 0, y: 78, width: 992, height: 30)
        page.body.addSubview(summary); self.summary = summary
        let meter = GameProgressIndicator(frame: CGRect(x: 0, y: 50, width: 992, height: 16))
        meter.isIndeterminate = false; meter.minValue = 0; meter.maxValue = 1
        meter.setAccessibilityLabel("Soundtrack download progress")
        page.body.addSubview(meter); self.meter = meter
        let status = GameLabel(labelWithString: "")
        status.frame = CGRect(x: 0, y: 0, width: 992, height: 44); status.cell?.wraps = true
        page.body.addSubview(status); self.status = status
        action = page.addPrimaryAction("Download") { [weak self] in self?.download() }
        cancel = page.addSecondaryAction("Cancel") { [weak self] in self?.task?.cancel() }
        cancel?.setAccessibilityLabel("Cancel download")
        remove = page.addSecondaryAction("Manage", at: 1) { [weak self] in self?.manageInstalled() }
        remove?.setAccessibilityLabel("Manage installed soundtracks")
        self.page = page; refresh()
        GameScreen.shared.present(page, owner: window, onDismiss: { [weak self] in self?.page = nil; onDismiss?() })
    }

    private func size(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    private func bundled(_ pack: MusicLibraryCatalogue.Pack) -> Bool {
        guard let root = Bundle.main.resourceURL else { return false }
        return pack.files.filter { !$0.path.hasSuffix(".json") }.allSatisfy { FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0.path).path) }
    }
    private var downloadable: [MusicLibraryCatalogue.Pack] { packs.filter { !bundled($0) && !MusicLibrary.isInstalled($0, in: directory) } }
    @objc private func toggleAll() {
        let ids = Set(downloadable.map(\.id))
        selected = ids.isSubset(of: selected) ? [] : ids
        failure = nil; refresh()
    }
    @objc private func toggleLibrary(_ sender: NSButton) {
        guard packs.indices.contains(sender.tag) else { return }
        let id = packs[sender.tag].id
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        failure = nil; refresh()
    }
    private func refresh() {
        let missing = downloadable
        let busy = activePack != nil
        let pending = missing.filter { selected.contains($0.id) }
        for pack in packs {
            let included = bundled(pack), installed = MusicLibrary.isInstalled(pack, in: directory)
            rows[pack.id]?.isEnabled = !included && !installed && !busy
            rows[pack.id]?.state = included || installed || selected.contains(pack.id) ? .on : .off
            rowStates[pack.id]?.stringValue = included ? "Included" : installed ? "Installed"
                : activePack == pack.id ? "Downloading" : busy && selected.contains(pack.id) ? "Queued" : size(pack.bytes)
        }
        all?.isEnabled = !busy && !missing.isEmpty
        all?.state = !missing.isEmpty && pending.count == missing.count ? .on : pending.isEmpty ? .off : .mixed
        summary?.stringValue = busy ? "\(packs.first { $0.id == activePack }?.title ?? "Soundtracks")  \(size(completedBytes + Int64(progress * Double(packs.first { $0.id == activePack }?.bytes ?? 0)))) / \(size(queueBytes))"
            : missing.isEmpty ? "All soundtracks installed" : "\(pending.count) libraries selected    \(size(pending.reduce(0) { $0 + $1.bytes }))"
        action?.title = busy ? "Downloading" : failure == nil ? "Download" : "Retry"
        action?.isEnabled = !busy && !pending.isEmpty
        cancel?.isHidden = !busy
        remove?.isHidden = busy || !packs.contains { !bundled($0) && MusicLibrary.isInstalled($0, in: directory) }
        meter?.isHidden = !busy
        meter?.doubleValue = queueBytes > 0 ? Double(completedBytes + Int64(progress * Double(packs.first { $0.id == activePack }?.bytes ?? 0))) / Double(queueBytes) : 0
        status?.stringValue = failure ?? (busy && progress >= 1 ? "Verifying" : "")
        if welcome { page?.backTitle = busy || missing.isEmpty ? "Continue" : "Not now" }
        page?.needsDisplay = true
    }
    private func download() {
        let queue = downloadable.filter { selected.contains($0.id) }
        guard !queue.isEmpty, task == nil else { return }
        let requestedAll = queue.count == downloadable.count
        if requestedAll { AnonymousTelemetry.shared.soundtrackAllSelected() }
        queueBytes = queue.reduce(0) { $0 + $1.bytes }; completedBytes = 0
        activePack = queue[0].id; progress = 0; failure = nil; refresh()
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for pack in queue {
                    try Task.checkCancellation()
                    self.activePack = pack.id; self.progress = 0; self.refresh()
                    try await self.installer.download(pack, to: self.directory) { [weak self] value in
                        Task { @MainActor in
                            guard self?.activePack == pack.id else { return }
                            self?.progress = value; self?.refresh()
                        }
                    }
                    self.completedBytes += pack.bytes; self.selected.remove(pack.id)
                    NotificationCenter.default.post(name: MusicLibrary.changed, object: nil)
                }
                if requestedAll && self.downloadable.isEmpty {
                    AnonymousTelemetry.shared.soundtrackAllDownloaded()
                }
            } catch { if !Task.isCancelled { self.failure = error.localizedDescription } }
            self.activePack = nil; self.task = nil; self.refresh()
        }
    }
    private func manageInstalled() {
        let page = GameMenuPage(title: "Installed soundtracks")
        let scroll = NSScrollView(frame: page.body.bounds)
        scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let installed = packs.filter { !bundled($0) && MusicLibrary.isInstalled($0, in: directory) }
        let list = NSView(frame: CGRect(x: 0, y: 0, width: 960, height: CGFloat(installed.count * 52)))
        for (index, pack) in installed.enumerated() {
            let button = GameActionButton(title: "Remove \(pack.title)", primary: false)
            button.frame = CGRect(x: 0, y: CGFloat((installed.count - index - 1) * 52), width: 940, height: 44)
            button.onPress = { [weak self, weak page] in
                guard let self else { return }
                do {
                    try FileManager.default.removeItem(at: self.directory.appendingPathComponent(pack.id))
                    NotificationCenter.default.post(name: MusicLibrary.changed, object: nil)
                } catch { self.failure = error.localizedDescription }
                if let page { GameScreen.shared.dismiss(page) }
                self.refresh()
            }
            list.addSubview(button)
        }
        scroll.documentView = list; scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, list.bounds.height - scroll.contentSize.height)))
        page.body.addSubview(scroll)
        page.onBack = { [weak page] in if let page { GameScreen.shared.dismiss(page) } }
        GameScreen.shared.present(page)
    }
}
