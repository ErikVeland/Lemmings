#if os(macOS)
import AppKit
import LemmingsAppCore
import NxlvKit

/// Inspection owns input until Back. Closing it leaves the attempt paused.
@MainActor final class LemmingInspectionPage: GameMenuPage {
    private let snapshot: LemmingInspection
    private var index: Int
    private var historyPage = 0
    private let content = LemmingInspectionBody()
    private let nameLabel = GameLabel(labelWithString: "")
    private let detailLabel = GameLabel(wrappingLabelWithString: "")
    private var previous: NSButton!
    private var next: NSButton!
    private var earlier: GameActionButton!
    private var later: GameActionButton!

    init(snapshot: LemmingInspection, selectedID: Int? = nil) {
        self.snapshot = snapshot
        index = selectedID.flatMap { id in snapshot.individuals.firstIndex { $0.id == id } } ?? 0
        super.init(title: L10n.text("Lemmings"), subtitle: L10n.text("This level"))
        content.frame = body.bounds
        body.addSubview(content)
        nameLabel.role = .heading
        nameLabel.frame = CGRect(x: 32, y: 0, width: 928, height: 40)
        detailLabel.frame = CGRect(x: 32, y: 48, width: 928, height: 336)
        content.addSubview(nameLabel); content.addSubview(detailLabel)
        previous = addSecondaryAction(L10n.text("Previous")) { [weak self] in self?.move(-1) }
        next = addPrimaryAction(L10n.text("Next")) { [weak self] in self?.move(1) }
        earlier = GameActionButton(title: L10n.text("Earlier actions"), primary: false) { [weak self] in self?.moveHistory(-1) }
        later = GameActionButton(title: L10n.text("Later actions"), primary: false) { [weak self] in self?.moveHistory(1) }
        earlier.frame = CGRect(x: 32, y: 390, width: 320, height: 48)
        later.frame = CGRect(x: 640, y: 390, width: 320, height: 48)
        content.addSubview(earlier); content.addSubview(later)
        onHorizontalNavigation = { [weak self] in self?.move($0) }
        onBack = { [weak self] in if let self { GameScreen.shared.dismiss(self) } }
        preferControllerControl(controllerBackButton)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func move(_ direction: Int) {
        guard snapshot.individuals.indices.contains(index + direction) else { return }
        index += direction; historyPage = 0; refresh()
    }
    private func moveHistory(_ direction: Int) {
        guard snapshot.individuals.indices.contains(index) else { return }
        let target = historyPage + direction
        guard (0...LemmingInspection.lastHistoryPage(for: snapshot.individuals[index])).contains(target) else { return }
        historyPage = target; refresh()
    }
    private func refresh() {
        let individual = snapshot.individuals.indices.contains(index) ? snapshot.individuals[index] : nil
        nameLabel.stringValue = individual?.title ?? L10n.text("No lemmings released yet")
        detailLabel.stringValue = individual == nil ? "" : snapshot.lines(for: index, historyPage: historyPage).joined(separator: "\n")
        previous.isEnabled = index > 0
        next.isEnabled = index + 1 < snapshot.individuals.count
        let hasHistoryPages = individual.map { LemmingInspection.lastHistoryPage(for: $0) > 0 } ?? false
        earlier.isHidden = !hasHistoryPages; later.isHidden = !hasHistoryPages
        earlier.isEnabled = historyPage > 0
        later.isEnabled = individual.map { historyPage < LemmingInspection.lastHistoryPage(for: $0) } ?? false
        nameLabel.setAccessibilityLabel(nameLabel.stringValue)
        detailLabel.setAccessibilityLabel(detailLabel.stringValue)
        nameLabel.needsDisplay = true; detailLabel.needsDisplay = true
        if let focused = window?.firstResponder as? NSControl, !focused.isEnabled || focused.isHidden {
            window?.makeFirstResponder(controllerBackButton)
        }
        if window != nil {
            NSAccessibility.post(element: nameLabel, notification: .valueChanged)
            NSAccessibility.post(element: detailLabel, notification: .valueChanged)
        }
    }
}

@MainActor private final class LemmingInspectionBody: NSView {
    override var isFlipped: Bool { true }
}
#endif
