import LemmingsAppCore
import NxlvKit

public enum FamiliarNamesArt {
    public static var privacy: String {
        L10n.text("Choose first names for your lemmings. Names stay on this device. Their stories are fictional.")
    }
    public static var retention: String {
        L10n.text("Existing lemmings keep their names until you choose Forget names.")
    }
    public static var forgetDetail: String {
        L10n.text("Remove all familiar names, including saved-run assignments. Lemmings will use fictional names again.")
    }
    public static func page(draft: String, offset: Int, contactsAvailable: Bool, editing: Bool = false,
                            notice: String = "", loadFailed: Bool = false, confirmingForget: Bool = false) -> GameFrontEnd.Page {
        if confirmingForget {
            return .init(title: L10n.text("Forget familiar names?"), details: [forgetDetail], footer: [
                .init("names.cancelForget", L10n.text("Back")), .init("names.forgetConfirm", L10n.text("Forget names"), primary: true)])
        }
        let names = FamiliarNamesStore.typed(draft)
        let start = min(max(0, offset), max(0, (names.count - 1) / 6 * 6))
        var rows: [GameFrontEnd.Action] = [.init("names.edit", L10n.text("Type first names"), selected: editing)]
        if contactsAvailable { rows.append(.init("names.contacts", L10n.text("Choose contacts"))) }
        rows.append(.init("names.forget", L10n.text("Forget names")))
        if names.count > 6 {
            rows += [.init("names.previous", L10n.text("Previous"), enabled: start > 0),
                     .init("names.next", L10n.text("Next"), enabled: start + 6 < names.count)]
        }
        let preview = names.isEmpty ? [L10n.text("No names for new levels")] : Array(names.dropFirst(start).prefix(6))
        let details = [privacy, retention] + (editing ? [L10n.text("First names, separated by commas"), String(draft.suffix(80)) + "_"] : preview)
            + (notice.isEmpty ? [] : [notice])
        return .init(title: L10n.text("Familiar names"), rows: rows, details: details, footer: [
            .init("names.back", L10n.text("Back")), .init("names.apply", L10n.text("Apply"), enabled: !loadFailed, primary: true)])
    }
}
