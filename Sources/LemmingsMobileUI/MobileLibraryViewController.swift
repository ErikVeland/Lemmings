#if os(iOS)
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit
import UniformTypeIdentifiers

struct MobileMenuPreview: Sendable {
    let frame: MobilePixelFrame
    let origin: MobilePoint
    let snapshot: MobileGameSnapshot
}

/// Each prepared session transfers from the loader to the main thread once.
/// Libraries retain assets and never retain the sessions they create.
struct MobilePreparedLevel: @unchecked Sendable { let content: MobileLevelContent }

actor MobileMenuPreviewLoader {
    /// Each loader opens its own library, so previews never share state with the one being played.
    private let makeLibrary: @Sendable () throws -> any MobileGameLibrary
    private var library: (any MobileGameLibrary)?
    private var frames: [Int: MobileMenuPreview] = [:]
    init(makeLibrary: @escaping @Sendable () throws -> any MobileGameLibrary) { self.makeLibrary = makeLibrary }
    func prepare(_ index: Int) throws -> MobilePreparedLevel {
        try Task.checkCancellation()
        let opened = try library ?? makeLibrary()
        library = opened
        let content = try opened.loadLevel(at: index)
        try Task.checkCancellation()
        return MobilePreparedLevel(content: content)
    }
    func load(_ index: Int) throws -> MobileMenuPreview {
        try Task.checkCancellation()
        if let cached = frames[index] { return cached }
        let library = try self.library ?? makeLibrary()
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
    enum Route: Equatable {
        case home, family(MobileFamily), levels, settings, settingsGroup(MobileSettingsGroup), controllerMappings, playInsights, soundtrack, data
        case whatsNew, effectsWelcome, telemetryConsent, insightsToken, insightsClear
        case journey, progression, techniques, rankings
        case collections, playlists, playlist(UUID), addToPlaylist, players, shuffleAll, hotSeat, hotSeats, records, achievements, recordLevel(String)
    }
    private let scrollView = UIScrollView()
    let canvas = MobileMenuCanvas()
    private let unfold = MobileUnfoldView()
    private var previousSize = CGSize.zero
    let browser = MobileLevelBrowserView()
    var browserShown = false
    var route = Route.home
    var mobileInsights = MobileInsightsState()
    var fanCountsTask: Task<Void, Never>?
    var fanCountGeneration = UUID()
    var learningTask: Task<Void, Never>?
    var learningPreparing = false
    lazy var mobileRankings = MobileRankingsController(presenter: self, store: arcadeStore)
    lazy var libraryInput = makeLibraryInput()
    private var inputLink: CADisplayLink?
    override var canBecomeFirstResponder: Bool { game == nil && !searchField.isFirstResponder && mobileInsights.field?.isFirstResponder != true }
    private var store: MobileContentStore?
    var checkpointStore: MobileCheckpointStore?
    var library: (any MobileGameLibrary)?
    var catalogue: MobileCatalogue?
    var currentPack: MobileContentPack?
    var levelsBackRoute = Route.home
    /// The players on this device. Each has their own collections and progress.
    var profiles = MobileStorage.standard(profile: "_players").load(MobileProfiles.self, name: "players") ?? MobileProfiles()
    lazy var arcadeStore = ArcadeStore(storage: .current(), bundledProofs: nil)
    var collectionsBridge: MobileCollectionsBridge?
    var creatingPlayer = false
    var draftPortrait = 0
    var storage: MobileStorage { .standard(profile: profiles.active.id) }
    lazy var favourites = MobileFavourites.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    lazy var recents = MobileRecents.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    lazy var playlists = MobilePlaylistStore.load(from: storage, legacy: profiles.active.id == MobileProfiles.defaultID)
    /// Set while the Players page keyboard edits a name, and while Shuffle all scans the packs.
    var renamingPlayer = false
    var hotSeats = MobileHotSeatStore.load(from: MobileStorage.standard(profile: "_players"))
    var hotSeatRoster: MobileHotSeatRoster?
    var confirmingRestart = false
    var shufflePool: (entries: [MobileFavourites.Entry], packs: Int)?
    var shuffleScanning = false
    var playlistSelection: Int?
    var confirmingDelete = false
    /// Non-nil while the keyboard edits a playlist name.
    var nameDraft: String?
    /// Set while a playlist run is the library being played.
    var activeRun: MobilePlaylistRun?
    var searchQuery = ""
    let searchField = UITextField()
    private var fanUpdateStatus = ""
    private var fanUpdating = false
    var pendingCheckpoint: MobileCheckpointEnvelope?
    var selectedIndex = 0
    var previewLoader: MobileMenuPreviewLoader?
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = UUID()
    var selectedPreview: MobileMenuPreview?
    var notice = ""
    private var loading = false
    private var preparingLevel = false
    var game: MobileGameViewController?
    private var solved: Set<Int> {
        // Favourites mirror the progress of the packs their levels belong to.
        if let list = library as? MobileFavouritesLibrary {
            // Resolving a level opens its pack, so only packs with progress are resolved.
            var progress: [String: Set<Int>] = [:]
            return Set(list.levels.indices.filter { index in
                let pack = String(list.levelKey(at: index).split(separator: "|", maxSplits: 1).first ?? "")
                if progress[pack] == nil { progress[pack] = solvedLevels(for: pack) }
                guard progress[pack]?.isEmpty == false else { return false }
                return list.origin(of: index).map { progress[$0.pack]?.contains($0.index) ?? false } ?? false
            })
        }
        return solvedLevels(for: currentPack?.id)
    }
    private func progressKey(for pack: String?, fallback: String) -> String {
        "mobile.completed." + (pack ?? fallback) + progressSuffix
    }
    func solvedLevels(for pack: String?) -> Set<Int> {
        let defaults = UserDefaults.standard
        var all = Set(defaults.array(forKey: progressKey(for: pack, fallback: library?.displayName ?? "classic")) as? [Int] ?? [])
        // Builds before the catalogue stored Classic progress under the release name.
        if pack == "release/lemmings", profiles.active.id == MobileProfiles.defaultID, hotSeat == nil {
            all.formUnion(defaults.array(forKey: "mobile.completed.Lemmings") as? [Int] ?? [])
        }
        return all
    }

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
        browser.isHidden = true
        browser.onBack = { [weak self] in self?.handle("back") }
        browser.onPlay = { [weak self] index in self?.selectedIndex = index; self?.startLevel(index, checkpoint: nil) }
        browser.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            self.browser.setFavourite(self.isFavourite(index))
        }
        browser.onFavourite = { [weak self] index in self?.toggleFavourite(index) }
        browser.onPlaylist = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            _ = self.handleCollections("addPlaylist")
        }
        browser.artworkLoader = { [weak self] index in await self?.coverArtwork(index) }
        view.addSubview(browser)
        view.addSubview(unfold)
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            swipe.cancelsTouchesInView = false
            canvas.addGestureRecognizer(swipe)
        }
        _ = saveProfiles()
        reloadPlayerData()
        catalogue = Self.makeCatalogue()
        inputLink = CADisplayLink(target: self, selector: #selector(pollLibraryInput(_:)))
        inputLink?.preferredFramesPerSecond = 30
        inputLink?.add(to: .main, forMode: .common)
        searchField.autocorrectionType = .no
        searchField.spellCheckingType = .no
        searchField.textContentType = nil
        if #available(iOS 17.0, *) { searchField.inlinePredictionType = .no }
        searchField.autocapitalizationType = .none
        searchField.returnKeyType = .done
        searchField.alpha = 0.01
        searchField.frame = CGRect(x: -100, y: -100, width: 10, height: 10)
        searchField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.nameDraft != nil { self.nameDraft = String((self.searchField.text ?? "").prefix(40)) }
            else { self.searchQuery = self.searchField.text ?? "" }
            self.rebuild()
        }, for: .editingChanged)
        searchField.addAction(UIAction { [weak self] _ in self?.searchField.resignFirstResponder(); self?.rebuild() }, for: .editingDidEndOnExit)
        view.addSubview(searchField)
        do {
            let configured = try MobileContentStore()
            store = configured
            checkpointStore = MobileCheckpointStore(url: configured.checkpointURL)
            reloadLibrary()
        } catch { notice = error.localizedDescription; rebuild() }
        beginWelcomeIfNeeded()
        measureMobileFanPacks()
        AnonymousTelemetry.shared.recordActiveDay()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if game == nil { becomeFirstResponder() }
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = libraryInput.began(presses)
        super.pressesBegan(presses.subtracting(handled), with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = libraryInput.ended(presses)
        super.pressesEnded(presses.subtracting(handled), with: event)
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        libraryInput.reset()
        super.pressesCancelled(presses, with: event)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let expanded = previousSize.width > 0 && view.bounds.width > previousSize.width * 1.25
        let division = MobileSystemRegions.read(in: view).contains { $0.kind == .division && $0.frame.height > $0.frame.width }
        if previousSize != view.bounds.size {
            unfold.stop()
            if game == nil, expanded, division { unfold.play(in: MobileSystemRegions.menuFrame(in: view)) }
        }
        previousSize = view.bounds.size
        browser.frame = view.bounds
        syncPages()
        scrollView.frame = MobileSystemRegions.menuFrame(in: view)
        let size = canvas.size(width: scrollView.bounds.width, minimumHeight: scrollView.bounds.height)
        canvas.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
        game?.view.frame = view.bounds
    }
    func rebuild() {
        unfold.stop()
        let count = library?.levels.count ?? 0
        let subtitle = loading ? "Loading..." : notice
        switch route {
        case .home:
            var resume: [GameFrontEnd.Action] = []
            if catalogue != nil, let run = learning.run {
                resume.append(.init("learningResume", "Resume journey  \(run.currentIndex + 1)/\(run.entries.count)"))
            }
            if catalogue != nil, let run = playlists.run {
                resume.append(.init("runResume", "Resume \(run.name)  \(run.position + 1)/\(run.entries.count)"))
            }
            if let saved = pendingCheckpoint {
                resume.append(checkpointMatchesSession(saved)
                    ? .init("resume", "Resume - " + playerName(saved.owner ?? profiles.activeID))
                    : .init("seatOther", otherSessionTitle(for: saved)))
            }
            let families: [GameFrontEnd.Action] = MobileFamily.allCases.map { family in
                let packs = catalogue?.packs(in: family) ?? []
                if catalogue == nil, family == .classic {
                    return .init("classic", "Classic Lemmings  \(solved.count)/\(count)", enabled: count > 0)
                }
                let total = packs.reduce(0) { $0 + ($1.levelCount ?? 0) }
                let passed = packs.reduce(0) { $0 + solvedLevels(for: $1.id).count }
                let title = family.title + (packs.isEmpty ? " - No data" : "  \(passed)/\(total)")
                return .init("family." + family.rawValue, title, enabled: !packs.isEmpty)
            } + [.init("neolemmix", "NeoLemmix - Unavailable", enabled: false),
                 .init("l2", "Lemmings 2 - Unavailable", enabled: false),
                 .init("l3", "Lemmings 3 - Unavailable", enabled: false)]
            let journey = bundledJourney
            let journeyTitle = LearningJourney.title + "  \(journey.map { learning.progress.solvedCount(in: $0) } ?? 0)/\(journey?.lessons.count ?? 0)"
            let initials = hotSeat.map { $0.players.map(playerName).joined(separator: " v ") } ?? profiles.active.name
            canvas.page = MobileHomeArt.page(resume: resume,
                journey: .init("journey", journeyTitle, enabled: catalogue != nil && journey != nil),
                families: families, initials: initials, subtitle: subtitle)
            canvas.preview = nil
        case let .family(family):
            let all = catalogue?.packs(in: family) ?? []
            let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            let packs = query.isEmpty ? all : all.filter { $0.title.lowercased().contains(query) }
            var rows: [GameFrontEnd.Action] = []
            if family == .fan {
                rows.append(.init("search", "Search: " + searchQuery.uppercased() + (searchField.isFirstResponder ? "_" : ""),
                                  selected: !query.isEmpty))
                rows.append(.init("shuffleAll", "Shuffle all"))
            }
            rows += packs.map { pack in
                .init("pack." + pack.id, pack.title + (pack.levelCount.map { "  \($0)" } ?? "") + solvedMark(pack))
            }
            if family == .fan {
                rows.append(.init("fanUpdate", fanUpdating ? "Checking for new packs..." : "Check for new packs", enabled: !fanUpdating))
            }
            let count = query.isEmpty ? "\(all.count) packs" : "\(packs.count)/\(all.count) packs"
            canvas.page = .init(title: family.title,
                                subtitle: !subtitle.isEmpty ? subtitle : (fanUpdateStatus.isEmpty ? count : fanUpdateStatus),
                                rows: rows, footer: [.init("home", "Back")])
            canvas.preview = nil
        case .levels:
            guard let library, library.levels.indices.contains(selectedIndex) else { route = .home; rebuild(); return }
            let level = library.levels[selectedIndex]
            let rank = library.levels.filter { $0.rank == level.rank }
            let rankIndex = rank.firstIndex(where: { $0.index == selectedIndex }) ?? 0
            let ranksCount = library is MobileJourneyLibrary ? 1 : Set(library.levels.map(\.rank)).count
            let stats: [String] = selectedPreview.map {
                let s = $0.snapshot
                return ["\(s.total) Lemmings   Save \(s.required)",
                        s.remainingSeconds.map { "Time \($0 / 60):\(String(format: "%02d", $0 % 60))" } ?? "No time limit"]
            } ?? []
            canvas.page = .init(title: level.title,
                                subtitle: loading ? "Loading..." : "\(level.rank)  \(level.number)/\(rank.count)",
                                details: stats,
                                footer: (ranksCount > 1 ? [.init("rankPrevious", "< Rank"), .init("rankNext", "Rank >")] : [])
                                    + [.init("previous", "< Level", enabled: !(library is MobileJourneyLibrary) && rankIndex > 0),
                                         .init("next", "Level >", enabled: !(library is MobileJourneyLibrary) && rankIndex + 1 < rank.count),
                                         .init("favourite", "Favourite", selected: isFavourite(selectedIndex)),
                                         .init("addPlaylist", "Playlist", enabled: catalogue != nil && favouriteIdentity(selectedIndex) != nil)]
                                    + (currentPack != nil && activeRun == nil && library.levels.count > 1 ? [.init("random", "Random 10")] : [])
                                    + [.init("back", "Back"),
                                         .init("play", solved.contains(selectedIndex) ? "Play again" : "Play", enabled: !loading, primary: true)],
                                preview: true, footerColumns: 2)
            if let preview = selectedPreview {
                canvas.preview = MobileBitmapRenderer.image(preview.frame)
                canvas.previewSource = CGRect(x: max(0, min(Double(max(0, preview.frame.width - 320)), preview.origin.x)),
                                              y: 0, width: Double(min(320, preview.frame.width)), height: Double(preview.frame.height))
            }
        case .journey:
            canvas.page = learningPage(subtitle: subtitle); canvas.preview = nil
        case .progression:
            canvas.page = progressionPage(subtitle: subtitle); canvas.preview = nil
        case .techniques:
            canvas.page = techniquePage(subtitle: subtitle); canvas.preview = nil
        case .rankings:
            canvas.page = rankingsPage(subtitle: subtitle); canvas.preview = nil
        case .whatsNew:
            canvas.page = whatsNewPage(); canvas.preview = nil
        case .effectsWelcome:
            canvas.page = effectsWelcomePage(); canvas.preview = nil
        case .telemetryConsent:
            canvas.page = telemetryConsentPage(); canvas.preview = nil
        case .insightsToken:
            canvas.page = insightsTokenPage(); canvas.preview = nil
        case .insightsClear:
            canvas.page = insightsClearPage(); canvas.preview = nil
        case .settings:
            canvas.page = settingsGroupsPage(); canvas.preview = nil
        case let .settingsGroup(group):
            canvas.page = settingsPage(group); canvas.preview = nil
        case .controllerMappings:
            canvas.page = MobileSettingsArt.controllerMappings(mobileSettings); canvas.preview = nil
        case .playInsights:
            canvas.page = insightsDashboardPage(); canvas.preview = nil
        case .hotSeat:
            canvas.page = hotSeatPage(subtitle: subtitle); canvas.preview = nil
        case .hotSeats:
            canvas.page = savedHotSeatsPage(subtitle: subtitle); canvas.preview = nil
        case .records:
            canvas.page = recordsPage(subtitle: subtitle); canvas.preview = nil
        case .achievements:
            canvas.page = achievementsPage(subtitle: subtitle); canvas.preview = nil
        case let .recordLevel(board):
            canvas.page = recordLevelPage(board, subtitle: subtitle); canvas.preview = nil
        case .players:
            canvas.page = playersPage(subtitle: subtitle); canvas.preview = nil
        case .shuffleAll:
            canvas.page = shuffleAllPage(subtitle: subtitle); canvas.preview = nil
        case .collections:
            canvas.page = collectionsPage(subtitle: subtitle); canvas.preview = nil
        case .playlists:
            canvas.page = playlistsPage(subtitle: subtitle); canvas.preview = nil
        case let .playlist(id):
            canvas.page = playlistPage(id, subtitle: subtitle); canvas.preview = nil
        case .addToPlaylist:
            canvas.page = addToPlaylistPage(subtitle: subtitle); canvas.preview = nil
        case .soundtrack:
            let libraries = MobileMusicLibraries.shared
            let packs = libraries.catalogue?.packs ?? []
            let status = libraries.failure ?? (libraries.isDownloading ? "Downloading..." : "\(packs.filter(libraries.isInstalled).count)/\(packs.count)")
            canvas.page = .init(title: "Soundtrack", subtitle: status,
                                rows: packs.map { pack in
                                    let percent = libraries.progress[pack.id].map { "  \(Int($0 * 100))%" }
                                    return .init("lib." + pack.id,
                                                 pack.title + "  " + (percent ?? MobileMusicLibraries.size(pack.bytes)),
                                                 selected: libraries.isInstalled(pack))
                                },
                                footer: [.init("settingsGroup.audio", "Back")])
            canvas.preview = nil
        case .data:
            canvas.page = .init(title: "Game Data", subtitle: subtitle,
                                details: library.map { ["\($0.displayName)", "\($0.levels.count) levels"] } ?? [],
                                footer: [.init("home", "Back"), .init("import", "Import", enabled: !loading, primary: library == nil)])
            canvas.preview = nil
        }
        canvas.previewSource = route == .levels ? canvas.previewSource : nil
        view.setNeedsLayout()
        syncPages()
    }

    /// iPad keeps the Mac carousel in both orientations. Narrow panes use the stacked page.
    private func syncPages() {
        let available = MobileSystemRegions.menuFrame(in: view)
        let coverBrowser = available.width >= 600 && available.height >= 300 && !(library is MobileJourneyLibrary)
        let show = game == nil && route == .levels && coverBrowser && library != nil
        scrollView.isHidden = game != nil || show
        browser.isHidden = !show
        if show, !browserShown, let library {
            browser.frame = view.bounds
            browser.configure(levels: library.levels, selected: selectedIndex)
        }
        browserShown = show
    }

    private func coverArtwork(_ index: Int) async -> CGImage? {
        guard let loader = previewLoader, let preview = try? await loader.load(index),
              let image = MobileBitmapRenderer.image(preview.frame) else { return nil }
        let width = min(320, image.width)
        let x = max(0, min(image.width - width, Int(preview.origin.x)))
        return image.cropping(to: CGRect(x: x, y: 0, width: width, height: image.height))
    }
    func navigate(_ next: Route) {
        if next != .insightsToken {
            mobileInsights.field?.resignFirstResponder(); mobileInsights.field?.text = nil
            mobileInsights.field?.removeFromSuperview(); mobileInsights.field = nil; mobileInsights.token = ""
        }
        if next != .playInsights {
            mobileInsights.task?.cancel(); mobileInsights.loading = false
        }
        learningTask?.cancel(); learningPreparing = false
        searchField.resignFirstResponder()
        if nameDraft != nil, !{ if case .playlist = next { return true }; return next == .players }() { nameDraft = nil; renamingPlayer = false; searchField.text = searchQuery }
        confirmingDelete = false
        previewTask?.cancel(); previewGeneration = UUID(); loading = false; preparingLevel = false
        route = next; notice = ""
        libraryInput.reset()
        if game == nil { becomeFirstResponder() }
        scrollView.setContentOffset(.zero, animated: false)
        rebuild()
    }
    func handle(_ id: String) {
        if handleWelcome(id) || handleInsights(id) { return }
        if handleLearning(id) || handleRankings(id) { return }
        if handleSettings(id) { return }
        switch id {
        case "classic": levelsBackRoute = .home; navigate(.levels); selectLevel(selectedIndex)
        case "home": navigate(.home)
        case "back": navigate(levelsBackRoute)
        case "favourite": toggleFavourite(selectedIndex)
        case "favourites": openFavourites()
        case "fanUpdate": checkForFanPacks()
        case "search":
            if searchField.isFirstResponder { searchField.resignFirstResponder() } else { searchField.becomeFirstResponder() }
            rebuild()
        case "settings": navigate(.settings)
        case "data": navigate(.data)
        case "import": chooseGameData()
        case "resume": resumeSavedRun()
        case "previous": moveLevel(-1)
        case "next": moveLevel(1)
        case "rankPrevious": moveRank(-1)
        case "rankNext": moveRank(1)
        case "play": startLevel(selectedIndex, checkpoint: nil)
        case "soundtrack":
            let libraries = MobileMusicLibraries.shared
            libraries.onChange = { [weak self] in
                guard let self, self.route == .soundtrack else { return }
                self.rebuild()
            }
            navigate(.soundtrack)
        default:
            if handleRecords(id) || handleHotSeat(id) || handleCollections(id) { return }
            if id.hasPrefix("lib."), let pack = MobileMusicLibraries.shared.catalogue?.packs.first(where: { $0.id == String(id.dropFirst(4)) }) {
                let libraries = MobileMusicLibraries.shared
                if libraries.progress[pack.id] != nil { libraries.cancel(pack) }
                else if libraries.isInstalled(pack) { libraries.remove(pack) }
                else { libraries.download(pack) }
                rebuild()
            } else if id.hasPrefix("family."), let family = MobileFamily(rawValue: String(id.dropFirst(7))) {
                openFamily(family)
            } else if id.hasPrefix("pack."), let pack = catalogue?.pack(id: String(id.dropFirst(5))) {
                openPack(pack, back: route)
            }
        }
    }

    /// The pack and level key that identify the selected level in the favourites store.
    func favouriteIdentity(_ index: Int) -> (pack: String, level: String)? {
        guard let library else { return nil }
        if let list = library as? MobileFavouritesLibrary, let origin = list.origin(of: index),
           let source = catalogue?.pack(id: origin.pack), let real = try? catalogue?.library(for: source) {
            return (origin.pack, real.levelKey(at: origin.index))
        }
        if let journey = library as? MobileJourneyLibrary, let origin = try? journey.origin(of: index) {
            return (origin.pack, origin.library.levelKey(at: origin.index))
        }
        guard let pack = currentPack else { return nil }
        return (pack.id, library.levelKey(at: index))
    }

    func isFavourite(_ index: Int) -> Bool {
        favouriteIdentity(index).map { favourites.contains(pack: $0.pack, level: $0.level) } ?? false
    }

    private func toggleFavourite(_ index: Int) {
        guard let identity = favouriteIdentity(index) else { return }
        favourites.toggle(pack: identity.pack, level: identity.level)
        saveSharedCollections()
        browser.setFavourite(isFavourite(index))
        rebuild()
    }

    private func openFavourites() {
        guard let catalogue else { return }
        let list = MobileFavouritesLibrary(favourites: favourites, catalogue: catalogue)
        guard !list.levels.isEmpty else { return }
        library = list
        currentPack = nil
        let ports = catalogue.portsRoot, fan = catalogue.fanFolders, saved = favourites
        previewLoader = MobileMenuPreviewLoader {
            MobileFavouritesLibrary(favourites: saved, catalogue: MobileCatalogue(portsRoot: ports, fanFolders: fan))
        }
        selectedIndex = 0; selectedPreview = nil; browserShown = false
        levelsBackRoute = .home
        navigate(.levels); selectLevel(0)
    }

    private func checkForFanPacks() {
        guard !fanUpdating, let catalogue else { return }
        fanUpdating = true
        fanUpdateStatus = "CHECKING..."
        rebuild()
        let existing = catalogue.packs(in: .fan).compactMap { pack -> URL? in
            if case let .fan(file) = pack.source { return file } else { return nil }
        }
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true) else { return }
        let destination = support.appendingPathComponent("Fan Levels", isDirectory: true)
        Task {
            let outcome = await FanPackUpdater().check(existing: existing, destination: destination)
            fanUpdating = false
            fanUpdateStatus = outcome.status
            measureMobileFanPacks()
            rebuild()
        }
    }

    private func solvedMark(_ pack: MobileContentPack) -> String {
        let done = solvedLevels(for: pack.id).count
        guard done > 0 else { return "" }
        return pack.levelCount.map { "  \(done)/\($0)" } ?? "  \(done)"
    }

    private static func makeCatalogue() -> MobileCatalogue? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let ports = resources.appendingPathComponent("Ports", isDirectory: true)
        guard FileManager.default.fileExists(atPath: ports.path) else { return nil }
        var fan = [resources.appendingPathComponent("LevelPacks", isDirectory: true)]
        if let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: false) {
            fan.append(support.appendingPathComponent("Fan Levels", isDirectory: true))
        }
        return MobileCatalogue(portsRoot: ports, fanFolders: fan)
    }

    private func openFamily(_ family: MobileFamily) {
        guard let catalogue else { return }
        let packs = catalogue.packs(in: family)
        if packs.count == 1, let pack = packs.first { openPack(pack, back: .home) }
        else { navigate(.family(family)) }
    }

    /// Makes a pack the current library and shows its levels.
    private func openPack(_ pack: MobileContentPack, back: Route, navigateToLevels: Bool = true) {
        guard let catalogue else { return }
        do {
            library = try catalogue.library(for: pack)
            currentPack = pack
            let ports = catalogue.portsRoot, fan = catalogue.fanFolders
            previewLoader = MobileMenuPreviewLoader { try MobileCatalogue(portsRoot: ports, fanFolders: fan).library(for: pack) }
            selectedIndex = 0; selectedPreview = nil; browserShown = false
            levelsBackRoute = back
            if navigateToLevels { navigate(.levels); selectLevel(0) }
        } catch { notice = error.localizedDescription; rebuild() }
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
    func selectLevel(_ index: Int) {
        if library is MobileJourneyLibrary, let run = learning.run, index != run.currentIndex { return }
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
            if let classic = library as? ClassicMobileLibrary {
                let directory = classic.directory
                previewLoader = MobileMenuPreviewLoader { try ClassicMobileLibrary(directory: directory) }
            }
            selectedIndex = 0; selectedPreview = nil
            if library == nil, catalogue == nil { route = .data }
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
    func loadCheckpoint() {
        guard let checkpointStore else { return }
        let owner = profiles.activeID, scope = hotSeat?.scope
        Task {
            do {
                let checkpoint = try await checkpointStore.load(owner: owner, scope: scope)
                guard profiles.activeID == owner, hotSeat?.scope == scope else { return }
                pendingCheckpoint = checkpoint; rebuild()
            }
            catch {
                guard profiles.activeID == owner, hotSeat?.scope == scope else { return }
                pendingCheckpoint = nil; notice = error.localizedDescription; rebuild()
            }
        }
    }
    private func resumeSavedRun() {
        guard let checkpoint = pendingCheckpoint, checkpointMatchesSession(checkpoint) else { return }
        if let run = learning.run, let catalogue {
            let queue = MobileJourneyLibrary(entries: run.entries, name: run.pool.summary, catalogue: catalogue)
            if let content = try? queue.loadLevel(at: run.currentIndex), content.session.levelIdentifier == checkpoint.levelIdentifier {
                openLearningRun(checkpoint: checkpoint); return
            }
        }
        if let catalogue, let pack = catalogue.pack(forLevelIdentifier: checkpoint.levelIdentifier) {
            openPack(pack, back: .home, navigateToLevels: false)
        }
        startLevel(checkpoint.levelIndex, checkpoint: checkpoint)
    }
    func startLevel(_ index: Int, checkpoint: MobileCheckpointEnvelope?, restoringMatchingCheckpoint: Bool = false) {
        guard !preparingLevel, let library, let checkpointStore else { return }
        guard let previewLoader else { return }
        previewTask?.cancel()
        let generation = UUID(); previewGeneration = generation
        preparingLevel = true; loading = true; rebuild()
        previewTask = Task {
            do {
                let prepared = try await previewLoader.prepare(index)
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; preparingLevel = false
                let matching = restoringMatchingCheckpoint && checkpoint?.levelIdentifier != prepared.content.session.levelIdentifier
                    ? nil : checkpoint
                presentPreparedLevel(index, checkpoint: matching, library: library,
                                     checkpointStore: checkpointStore, content: prepared.content)
            } catch {
                guard !Task.isCancelled, previewGeneration == generation else { return }
                loading = false; preparingLevel = false
                if let game { game.showPreparationError(error.localizedDescription) }
                else { notice = error.localizedDescription; rebuild() }
            }
        }
    }
    private func presentPreparedLevel(_ index: Int, checkpoint: MobileCheckpointEnvelope?, library: any MobileGameLibrary,
                                      checkpointStore: MobileCheckpointStore, content: MobileLevelContent) {
        do {
            if let checkpoint {
                guard checkpoint.engine == content.session.engineIdentifier,
                      checkpoint.engineFingerprint == content.session.engineFingerprint,
                      checkpoint.levelIdentifier == content.session.levelIdentifier,
                      checkpoint.levelFingerprint == content.session.levelFingerprint else { throw MobileSessionError.changedLevel }
                // A shared run resumes only in its own session, with the player who started it.
                guard checkpointMatchesSession(checkpoint) else { throw MobileSessionError.changedLevel }
                try content.session.restoreCheckpointPayload(checkpoint.payload)
                if let owner = checkpoint.owner, hotSeat?.players.contains(owner) == true { handOver(to: owner) }
            }
            levelStarted(index)
            // Playlist and shuffle results do not advance campaign or pack progress.
            let inLearning = library is MobileJourneyLibrary
            let inRun = activeRun != nil || inLearning
            let next = MobileGameViewController(summary: content.summary, session: content.session,
                                               checkpointStore: checkpointStore, restoredCheckpoint: checkpoint,
                                               turn: currentTurn())
            let journeyMusic = inLearning && self.learning.run?.pool.id.hasPrefix("learning-") == true
            var sourceTitles = library.levels.map(\.title)
            if let queue = library as? MobileJourneyLibrary, let origin = try? queue.origin(of: index) { sourceTitles = origin.library.levels.map(\.title) }
            else if let queue = library as? MobileFavouritesLibrary, let origin = queue.origin(of: index),
                    let pack = catalogue?.pack(id: origin.pack), let source = try? catalogue?.library(for: pack) { sourceTitles = source.levels.map(\.title) }
            let fullJourney = self.bundledJourney
            let fullPosition = journeyMusic ? (library as? MobileJourneyLibrary).flatMap { queue in
                fullJourney?.lessons.firstIndex { $0.entry.identity == queue.entries[index].identity }
            } : nil
            next.musicContext = MobileMusicContext(scorePosition: fullPosition, titles: journeyMusic ? (fullJourney?.lessons.map { $0.entry.levelNameSnapshot } ?? sourceTitles) : sourceTitles,
                isFan: content.session.levelIdentifier.hasPrefix("fan/"), isLearningJourney: journeyMusic)
            next.canDefer = inLearning
            next.soloOwnerID = profiles.activeID
            let attemptID = checkpoint?.runID ?? next.recordRunID
            let ownerID = checkpoint?.owner ?? hotSeat?.turn ?? profiles.activeID
            let recordLevel = mobileArcadeLevel(session: content.session, summary: content.summary,
                pack: favouriteIdentity(index)?.pack ?? library.displayName)
            if !inRun, library.levels.indices.contains(index + 1), arcadeStore.records.levelSkips(profileID: ownerID).available > 0 {
                next.onSkipLevel = { [weak self] in self?.arcadeStore.spendLevelSkip(on: recordLevel, profileID: ownerID) ?? false }
            }
            if checkpoint == nil {
                guard arcadeStore.beginAttempt(id: attemptID, profileID: ownerID, level: recordLevel,
                                               previousID: game?.recordRunID) else {
                    throw NSError(domain: "MobileRecords", code: 1, userInfo: [NSLocalizedDescriptionKey:
                        arcadeStore.storageError ?? "The attempt was not saved."])
                }
            }
            AnonymousTelemetry.shared.start(recordLevel, hotSeat: hotSeat != nil, attemptID: attemptID)
            next.onRecordCompletion = { [weak self, weak session = content.session] snapshot in
                guard let self, let session else { return ([], "Records are not available.") }
                if inLearning {
                    do { try self.recordLearningResult(snapshot) }
                    catch { return ([], error.localizedDescription) }
                }
                let run = ArcadeRun(id: attemptID, profileID: ownerID, level: recordLevel,
                    saved: snapshot.saved, didWin: snapshot.didWin, skills: session.assignedSkills,
                    seconds: Double(snapshot.tick) / session.ticksPerSecond, assisted: session.usedRewind,
                    telemetry: self.mobileTelemetry(session: session, snapshot: snapshot))
                return self.recordMobileCompletion(run, session: session)
            }
            next.onResultAwards = { [weak self] in self?.mobileResultAwards(runID: attemptID) ?? (0, false) }
            next.onHandover = { [weak self] player in self?.handOver(to: player) ?? false }
            next.onCompleted = { [weak self] snapshot in
                guard let self else { return }
                if inLearning { return }
                guard snapshot.didWin else { return }
                if inRun { self.finishRunIfNeeded(afterLast: index); return }
                var pack = self.currentPack?.id, real = index
                if let list = library as? MobileFavouritesLibrary, let origin = list.origin(of: index) {
                    pack = origin.pack; real = origin.index
                }
                var completed = self.solvedLevels(for: pack); completed.insert(real)
                UserDefaults.standard.set(completed.sorted(),
                                          forKey: self.progressKey(for: pack, fallback: self.library?.displayName ?? "classic"))
            }
            next.onExit = { [weak self] action in
                guard let self else { return }
                switch action {
                case .library:
                    self.previewTask?.cancel(); self.previewGeneration = UUID()
                    self.loading = false; self.preparingLevel = false
                    self.game?.willMove(toParent: nil); self.game?.view.removeFromSuperview(); self.game?.removeFromParent()
                    self.game = nil; self.loadCheckpoint(); self.rebuild()
                    self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                case .retry: self.startLevel(index, checkpoint: nil)
                case .next:
                    if inLearning {
                        do {
                            if try !self.advanceLearningRun() {
                                self.navigate(.journey); self.game?.onExit?(.library); return
                            }
                        } catch { self.game?.showPreparationError(error.localizedDescription); return }
                    }
                    if library.levels.indices.contains(index + 1) { self.startLevel(index + 1, checkpoint: nil) }
                    else { self.finishRunIfNeeded(afterLast: index); self.handle("home"); self.game?.onExit?(.library) }
                }
            }
            let previous = game
            addChild(next); next.view.frame = view.bounds
            next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(next.view); next.didMove(toParent: self)
            game = next; syncPages()
            previous?.willMove(toParent: nil); previous?.view.removeFromSuperview(); previous?.removeFromParent()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        } catch {
            if let game { game.showPreparationError(error.localizedDescription) }
            else { notice = error.localizedDescription; rebuild() }
        }
    }
}
#endif
