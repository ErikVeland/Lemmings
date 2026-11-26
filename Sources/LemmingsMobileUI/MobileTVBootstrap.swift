#if os(tvOS)
import LemmingsGameArt
import NxlvKit
import LemmingsMobileCore
import LemmingsTVCore
import UIKit

@MainActor final class MobileTVBootstrap: UIViewController {
    let configuration: LemmingsMobileConfiguration
    var catalogue: MobileCatalogue?
    var resourceNotice: String?
    private let canvas = MobileMenuCanvas()
    private let scrollView = UIScrollView()
    private let loadingIntro = MobileLoadingIntro()
    private var content: UIViewController?
    private var migrating = false
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { content.map { [$0] } ?? [canvas] }

    init(configuration: LemmingsMobileConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(scrollView)
        scrollView.addSubview(canvas)
        canvas.onAction = { [weak self] id in
            guard let self, !self.migrating, self.content == nil else { return }
            if id == "continue" { self.openLibrary() }
            else if id == "retry" { self.migrate() }
        }
        migrate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = MobileSystemRegions.menuFrame(in: view)
        let size = canvas.size(width: scrollView.bounds.width, minimumHeight: scrollView.bounds.height)
        canvas.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
        content?.view.frame = view.bounds
    }

    private func migrate() {
        guard !migrating else { return }
        migrating = true
        canvas.page = .init(title: L10n.text("Lemmings"), subtitle: L10n.text("Loading..."))
        loadingIntro.start(in: view, configuration: configuration, message: L10n.text("Loading..."),
                           reduceMotion: UIAccessibility.isReduceMotionEnabled) { [weak self] in
            self?.migrating == true
        }
        Task { [weak self] in
            guard let self else { return }
            defer {
                loadingIntro.stop()
                migrating = false
            }
            do {
                let store = try MobileContentStore()
                try await TVMobileMigration.migrate(defaults: .standard, players: .standard(profile: "_players"),
                    legacyCheckpoint: MobileCheckpointStore(url: TVMobileMigration.legacyCheckpointURL),
                    destination: MobileCheckpointStore(url: store.checkpointURL))
                openLibrary()
            } catch {
                canvas.page = GameRecoveryArt.migrationFailure(error.localizedDescription)
                view.setNeedsLayout()
                view.layoutIfNeeded()
                scrollView.setContentOffset(.zero, animated: false)
                setNeedsFocusUpdate()
                updateFocusIfNeeded()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loadingIntro.stop()
    }

    private func openLibrary() {
        guard content == nil else { return }
        let library = MobileLibraryViewController(configuration: configuration)
        library.catalogue = catalogue
        if let resourceNotice { library.notice = resourceNotice }
        addChild(library)
        library.view.frame = view.bounds
        view.addSubview(library.view)
        library.didMove(toParent: self)
        content = library
        canvas.isHidden = true
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }
}
#endif
