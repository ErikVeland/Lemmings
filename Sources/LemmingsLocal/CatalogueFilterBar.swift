#if os(macOS)
import AppKit
import NxlvKit

@MainActor final class CatalogueFilterBar: NSView, NSSearchFieldDelegate {
    let search = GameSearchField(frame: .zero)
    let filter = GameActionButton(title: CatalogueProgressFilter.all.title, primary: false)
    let clear = GameActionButton(title: L10n.text("Clear filters"), primary: false)
    var onChange: ((String, CatalogueProgressFilter) -> Void)?
    private(set) var progress = CatalogueProgressFilter.all

    init(searchTitle: String, progressEnabled: Bool) {
        super.init(frame: .zero)
        search.placeholderString = searchTitle
        search.setAccessibilityLabel(searchTitle)
        search.delegate = self
        filter.isHidden = !progressEnabled
        filter.setAccessibilityIdentifier("catalogue.progress")
        clear.setAccessibilityIdentifier("catalogue.clear")
        filter.onPress = { [weak self] in
            guard let self else { return }
            progress = progress.next
            changed()
        }
        clear.onPress = { [weak self] in
            guard let self else { return }
            search.stringValue = ""
            progress = .all
            changed()
        }
        for control in [search, filter, clear] as [NSControl] { addSubview(control) }
        clear.isEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    func install(in body: NSView, above carousel: LevelCoverFlowView, emptyTitle: String) -> GameLabel {
        frame = CGRect(x: 0, y: body.bounds.maxY - 48, width: body.bounds.width, height: 48)
        autoresizingMask = [.width, .minYMargin]
        body.addSubview(self)
        carousel.frame.size.height = max(1, frame.minY - 8)
        let empty = GameLabel(labelWithString: emptyTitle)
        empty.alignment = .center
        empty.frame = CGRect(x: 0, y: carousel.frame.midY - 24, width: carousel.frame.width, height: 48)
        body.addSubview(empty)
        return empty
    }

    func controlTextDidChange(_ obj: Notification) { changed() }

    private func changed() {
        filter.title = progress.title
        filter.setAccessibilityValue(progress.title)
        filter.needsDisplay = true
        clear.isEnabled = !search.stringValue.isEmpty || progress != .all
        search.needsDisplay = true
        onChange?(search.stringValue, progress)
    }

    override func layout() {
        super.layout()
        let width = min(225, (bounds.width - 16) * 0.29)
        clear.frame = CGRect(x: bounds.maxX - width, y: 0, width: width, height: bounds.height)
        filter.frame = clear.frame.offsetBy(dx: -width - 8, dy: 0)
        search.frame = CGRect(x: 0, y: 0, width: (filter.isHidden ? clear : filter).frame.minX - 8, height: bounds.height)
    }
}
#endif
