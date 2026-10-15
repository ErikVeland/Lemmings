import Foundation
import NxlvKit

/// Error actions remain independent of the operation that failed.
public enum GameRecoveryArt {
    public static func page(title: String, details: [String] = []) -> GameFrontEnd.Page {
        .init(title: title, details: details, footer: [
            .init("retry", L10n.text("TRY AGAIN"), primary: true),
            .init("back", L10n.text("BACK")),
            .init("menu", L10n.text("MENU")),
        ])
    }

    public static func migrationFailure(_ message: String) -> GameFrontEnd.Page {
        .init(title: L10n.text("Saved data could not be opened"), details: [message], footer: [
            .init("retry", L10n.text("Retry")),
            .init("continue", L10n.text("Continue"), primary: true),
        ])
    }

    public static func recordsReset(_ message: String) -> GameFrontEnd.Page {
        .init(title: L10n.text("Records cannot be read"),
            details: [L10n.text("\(message) Start new records to save again. The unreadable files stay in the records folder.")],
            footer: [.init("recordsResetCancel", L10n.text("Cancel")),
                     .init("recordsResetConfirm", L10n.text("Start new records"), primary: true)])
    }
}
