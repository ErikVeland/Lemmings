import AppKit
import Sparkle

/// Sparkle owns download verification and installation. The home screen offers a quiet reminder.
@MainActor final class AppUpdates: NSObject, @preconcurrency SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    var onChange: (() -> Void)?
    private(set) var availableVersion: String?
    private(set) var isDownloaded = false
    private var automaticNotesVersion: String?
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)

    func start() { _ = controller }
    func showUpdate() { controller.checkForUpdates(nil) }
    var supportsGentleScheduledUpdateReminders: Bool { true }
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool) -> Bool { false }
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        setAvailable(update, downloaded: state.stage != .notDownloaded)
        if !handleShowingUpdate, !state.userInitiated, state.stage != .notDownloaded,
           automaticNotesVersion != update.versionString {
            automaticNotesVersion = update.versionString
            // Wait until Sparkle has finished its callback before bringing its notes forward.
            DispatchQueue.main.async { [weak self] in self?.showUpdate() }
        }
    }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        setAvailable(item, downloaded: false)
    }
    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        setAvailable(item, downloaded: true)
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { clear() }
    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
        forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if choice == .skip { clear() }
    }
    private func setAvailable(_ item: SUAppcastItem, downloaded: Bool) {
        guard !item.isInformationOnlyUpdate, item.fileURL != nil else { clear(); return }
        availableVersion = item.displayVersionString
        isDownloaded = downloaded
        onChange?()
    }
    private func clear() { availableVersion = nil; isDownloaded = false; onChange?() }
}
