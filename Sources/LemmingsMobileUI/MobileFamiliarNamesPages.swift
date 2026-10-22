#if os(iOS) || os(tvOS)
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit
import UIKit
#if os(iOS)
import Contacts
import ContactsUI
#endif

@MainActor final class MobileFamiliarNamesState: NSObject {
    var draft = ""
    var offset = 0
    var notice = ""
    var confirmingForget = false
    var loadFailed = false
    var field: UITextField?
    var selectedNames: (([String]) -> Void)?
    func clear() {
        field?.undoManager?.removeAllActions(); field?.resignFirstResponder(); field?.text = nil; field?.removeFromSuperview(); field = nil
        draft = ""; offset = 0; notice = ""; confirmingForget = false; loadFailed = false; selectedNames = nil
    }
}
#if os(iOS)
extension MobileFamiliarNamesState: @preconcurrency CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        // Retain strings only, never contact objects, identifiers or other fields.
        selectedNames?(contacts.compactMap { $0.isKeyAvailable(CNContactGivenNameKey) ? $0.givenName : nil })
        selectedNames = nil
    }
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) { selectedNames = nil }
}
#endif

extension MobileLibraryViewController {
    func familiarNamesPage() -> GameFrontEnd.Page {
        #if os(iOS)
        let contactsAvailable = true
        #else
        let contactsAvailable = false
        #endif
        return FamiliarNamesArt.page(draft: familiarNames.draft, offset: familiarNames.offset,
            contactsAvailable: contactsAvailable, editing: familiarNames.field?.isFirstResponder == true,
            notice: familiarNames.notice, loadFailed: familiarNames.loadFailed, confirmingForget: familiarNames.confirmingForget)
    }
    func handleFamiliarNames(_ id: String) -> Bool {
        if id == "familiarNames" {
            familiarNames.clear()
            do { familiarNames.draft = try FamiliarNamesStore.shared.names().joined(separator: ", ") }
            catch {
                familiarNames.loadFailed = true
                familiarNames.notice = L10n.text("Could not load familiar names. You can forget them and start again.")
            }
            navigate(.familiarNames); return true
        }
        guard id.hasPrefix("names."), route == .familiarNames else { return false }
        switch id {
        case "names.back": navigate(.settingsGroup(.privacy))
        case "names.apply":
            guard !familiarNames.loadFailed else { return true }
            do {
                try FamiliarNamesStore.shared.replace(with: FamiliarNamesStore.typed(familiarNames.draft))
                navigate(.settingsGroup(.privacy))
            } catch { familiarNames.notice = L10n.text("Could not save familiar names. Try again.") }
        case "names.edit": editFamiliarNames()
        case "names.previous": familiarNames.offset = max(0, familiarNames.offset - 6)
        case "names.next": familiarNames.offset += 6
        case "names.forget":
            familiarNames.field?.resignFirstResponder(); familiarNames.confirmingForget = true
        case "names.cancelForget": familiarNames.confirmingForget = false
        case "names.forgetConfirm":
            do {
                try FamiliarNamesStore.shared.forget(); familiarNames.clear()
            } catch {
                familiarNames.confirmingForget = false
                familiarNames.notice = L10n.text("Could not forget familiar names. Try again.")
            }
        case "names.contacts":
            #if os(iOS)
            familiarNames.field?.resignFirstResponder()
            let picker = CNContactPickerViewController()
            picker.delegate = familiarNames
            picker.displayedPropertyKeys = [CNContactGivenNameKey]
            picker.predicateForEnablingContact = NSPredicate(format: "givenName.length > 0")
            familiarNames.selectedNames = { [weak self] names in
                guard let self, route == .familiarNames else { return }
                familiarNames.draft = FamiliarNamesStore.unique(FamiliarNamesStore.typed(familiarNames.draft) + names).joined(separator: ", ")
                familiarNames.field?.text = familiarNames.draft
                familiarNames.offset = 0; rebuild()
            }
            present(picker, animated: true)
            #endif
        default: return false
        }
        rebuild(); return true
    }
    private func editFamiliarNames() {
        if let field = familiarNames.field { field.becomeFirstResponder(); return }
        let field = UITextField()
        field.text = familiarNames.draft
        field.autocorrectionType = .no; field.spellCheckingType = .no; field.textContentType = nil
        #if os(iOS)
        if #available(iOS 17.0, *) { field.inlinePredictionType = .no }
        #endif
        field.autocapitalizationType = .words; field.returnKeyType = .done
        field.accessibilityLabel = L10n.text("First names, separated by commas")
        field.frame = CGRect(x: -100, y: -100, width: 10, height: 10); field.alpha = 0.01
        field.addAction(UIAction { [weak self, weak field] _ in
            guard let self else { return }
            familiarNames.draft = field?.text ?? ""; familiarNames.offset = 0; rebuild()
        }, for: .editingChanged)
        field.addAction(UIAction { [weak self, weak field] _ in field?.resignFirstResponder(); self?.rebuild() }, for: .editingDidEndOnExit)
        view.addSubview(field); familiarNames.field = field; field.becomeFirstResponder()
    }
}
#endif
