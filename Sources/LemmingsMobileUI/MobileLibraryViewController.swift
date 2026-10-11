#if os(iOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit
import UniformTypeIdentifiers

private struct MobileMenuPreview: Sendable {
    let frame: MobilePixelFrame
    let origin: MobilePoint
    let snapshot: MobileGameSnapshot
}

private actor MobileMenuPreviewLoader {
    let directory: URL
    private var library: ClassicMobileLibrary?
    private var frames: [Int: MobileMenuPreview] = [:]
    init(directory: URL) { self.directory = directory }
    func load(_ index: Int) throws -> MobileMenuPreview {
        try Task.checkCancellation()
        if let cached = frames[index] { return cached }
        let library = try self.library ?? ClassicMobileLibrary(directory: directory)
        self.library = library
        let session = try library.loadLevel(at: index).session
        let preview = MobileMenuPreview(frame: try session.render(highlight: nil),
                                        origin: session.initialCameraOrigin, snapshot: session.snapshot)
        try Task.checkCancellation()
        if frames.count >= 6 { frames.removeAll() }
        frames[index] = preview
        return preview
    }
}

@MainActor final class MobileLibraryViewController: UIViewController, UIDocumentPickerDelegate {
    private enum Route { case home, levels, settings, data }
    private let scrollView = UIScrollView()
    private let canvas = MobileMenuCanvas()
    private var route = Route.home
    private var store: MobileContentStore?
    private var checkpointStore: MobileCheckpointStore?
    private var library: (any MobileGameLibrary)?
    private var pendingCheckpoint: MobileCheckpointEnvelope?
    private var selectedIndex = 0
    private var previewLoader: MobileMenuPreviewLoader?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = UUID()
    private var selectedPreview: MobileMenuPreview?
    private var notice = ""
    private var loading = false
    private var game: MobileGameViewController?
    private var solved: Set<Int> {
        Set(UserDefaults.standard.array(forKey: progressKey) as? [Int] ?? [])
    }
    private var progressKey: String { "mobile.completed." + (library?.displayName ?? "classic") }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { game != nil }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scrollView.backgroundColor = .black
        scrollView.alwaysBounceVertical = false
        scrollView.addSubview(canvas)
        view.addSubview(scrollView)
        canvas.onAction = { [weak self] in self?.handle($0) }
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            swipe.cancelsTouchesInView = false
            canvas.addGestureRecognizer(swipe)
        }
        do {
            let configured = try MobileContentStore()
            store = configured
            checkpointStore = MobileCheckpointStore(url: configured.checkpointURL)
            reloadLibrary()
        } catch { notice = error.localizedDescription; rebuild() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.safeAreaLayoutGuide.layoutFrame
        let size = canvas.size(width: scrollView.bounds.width, minimumHeight: scrollView.bounds.height)
        canvas.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
        game?.view.frame = view.bounds
    }
    private func rebuild() {
        let count = library?.levels.count ?? 0
        let subtitle = loading ? "Loading..." : notice
        switch route {
        case .home:
            var rows: [GameFrontEnd.Action] = []
            if pendingCheckpoint != nil { rows.append(.init("resume", "Resume saved run", primary: true)) }
            rows.append(.init("classic", "Lemmings  \(solved.count)/\(count)", enabled: count > 0,
                              primary: pendingCheckpoint == nil && count > 0))
            rows.append(.init("l2", "Lemmings 2 - Unavailable", enabled: false))
            rows.append(.init("l3", "Lemmings 3 - Unavailable", enabled: false))
            canvas.page = .init(title: "Lemmings", subtitle: subtitle, home: true, rows: rows,
                                footer: [.init("settings", "Settings"), .init("data", "Game Data")])
            canvas.preview = nil
        case .levels:
            guard let library, library.levels.indices.contains(selectedIndex) else { route = .home; rebuild(); return }
            let level = library.levels[selectedIndex]
            let rank = library.levels.filter { $0.rank == level.rank }
            let rankIndex = rank.firstIndex(where: { $0.index == selectedIndex }) ?? 0
            let stats: [String] = selectedPreview.map {
                let s = $0.snapshot
                return ["\(s.total) Lemmings   Save \(s.required)",
                        s.remainingSeconds.map { "Time \($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? "No time limit"]
            } ?? []
            canvas.page = .init(title: level.title,
                                subtitle: loading ? "Loading..." : "\(level.rank)  \(level.number)/\(rank.count)",
                                details: stats,
                                footer: [.init("rankPrevious", "< Rank"), .init("rankNext", "Rank >"),
                                         .init("previous", "< Level", enabled: rankIndex > 0),
                                         .init("next", "Level >", enabled: rankIndex + 1 < rank.count),
                                         .init("home", "Back"),
                                         .init("play", solved.contains(selectedIndex) ? "Play again" : "Play", enabled: !loading, primary: true)],
                                preview: true, footerColumns: 2)
            if let preview = selectedPreview {
                canvas.preview = MobileBitmapRenderer.image(preview.frame)
                canvas.previewSource = CGRect(x: max(0, min(Double(max(0, preview.frame.width - 320)), preview.origin.x)),
                                              y: 0, width: Double(min(320, preview.frame.width)), height: Double(preview.frame.height))
            }
        case .settings:
            let defaults = UserDefaults.standard
            let planning = !defaults.bool(forKey: "mobile.continuousSkillSelection")
            let fast = defaults.integer(forKey: "mobile.fastSpeed")
            let fastSpeed = [2, 3, 5, 10].contains(fast) ? fast : 2
            canvas.page = .init(title: "Settings", subtitle: subtitle,
                                rows: [.init("planning", "Pause to assign", selected: planning),
                                       .init("speed", "Fast speed: \(fastSpeed)X")],
                                footer: [.init("home", "Back")])
            canvas.preview = nil
        case .data:
            canvas.page = .init(title: "Game Data", subtitle: subtitle,
                                details: library.map { ["\($0.displayName)", "\($0.levels.count) levels"] } ?? [],
                                footer: [.init("home", "Back"), .init("import", "Import", enabled: !loading, primary: library == nil)])
            canvas.preview = nil
        }
        canvas.previewSource = route == .levels ? canvas.previewSource : nil
        view.setNeedsLayout()
    }
    private func navigate(_ next: Route) {
        previewTask?.cancel(); previewGeneration = UUID(); loading = false
        route = next; notice = ""
        scrollView.setContentOffset(.zero, animated: false)
        rebuild()
    }
    private func handle(_ id: String) {
        switch id {
        case "classic": navigate(.levels); selectLevel(selectedIndex)
        case "home": navigate(.home)
        case "settings": navigate(.settings)
        case "data": navigate(.data)
        case "import": chooseGameData()
        case "resume": resumeSavedRun()
        case "previous": moveLevel(-1)
        case "next": moveLevel(1)
        case "rankPrevious": moveRank(-1)
        case "rankNext": moveRank(1)
        case "play": startLevel(selectedIndex, checkpoint: nil)
        case "planning":
            let defaults = UserDefaults.standard
            defaults.set(!defaults.bool(forKey: "mobile.continuousSkillSelection"), forKey: "mobile.continuousSkillSelection")
            rebuild()
        case "speed":
            let defaults = UserDefaults.standard
            let speeds = [2, 3, 5, 10]
            let current = speeds.firstIndex(of: defaults.integer(forKey: "mobile.fastSpeed")) ?? 0
            defaults.set(speeds[(current + 1) % speeds.count], forKey: "mobile.fastSpeed")
            rebuild()
        default: break
        }
    }
    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        guard route == .levels, game == nil else { return }
        moveLevel(gesture.direction == .left ? 1 : -1)
    }
    private func moveLevel(_ offset: Int) {
        guard let library else { return }
        let index = selectedIndex + offset
        guard library.levels.indices.contains(index),
              library.levels[index].rank == library.levels[selectedIndex].rank else { return }
        selectLevel(index)
    }
    private func moveRank(_ offset: Int) {
        guard let library else { return }
        var ranks: [String] = []
        for level in library.levels where !ranks.contains(level.rank) { ranks.append(level.rank) }
        guard let current = ranks.firstIndex(of: library.levels[selectedIndex].rank) else { return }
        let next = (current + offset + ranks.count) % ranks.count
        if let level = library.levels.first(where: { $0.rank == ranks[next] }) { selectLevel(level.index) }
    }
    private func selectLevel(_ index: Int) {
        guard let previewLoader else { selectedIndex = index; rebuild(); return }
        previewTask?.cancel()
        let generation = UUID(); previewGeneration = generation
        loading = true; rebuild()
        previewTask = Task {
            do {
                let preview = try await previewLoader.load(index)
                guard !Task.isCancelled, previewGeneration == generation, route == .levels else { return }
                selectedIndex = index; selectedPreview = preview; loading = false
                rebuild()
            } catch {
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; notice = error.localizedDescription
                rebuild()
            }
        }
    }
    private func reloadLibrary() {
        do {
            library = try store?.loadLibrary(bundledDirectory: Bundle.main.resourceURL?.appendingPathComponent("BetaGameData", isDirectory: true))
            if let classic = library as? ClassicMobileLibrary { previewLoader = MobileMenuPreviewLoader(directory: classic.directory) }
            selectedIndex = 0; selectedPreview = nil
            if library == nil { route = .data }
            rebuild(); loadCheckpoint()
        } catch { library = nil; notice = error.localizedDescription; rebuild() }
    }
    private func chooseGameData() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self; picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let source = urls.first, let store else { return }
        loading = true; rebuild()
        let accessed = source.startAccessingSecurityScopedResource()
        Task {
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }
            let result = await Task.detached(priority: .userInitiated) { Result { try store.install(directory: source) } }.value
            loading = false
            switch result {
            case .success: notice = ""; reloadLibrary()
            case let .failure(error): notice = error.localizedDescription; rebuild()
            }
        }
    }
    private func loadCheckpoint() {
        guard let checkpointStore else { return }
        Task {
            do { pendingCheckpoint = try await checkpointStore.load(); rebuild() }
            catch { pendingCheckpoint = nil; notice = error.localizedDescription; rebuild() }
        }
    }
    private func resumeSavedRun() {
        guard let checkpoint = pendingCheckpoint else { return }
        startLevel(checkpoint.levelIndex, checkpoint: checkpoint)
    }
    private func startLevel(_ index: Int, checkpoint: MobileCheckpointEnvelope?) {
        guard let library, let checkpointStore else { return }
        do {
            let content = try library.loadLevel(at: index)
            if let checkpoint {
                guard checkpoint.engine == content.session.engineIdentifier,
                      checkpoint.engineFingerprint == content.session.engineFingerprint,
                      checkpoint.levelIdentifier == content.session.levelIdentifier,
                      checkpoint.levelFingerprint == content.session.levelFingerprint else { throw MobileSessionError.changedLevel }
                try content.session.restoreCheckpointPayload(checkpoint.payload)
            }
            let next = MobileGameViewController(summary: content.summary, session: content.session,
                                               checkpointStore: checkpointStore, restoredCheckpoint: checkpoint)
            next.onCompleted = { [weak self] snapshot in
                guard let self, snapshot.didWin else { return }
                var completed = self.solved; completed.insert(index)
                UserDefaults.standard.set(completed.sorted(), forKey: self.progressKey)
            }
            next.onExit = { [weak self] action in
                guard let self else { return }
                switch action {
                case .library:
                    self.game?.willMove(toParent: nil); self.game?.view.removeFromSuperview(); self.game?.removeFromParent()
                    self.game = nil; self.scrollView.isHidden = false; self.loadCheckpoint(); self.rebuild()
                    self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                case .retry: self.startLevel(index, checkpoint: nil)
                case .next:
                    if library.levels.indices.contains(index + 1) { self.startLevel(index + 1, checkpoint: nil) }
                    else { self.handle("home"); self.game?.onExit?(.library) }
                }
            }
            let previous = game
            addChild(next); next.view.frame = view.bounds
            next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(next.view); next.didMove(toParent: self)
            game = next; scrollView.isHidden = true
            previous?.willMove(toParent: nil); previous?.view.removeFromSuperview(); previous?.removeFromParent()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        } catch {
            if let game { game.showPreparationError(error.localizedDescription) }
            else { notice = error.localizedDescription; rebuild() }
        }
    }
}
#endif
