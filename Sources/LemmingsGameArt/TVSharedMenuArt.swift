/// TV file equivalents retain the shared cloud page and its bitmap action targets.
public enum TVSharedMenuArt {
    public static func cloud(_ shared: GameFrontEnd.Page, restoring: Bool, hasCode: Bool,
                             enteringCode: Bool, busy: Bool) -> GameFrontEnd.Page {
        if restoring {
            return .init(title: "Restore TV saves?", footer: [.init("syncTVRestoreCancel", "Cancel"),
                .init("syncTVRestoreConfirm", "Restore", primary: true)])
        }
        var page = shared
        if hasCode { page.footer.removeAll { $0.id == "syncCopy" } }
        else if !enteringCode {
            page.rows += [.init("syncTVBackup", "Back up TV saves", enabled: !busy),
                          .init("syncTVRestore", "Restore TV saves", enabled: !busy)]
        }
        return page
    }
}
