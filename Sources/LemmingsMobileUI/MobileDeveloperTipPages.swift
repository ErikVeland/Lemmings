#if os(iOS) || os(tvOS)
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import UIKit

enum MobileSupportPolicy {
    static func usesTipPage(storeBuild: Bool, configuration: LemmingsMobileConfiguration) -> Bool {
        #if ULTIMATE_LEMMIX_STORE
        true
        #else
        storeBuild || configuration == .ultimateLemmix
        #endif
    }

    static func settingsActions(usesTipPage: Bool) -> [GameFrontEnd.Action] {
        [MobileAboutArt.action] + MobileSettingsArt.aboutActions.filter {
            !usesTipPage || $0.id != "donate"
        }
    }
}

struct MobileSupportPage {
    let page: GameFrontEnd.Page
    let preview: CGImage?

    init(tipPage: GameFrontEnd.Page?, returningToAbout: Bool) {
        if let tipPage {
            page = tipPage
            preview = nil
        } else {
            var page = GameSupport.page
            if returningToAbout {
                page.footer = [.init("aboutSupportBack", L10n.text("Back"), backNavigation: true)]
            }
            self.page = page
            preview = GameSupport.qrCode
        }
    }
}

@MainActor final class MobileDeveloperTipState {
    let service: DeveloperTipService
    private(set) var task: Task<Void, Never>?
    private var generation = UUID()
    private var isActive: (@MainActor () -> Bool)?

    init(service: DeveloperTipService) {
        self.service = service
    }

    var page: GameFrontEnd.Page {
        DeveloperTipArt.page(state: service.state, product: service.product,
                             canPurchase: service.canPurchase)
    }

    func begin(isActive: @escaping @MainActor () -> Bool,
               onChange: @escaping @MainActor () -> Void) {
        end()
        let current = generation
        self.isActive = isActive
        service.onChange = { [weak self] in
            guard let self, self.generation == current, isActive() else { return }
            onChange()
        }
        reload()
    }

    private func reload() {
        task?.cancel()
        let current = generation
        let service = service
        task = Task { [weak self] in
            await service.loadProduct()
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.task = nil
        }
    }

    @discardableResult func handle(_ id: String) -> Bool {
        guard isActive?() == true, page.footer.contains(where: { $0.id == id && $0.enabled }) else { return false }
        switch id {
        case "developerTip.buy", "developerTip.buyAgain":
            guard service.canPurchase else { return false }
            let service = service
            Task { await service.purchase() }
        case "developerTip.retry":
            reload()
        default:
            return false
        }
        return true
    }

    func end() {
        generation = UUID()
        isActive = nil
        service.onChange = nil
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

extension MobileLibraryViewController {
    var isDeveloperTipRoute: Bool {
        route == .developerTip || (route == .support && developerTip != nil)
    }

    func activateDeveloperTip() {
        guard isDeveloperTipRoute, game == nil, let developerTip else { return }
        developerTip.begin(isActive: { [weak self] in
            self?.isDeveloperTipRoute == true && self?.game == nil
        }, onChange: { [weak self] in
            guard let self, self.isDeveloperTipRoute, self.game == nil else { return }
            self.rebuild()
        })
    }

    func showDeveloperTip() {
        guard route == .about, game == nil, developerTip != nil else { return }
        navigate(.developerTip)
        guard route == .developerTip else { return }
        activateDeveloperTip()
        view.layoutIfNeeded()
        canvas.focusAction("navigation.back")
    }

    func handleDeveloperTip(_ id: String) -> Bool {
        if id == "aboutTip" {
            showDeveloperTip()
            return true
        }
        guard id.hasPrefix("developerTip.") else { return false }
        guard isDeveloperTipRoute, game == nil else { return true }
        switch id {
        case "developerTip.back":
            navigate(.about)
            if mobileAbout.status == nil { refreshAboutContributors() }
        case "developerTip.buy", "developerTip.buyAgain", "developerTip.retry":
            developerTip?.handle(id)
        default:
            break
        }
        return true
    }
}
#endif
