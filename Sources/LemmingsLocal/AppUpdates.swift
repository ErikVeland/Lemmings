#if os(macOS)
import AppKit
import Sparkle

@MainActor protocol AppUpdateChecking: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
    func observeAvailability(_ action: @escaping @MainActor () -> Void) -> NSKeyValueObservation?
}

extension SPUUpdater: AppUpdateChecking {
    func observeAvailability(_ action: @escaping @MainActor () -> Void) -> NSKeyValueObservation? {
        observe(\.canCheckForUpdates, options: [.new]) { _, _ in
            // Sparkle can become ready during its own delegate callback. Let it finish first.
            Task { @MainActor in action() }
        }
    }
}

/// Sparkle owns download verification and installation. The home screen offers a quiet reminder.
@MainActor final class AppUpdates: NSObject, @preconcurrency SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    var onChange: (() -> Void)?
    private(set) var availableVersion: String?
    private(set) var isDownloaded = false
    private(set) var isDownloading = false
    private(set) var isUpdateRequested = false
    var isBusy: Bool { isDownloading || isUpdateRequested }
    private var automaticNotesVersion: String?
    private var pendingCheck = false
    private var pendingAutomaticCheck = false
    private var started = false
    private var availabilityObservation: NSKeyValueObservation?
    private let suppliedUpdater: (any AppUpdateChecking)?
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
    private var checker: any AppUpdateChecking { suppliedUpdater ?? controller.updater }

    init(updater: (any AppUpdateChecking)? = nil) {
        suppliedUpdater = updater
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        availabilityObservation = checker.observeAvailability { [weak self] in self?.performPendingCheck() }
    }

    func showUpdate() {
        isUpdateRequested = true
        onChange?()
        requestCheck(userInitiated: true)
    }

    private func requestCheck(userInitiated: Bool) {
        start()
        // Background checks and automatic downloads can temporarily reject manual checks.
        // Keep one request from either entry point until Sparkle can show its update UI.
        if userInitiated { pendingCheck = true } else { pendingAutomaticCheck = true }
        performPendingCheck()
    }

    private func performPendingCheck() {
        guard pendingCheck || pendingAutomaticCheck, checker.canCheckForUpdates else { return }
        pendingCheck = false
        pendingAutomaticCheck = false
        checker.checkForUpdates()
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool) -> Bool { immediateFocus }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // Announce discovery before an automatic download creates its alert.
        setAvailable(item, downloaded: availableVersion == item.displayVersionString && isDownloaded)
    }
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        updateWillBePresented(update, downloaded: state.stage != .notDownloaded,
            automaticallyShowNotes: !handleShowingUpdate && !state.userInitiated && state.stage != .notDownloaded)
    }
    func updateWillBePresented(_ update: SUAppcastItem, downloaded: Bool, automaticallyShowNotes: Bool) {
        isUpdateRequested = false
        // Refresh the discovery reminder with the alert's download state.
        setAvailable(update, downloaded: downloaded)
        if automaticallyShowNotes, automaticNotesVersion != update.versionString {
            automaticNotesVersion = update.versionString
            let version = update.versionString
            DispatchQueue.main.async { [weak self] in
                guard let self, self.automaticNotesVersion == version, self.availableVersion != nil else { return }
                self.requestCheck(userInitiated: false)
            }
        }
    }
    func standardUserDriverWillFinishUpdateSession() { clear() }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        // A successful background cycle can leave an update waiting for the player.
        if error != nil { clear() }
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) { clear() }
    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        isUpdateRequested = false
        isDownloading = true
        setAvailable(item, downloaded: false)
    }
    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        isUpdateRequested = false
        setAvailable(item, downloaded: true)
    }
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        isUpdateRequested = false
        isDownloading = false
        setAvailable(item, downloaded: false)
    }
    func userDidCancelDownload(_ updater: SPUUpdater) {
        isUpdateRequested = false
        isDownloading = false
        onChange?()
    }
    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
        forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if choice == .skip { clear() }
    }
    private func setAvailable(_ item: SUAppcastItem, downloaded: Bool) {
        guard !item.isInformationOnlyUpdate, item.fileURL != nil else { clear(); return }
        availableVersion = item.displayVersionString
        isDownloaded = downloaded
        if downloaded { isDownloading = false }
        onChange?()
    }
    private func clear() {
        availableVersion = nil
        isDownloaded = false
        isDownloading = false
        isUpdateRequested = false
        automaticNotesVersion = nil
        pendingAutomaticCheck = false
        onChange?()
    }
}
#endif
