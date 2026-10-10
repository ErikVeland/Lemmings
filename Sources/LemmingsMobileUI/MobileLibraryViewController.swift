#if os(iOS)
import LemmingsMobileCore
import UIKit
import UniformTypeIdentifiers

@MainActor final class MobileLibraryViewController: UIViewController, UIDocumentPickerDelegate {
    private let titleLabel = MobilePixelLabel()
    private let statusLabel = MobilePixelLabel()
    private let importButton = MobilePixelButton()
    private let resumeButton = MobilePixelButton()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private var store: MobileContentStore?
    private var checkpointStore: MobileCheckpointStore?
    private var library: ClassicMobileLibrary?
    private var levelViews: [UIView] = []
    private var pendingCheckpoint: MobileCheckpointEnvelope?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        titleLabel.text = "ULTIMATE LEMMINGS 1.3"
        titleLabel.palette = .green
        titleLabel.maximumScale = 3
        view.addSubview(titleLabel)

        statusLabel.maximumScale = 2
        view.addSubview(statusLabel)

        importButton.title = "IMPORT GAME DATA"
        importButton.onPress = { [weak self] in self?.chooseGameData() }
        view.addSubview(importButton)

        resumeButton.title = "RESUME SAVED RUN"
        resumeButton.isPrimary = true
        resumeButton.isHidden = true
        resumeButton.onPress = { [weak self] in self?.resumeSavedRun() }
        view.addSubview(resumeButton)

        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)

        do {
            let configured = try MobileContentStore()
            store = configured
            checkpointStore = MobileCheckpointStore(url: configured.checkpointURL)
            reloadLibrary()
        } catch {
            show(error.localizedDescription, warning: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaLayoutGuide.layoutFrame
        titleLabel.frame = CGRect(x: safe.minX + 12, y: safe.minY + 8, width: safe.width - 24, height: 34)
        var y = titleLabel.frame.maxY + 8
        importButton.frame = CGRect(x: safe.minX + 12, y: y, width: safe.width - 24, height: 48)
        y = importButton.frame.maxY + 6
        if !resumeButton.isHidden {
            resumeButton.frame = CGRect(x: safe.minX + 12, y: y, width: safe.width - 24, height: 48)
            y = resumeButton.frame.maxY + 6
        }
        statusLabel.frame = CGRect(x: safe.minX + 12, y: y, width: safe.width - 24, height: 30)
        y = statusLabel.frame.maxY + 6
        scrollView.frame = CGRect(x: safe.minX, y: y, width: safe.width, height: max(0, safe.maxY - y))
        layoutLevelViews()
    }

    private func reloadLibrary() {
        do {
            library = try store?.loadLibrary()
            rebuildLevelViews()
            if let library {
                show("\(library.dataSet.name)  \(library.levels.count) LEVELS", warning: false)
            } else {
                show("IMPORT YOUR ORIGINAL DOS DATA FOLDER", warning: false)
            }
            loadCheckpoint()
        } catch {
            library = nil
            rebuildLevelViews()
            show(error.localizedDescription, warning: true)
        }
    }

    private func rebuildLevelViews() {
        levelViews.forEach { $0.removeFromSuperview() }
        levelViews = []
        guard let library else { return }
        var lastRank: String?
        for summary in library.levels {
            if summary.rank != lastRank {
                let header = MobilePixelLabel()
                header.text = summary.rank
                header.palette = .green
                header.alignment = .left
                header.maximumScale = 2
                contentView.addSubview(header)
                levelViews.append(header)
                lastRank = summary.rank
            }
            let button = MobilePixelButton()
            button.title = "\(summary.number)  \(summary.title)"
            button.accessibilityLabel = "\(summary.rank) \(summary.number), \(summary.title)"
            button.onPress = { [weak self] in self?.startLevel(summary.index, checkpoint: nil) }
            contentView.addSubview(button)
            levelViews.append(button)
        }
        view.setNeedsLayout()
    }

    private func layoutLevelViews() {
        let width = max(0, scrollView.bounds.width - 24)
        var y = 4.0
        for item in levelViews {
            let isHeader = item is MobilePixelLabel
            item.frame = CGRect(x: 12, y: y, width: width, height: isHeader ? 34 : 48)
            y = item.frame.maxY + (isHeader ? 2 : 5)
        }
        contentView.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: y + 12)
        scrollView.contentSize = contentView.bounds.size
    }

    private func chooseGameData() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let source = urls.first, let store else { return }
        show("IMPORTING AND VERIFYING...", warning: false)
        importButton.isEnabled = false
        let accessed = source.startAccessingSecurityScopedResource()
        Task {
            defer {
                if accessed { source.stopAccessingSecurityScopedResource() }
                importButton.isEnabled = true
            }
            let result = await Task.detached(priority: .userInitiated) {
                Result { try store.install(directory: source) }
            }.value
            switch result {
            case .success:
                reloadLibrary()
            case let .failure(error):
                show(error.localizedDescription, warning: true)
            }
        }
    }

    private func loadCheckpoint() {
        guard let checkpointStore else { return }
        Task {
            do {
                let checkpoint = try await checkpointStore.load()
                pendingCheckpoint = checkpoint
                resumeButton.isHidden = checkpoint == nil
                view.setNeedsLayout()
            } catch {
                pendingCheckpoint = nil
                resumeButton.isHidden = true
                show(error.localizedDescription, warning: true)
            }
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
                      checkpoint.levelFingerprint == content.session.levelFingerprint else {
                    throw MobileSessionError.changedLevel
                }
                try content.session.restoreCheckpointPayload(checkpoint.payload)
            }
            let game = MobileGameViewController(
                summary: content.summary,
                session: content.session,
                checkpointStore: checkpointStore,
                restoredCheckpoint: checkpoint
            )
            game.modalPresentationStyle = .fullScreen
            game.onExit = { [weak self, weak game] action in
                game?.dismiss(animated: true) {
                    guard let self else { return }
                    switch action {
                    case .library:
                        self.loadCheckpoint()
                    case .retry:
                        self.startLevel(index, checkpoint: nil)
                    case .next:
                        if library.levels.indices.contains(index + 1) {
                            self.startLevel(index + 1, checkpoint: nil)
                        } else {
                            self.loadCheckpoint()
                        }
                    }
                }
            }
            present(game, animated: true)
        } catch {
            show(error.localizedDescription, warning: true)
        }
    }

    private func show(_ message: String, warning: Bool) {
        statusLabel.text = message
        statusLabel.palette = warning ? .warning : .blue
        statusLabel.accessibilityLabel = message
    }
}
#endif
