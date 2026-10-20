import NxlvKit
/// TV file equivalents retain the shared cloud page and its bitmap action targets.
public enum TVSharedMenuArt {
    public static func cloud(_ shared: GameFrontEnd.Page, restoring: Bool, hasCode: Bool,
                             enteringCode: Bool, busy: Bool) -> GameFrontEnd.Page {
        if restoring {
            return .init(title: L10n.text("Restore TV saves?"), footer: [.init("syncTVRestoreCancel", L10n.text("Cancel")),
                .init("syncTVRestoreConfirm", L10n.text("Restore"), primary: true)])
        }
        return shared
    }
}
