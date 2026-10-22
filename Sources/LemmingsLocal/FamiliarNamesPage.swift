#if os(macOS)
import AppKit
import Contacts
import ContactsUI
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit

@MainActor final class FamiliarNamesPage: GameMenuPage, NSSearchFieldDelegate, @preconcurrency CNContactPickerDelegate {
    let field = GameSearchField(frame: .zero)
    private let preview = GameLabel(wrappingLabelWithString: "")
    private let notice = GameLabel(wrappingLabelWithString: "")
    private let store: FamiliarNamesStore
    private var picker: CNContactPicker?
    private var offset = 0
    private var previous: NSButton!
    private var next: NSButton!
    private var forget: NSButton!
    private var apply: NSButton!
    private var loadFailed = false

    init(store: FamiliarNamesStore = .shared) {
        self.store = store
        super.init(title: L10n.text("Familiar names"))
        let content = FamiliarNamesBody(frame: body.bounds)
        body.addSubview(content)
        let privacy = GameLabel(wrappingLabelWithString: FamiliarNamesArt.privacy + "\n" + FamiliarNamesArt.retention)
        privacy.frame = CGRect(x: 32, y: 0, width: 928, height: 108)
        content.addSubview(privacy)
        field.frame = CGRect(x: 32, y: 122, width: 928, height: 48)
        field.placeholderString = L10n.text("First names, separated by commas")
        field.setAccessibilityLabel(L10n.text("First names, separated by commas"))
        field.delegate = self
        content.addSubview(field)
        preview.frame = CGRect(x: 32, y: 182, width: 928, height: 144)
        content.addSubview(preview)
        func button(_ title: String, _ frame: CGRect, _ action: @escaping () -> Void) -> NSButton {
            let result = GameActionButton(title: title, primary: false, onPress: action)
            result.frame = frame; content.addSubview(result); return result
        }
        previous = button(L10n.text("Previous"), CGRect(x: 32, y: 330, width: 280, height: 48)) { [weak self] in
            self?.offset -= 6; self?.refresh()
        }
        next = button(L10n.text("Next"), CGRect(x: 680, y: 330, width: 280, height: 48)) { [weak self] in
            self?.offset += 6; self?.refresh()
        }
        let contacts = button(L10n.text("Choose contacts"), CGRect(x: 32, y: 394, width: 440, height: 48)) { [weak self] in self?.chooseContacts() }
        contacts.setAccessibilityIdentifier("familiarNames.contacts")
        forget = button(L10n.text("Forget names"), CGRect(x: 520, y: 394, width: 440, height: 48)) { [weak self] in
            guard let self else { return }
            GameScreen.shared.confirm(L10n.text("Forget familiar names?"), detail: FamiliarNamesArt.forgetDetail,
                actionTitle: L10n.text("Forget names"), owner: window) { [weak self] in self?.forgetNames() }
        }
        notice.frame = CGRect(x: 32, y: 446, width: 928, height: 32)
        content.addSubview(notice)
        apply = addPrimaryAction(L10n.text("Apply")) { [weak self] in self?.save() }
        onBack = { [weak self] in
            guard let self else { return }; picker?.close(); field.stringValue = ""; GameScreen.shared.dismiss(self)
        }
        preferControllerControl(controllerBackButton)
        do { field.stringValue = try store.names().joined(separator: ", ") }
        catch { loadFailed = true; notice.stringValue = L10n.text("Could not load familiar names. You can forget them and start again.") }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func controlTextDidChange(_ obj: Notification) { offset = 0; refresh() }
    private func refresh() {
        let names = FamiliarNamesStore.typed(field.stringValue)
        offset = min(max(0, offset), max(0, (names.count - 1) / 6 * 6))
        preview.stringValue = names.isEmpty ? L10n.text("No names for new levels") : names.dropFirst(offset).prefix(6).joined(separator: "\n")
        previous.isEnabled = offset > 0; next.isEnabled = offset + 6 < names.count
        forget.isEnabled = true // Also clears retained assignments and a damaged file.
        apply.isEnabled = !loadFailed
        preview.needsDisplay = true; field.needsDisplay = true
    }
    private func chooseContacts() {
        let picker = CNContactPicker()
        picker.displayedKeys = [] // Select a contact; never request address-book authorization.
        picker.delegate = self; self.picker = picker
        picker.showRelative(to: field.bounds, of: field, preferredEdge: .maxY)
    }
    func contactPicker(_ picker: CNContactPicker, didSelect contact: CNContact) {
        guard contact.isKeyAvailable(CNContactGivenNameKey) else { return }
        field.stringValue = FamiliarNamesStore.unique(FamiliarNamesStore.typed(field.stringValue) + [contact.givenName]).joined(separator: ", ")
        picker.close(); refresh()
    }
    func contactPickerDidClose(_ picker: CNContactPicker) { self.picker = nil }
    func save() {
        guard !loadFailed else { return }
        do {
            try store.replace(with: FamiliarNamesStore.typed(field.stringValue))
            onBack?()
        } catch { notice.stringValue = L10n.text("Could not save familiar names. Try again.") }
    }
    func forgetNames() {
        do {
            try store.forget(); field.currentEditor()?.undoManager?.removeAllActions(); loadFailed = false; field.stringValue = ""; notice.stringValue = ""; refresh()
        } catch { notice.stringValue = L10n.text("Could not forget familiar names. Try again.") }
    }
}
@MainActor private final class FamiliarNamesBody: NSView { override var isFlipped: Bool { true } }
#endif
