#if os(macOS)
import AppKit
import NxlvKit

/// A short grid of categories, series or packs, using the existing stone controls.
@MainActor final class FanLevelGroupPage: GameMenuPage {
    let path: [String]
    private(set) var groups: [FanLevelOrganisation.Group] = []
    private(set) var groupButtons: [NSButton] = []
    var onSelect: ((FanLevelOrganisation.Group) -> Void)?

    init(root: FanLevelOrganisation.Group, path: [String]) {
        self.path = path
        let group = root.group(at: path) ?? root
        super.init(title: group.title)
        listMinimumHeight = 76
        reload(root)
    }
    required init?(coder: NSCoder) { nil }

    func reload(_ root: FanLevelOrganisation.Group) {
        let focusedID = groupButtons.firstIndex { $0 === window?.firstResponder }.map { groups[$0].id }
        groupButtons.forEach { $0.removeFromSuperview() }
        groups = root.group(at: path)?.children ?? []
        groupButtons = groups.enumerated().map { index, group in
            let label = group.packID == nil
                ? group.title + "  (\(group.packIDs.count)) >" : group.title
            let button = addListAction(label, at: index) { [weak self] in self?.onSelect?(group) }
            (button as? GameActionButton)?.wrapsTitle = true
            button.setAccessibilityLabel(group.packID == nil
                ? group.title + ", " + L10n.plural("count.packs", count: group.packIDs.count, one: "%ld pack", other: "%ld packs")
                : group.title)
            return button
        }
        if let index = groups.firstIndex(where: { $0.id == focusedID }) { window?.makeFirstResponder(groupButtons[index]) }
        if let first = groupButtons.first { preferControllerControl(first) }
        needsLayout = true
    }

}
#endif
