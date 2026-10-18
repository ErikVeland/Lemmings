import Foundation
import NxlvKit

/// The same stone controls and bitmap targets on Mac, iPhone and iPad.
public enum CloudSyncArt {
    public static func page(status: String, providers: String, enabled: Bool, busy: Bool = false,
                            code: String? = nil, draft: String? = nil, password: String? = nil,
                            message: String = "") -> GameFrontEnd.Page {
        if let password {
            return .init(title: L10n.text("Sync password"), subtitle: message,
                rows: [.init("syncPasswordField", L10n.text("Password: \(masked(password))_"), selected: true)],
                details: [L10n.text("At least 4 characters."), L10n.text("Use the same password on every device."),
                          L10n.text("Shares your whole library.")],
                footer: [.init("syncCancel", L10n.text("Cancel")),
                         .init("syncJoinPassword", L10n.text("Link library"),
                               enabled: password.trimmingCharacters(in: .whitespacesAndNewlines).count >= passwordMinimum && !busy, primary: true)])
        }
        if let draft {
            return .init(title: L10n.text("Link library"), subtitle: message,
                rows: [.init("syncCodeField", L10n.text("Code: \(grouped(draft))_"), selected: true)],
                details: [L10n.text("Shares your whole library."), L10n.text("Profiles and Hot Seats.")],
                footer: [.init("syncCancel", L10n.text("Cancel")),
                         .init("syncJoin", L10n.text("Link library"), enabled: draft.count == 12 && !busy, primary: true)])
        }
        if let code {
            return .init(title: L10n.text("Link device"), subtitle: message,
                details: [grouped(code), L10n.text("Valid for 10 minutes."), L10n.text("One use."), L10n.text("Shares your whole library.")],
                footer: [.init("syncCancel", L10n.text("Back")), .init("syncCopy", L10n.text("Copy code"), primary: true)])
        }
        return .init(title: L10n.text("Cloud saves"), subtitle: message.isEmpty ? status : message,
            rows: [.init("syncToggle", enabled ? L10n.text("Cloud saves: On") : L10n.text("Cloud saves: Off"), primary: !enabled, selected: enabled),
                   .init("syncNow", L10n.text("Sync now"), enabled: enabled && !busy, primary: enabled),
                   .init("syncMakeLink", L10n.text("Link another device"), enabled: enabled && !busy),
                   .init("syncEnterCode", L10n.text("Enter device code"), enabled: enabled && !busy),
                   .init("syncEnterPassword", L10n.text("Sync password"), enabled: enabled && !busy),
                   .init("syncExportKey", L10n.text("Save recovery key"), enabled: !busy),
                   .init("syncImportKey", L10n.text("Restore recovery key"), enabled: !busy)],
            details: providers.isEmpty ? [] : [providers], footer: [.init("syncBack", L10n.text("Back"))])
    }
    /// Matches `CloudLibraryIdentity.minimumPasswordLength`.
    public static let passwordMinimum = 4
    public static let passwordMaximum = 64
    public static func masked(_ password: String) -> String { String(repeating: "*", count: password.count) }
    public static func grouped(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4).map { start in
            String(code.dropFirst(start).prefix(4))
        }.joined(separator: " ")
    }
}
