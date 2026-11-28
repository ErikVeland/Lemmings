#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit
import UIKit

@MainActor final class MobileAboutState {
    var content: AboutContent?
    var section = MobileAboutArt.Section.overview
    var releaseIndex: Int?
    var historyOffset = CGPoint.zero
    var contributors: String?
    var status: String?
    var showsRetry = false
    var task: Task<Void, Never>?
    var generation = UUID()
    let defaults: UserDefaults
    var loadContributors: @MainActor () async throws -> String

    init(content: AboutContent? = nil, defaults: UserDefaults = .standard,
         loadContributors: @escaping @MainActor () async throws -> String = { try await AboutContent.loadContributors() }) {
        self.content = content
        self.defaults = defaults
        self.loadContributors = loadContributors
    }

    func prepare(resources: URL) {
        cancelContributors()
        if content == nil { content = AboutContent(resources: resources) }
        section = .overview
        releaseIndex = nil
        historyOffset = .zero
        contributors = defaults.string(forKey: AboutContent.contributorCacheKey) ?? content?.contributors
        status = nil
        showsRetry = false
    }

    func cancelContributors() {
        if task != nil { status = nil }
        task?.cancel()
        task = nil
        generation = UUID()
    }

    func refreshContributors(isActive: @escaping @MainActor () -> Bool = { true },
                             onChange: @escaping @MainActor () -> Void) {
        cancelContributors()
        status = L10n.text("Loading...")
        showsRetry = false
        let requestGeneration = generation
        let load = loadContributors
        onChange()
        task = Task { [weak self] in
            do {
                let markdown = try await load()
                guard !Task.isCancelled, isActive(), let self, self.generation == requestGeneration else { return }
                self.defaults.set(markdown, forKey: AboutContent.contributorCacheKey)
                self.contributors = markdown
                self.status = nil
                self.showsRetry = false
            } catch {
                guard !Task.isCancelled, isActive(), let self, self.generation == requestGeneration else { return }
                self.status = L10n.text("Saved list · Offline")
                self.showsRetry = true
            }
            guard isActive(), let self, self.generation == requestGeneration else { return }
            self.task = nil
            onChange()
        }
    }

    deinit {
        task?.cancel()
    }
}

extension MobileLibraryViewController {
    func prepareAbout() {
        mobileAbout.prepare(resources: Bundle.main.resourceURL ?? Bundle.main.bundleURL)
    }

    func aboutPage() -> GameFrontEnd.Page {
        let name = configuration == .ultimateLemmix && !GameResources.hasRestoredOriginalAssets
            ? "Ultimate Lemmix" : "Ultimate Lemmings"
        return MobileAboutArt.page(productName: name,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            showsLixCredits: configuration == .ultimateLemmix || GameArtworkResources.lixArtwork != nil,
            content: mobileAbout.content ?? .init(), section: mobileAbout.section,
            selectedRelease: mobileAbout.releaseIndex, contributors: mobileAbout.contributors,
            contributorStatus: mobileAbout.status, allowsContributorRetry: mobileAbout.showsRetry,
            showsSupportAction: developerTip == nil, showsTipAction: developerTip != nil)
    }

    func cancelAboutContributors() {
        mobileAbout.cancelContributors()
    }

    func refreshAboutContributors() {
        guard route == .about else { return }
        mobileAbout.refreshContributors(isActive: { [weak self] in self?.route == .about }) { [weak self] in
            guard let self, self.route == .about, self.mobileAbout.section == .contributors else { return }
            self.rebuild()
        }
    }

    func handleAbout(_ id: String) -> Bool {
        if handleDeveloperTip(id) { return true }
        if id == "about" {
            guard game == nil else { return true }
            let inSettings: Bool
            switch route {
            case .settings, .settingsGroup: inSettings = true
            default: inSettings = false
            }
            guard inSettings else { return true }
            prepareAbout()
            navigate(.about)
            view.layoutIfNeeded()
            canvas.focusAction("navigation.back")
            refreshAboutContributors()
            return true
        }
        if id == "aboutForumsBack" || id == "aboutSupportBack" {
            guard route == .aboutForums || route == .support else { return true }
            navigate(.about)
            if mobileAbout.status == nil { refreshAboutContributors() }
            return true
        }
        guard route == .about else { return false }
        if id.hasPrefix("aboutSection."),
           let section = MobileAboutArt.Section(rawValue: String(id.dropFirst("aboutSection.".count))) {
            mobileAbout.section = section
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
            view.layoutIfNeeded()
            canvas.focusAction(id)
            return true
        }
        if id.hasPrefix("aboutRelease."), let index = Int(id.dropFirst("aboutRelease.".count)),
           mobileAbout.section == .history,
           let history = mobileAbout.content?.versionHistory,
           AboutContent.releases(markdown: history).indices.contains(index) {
            mobileAbout.historyOffset = scrollView.contentOffset
            mobileAbout.releaseIndex = index
            scrollView.setContentOffset(.zero, animated: false)
            rebuild()
            view.layoutIfNeeded()
            canvas.focusAction("navigation.back")
            return true
        }
        switch id {
        case "aboutHistoryBack":
            let index = mobileAbout.releaseIndex
            mobileAbout.releaseIndex = nil
            rebuild()
            view.layoutIfNeeded()
            let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(CGPoint(x: 0, y: min(maximum, max(0, mobileAbout.historyOffset.y))), animated: false)
            if let index { canvas.focusAction("aboutRelease.\(index)") }
        case "aboutRetry":
            refreshAboutContributors()
        case "aboutBack":
            navigate(previousRoute ?? .settings)
        case "aboutForums":
            #if os(tvOS)
            showAboutForumsCode()
            #else
            UIApplication.shared.open(AboutContent.forumsURL, options: [:]) { [weak self] opened in
                guard !opened else { return }
                Task { @MainActor [weak self] in
                    if self?.route == .about { self?.showAboutForumsCode() }
                }
            }
            #endif
        default:
            return false
        }
        return true
    }

    private func showAboutForumsCode() {
        navigate(.aboutForums)
        view.layoutIfNeeded()
        canvas.focusAction("navigation.back")
    }
}
#endif
