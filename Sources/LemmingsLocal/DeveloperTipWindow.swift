#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt

@MainActor final class DeveloperTipWindow {
    static let shared = DeveloperTipWindow()
    private let service: DeveloperTipService
    private var page: GameMenuPage?
    private var loadTask: Task<Void, Never>?
    private var generation = UUID()

    init(service: DeveloperTipService? = nil) {
        self.service = service ?? .shared
    }

    func show(owner: NSWindow? = nil) {
        guard AppDistribution.isStore else { return }
        if let page, GameScreen.shared.contains(page) {
            GameScreen.shared.present(page, owner: owner)
            return
        }
        generation = UUID()
        let current = generation
        let page = makePage()
        self.page = page
        guard GameScreen.shared.present(page, owner: owner,
            focus: page.controllerBackButton, onDismiss: { [weak self] in self?.end(current) }) else {
            end(current)
            return
        }
        service.onChange = { [weak self] in
            guard let self, self.generation == current else { return }
            self.refresh(current)
        }
        reload()
    }

    private func makePage() -> GameMenuPage {
        let content = DeveloperTipArt.page(state: service.state, product: service.product,
                                          canPurchase: service.canPurchase)
        let page = GameMenuPage(title: content.title)
        page.setDetail(([content.subtitle] + content.details).filter { !$0.isEmpty }.joined(separator: "\n\n"))
        page.controllerBackButton.identifier = .init("developerTip.back")
        page.onBack = { [weak page] in
            if let page { GameScreen.shared.dismiss(page) }
        }
        page.preferControllerControl(page.controllerBackButton)
        for action in content.footer where !action.isBackNavigation {
            let button = page.addPrimaryAction(action.title) { [weak self, weak page] in
                guard let self, let page, let window = page.window, self.page === page,
                      GameScreen.shared.contains(page), GameScreen.shared.controllerPage(in: window) === page else { return }
                let current = DeveloperTipArt.page(state: self.service.state, product: self.service.product,
                                                  canPurchase: self.service.canPurchase)
                guard current.footer.contains(where: { $0.id == action.id && $0.enabled }) else { return }
                if action.id == "developerTip.buy" || action.id == "developerTip.buyAgain" {
                    let service = self.service
                    Task { await service.purchase() }
                } else if action.id == "developerTip.retry" {
                    self.reload()
                }
            }
            button.identifier = .init(action.id)
            button.setAccessibilityLabel(action.title)
            button.isEnabled = action.enabled
        }
        return page
    }

    private func refresh(_ current: UUID) {
        guard generation == current, let previous = page, GameScreen.shared.contains(previous) else { return }
        let focusedID = (previous.window?.firstResponder as? NSView)?.identifier
        let replacement = makePage()
        let buttons = DialogKeyboardNavigation().controls(in: replacement)
        let focus = focusedID.flatMap { id in buttons.first { $0.identifier == id } } ?? replacement.controllerBackButton
        guard GameScreen.shared.replace(previous, with: replacement, focus: focus,
            onDismiss: { [weak self] in self?.end(current) }) else { return }
        page = replacement
    }

    private func reload() {
        loadTask?.cancel()
        let current = generation
        let service = service
        loadTask = Task { [weak self] in
            await service.loadProduct()
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.loadTask = nil
        }
    }

    private func end(_ current: UUID) {
        guard generation == current else { return }
        generation = UUID()
        service.onChange = nil
        loadTask?.cancel()
        loadTask = nil
        page = nil
    }

    deinit {
        loadTask?.cancel()
    }
}
#endif
