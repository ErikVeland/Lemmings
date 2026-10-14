import NxlvKit
/// TV file equivalents retain the shared cloud page and its bitmap action targets.
public enum TVSharedMenuArt {
    public static func cloud(_ shared: GameFrontEnd.Page, restoring: Bool, hasCode: Bool,
                             enteringCode: Bool, busy: Bool) -> GameFrontEnd.Page {
        if restoring {
            return .init(title: L10n.text("Restore TV saves?"), footer: [.init("syncTVRestoreCancel", L10n.text("Cancel")),
                .init("syncTVRestoreConfirm", L10n.text("Restore"), primary: true)])
        }
        var page = shared
        if hasCode { page.footer.removeAll { $0.id == "syncCopy" } }
        else if !enteringCode {
            page.rows += [.init("syncTVBackup", L10n.text("Back up TV saves"), enabled: !busy),
                          .init("syncTVRestore", L10n.text("Restore TV saves"), enabled: !busy)]
        }
        return page
    }
}
