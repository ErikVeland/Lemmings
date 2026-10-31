import Foundation
import NxlvKit

/// The same private-library link flow supplies every platform's bitmap page.
public enum CloudSyncArt {
    public static func page(testerEnabled: Bool = false, busy: Bool = false, message: String = "", status: String = "",
                            code: String = "", draft: String? = nil) -> GameFrontEnd.Page {
        let subtitle = busy ? L10n.text("Connecting") : (message.isEmpty ? status : message)
        if testerEnabled {
            return .init(title: L10n.text("Cloud saves"), subtitle: subtitle,
                details: [L10n.text("Shared tester library"), L10n.text("Private device linking is unavailable for this library.")],
                footer: [.init("syncBack", L10n.text("Back"), primary: true)])
        }
        if let draft {
            return .init(title: L10n.text("Link device"), subtitle: subtitle,
                rows: [.init("syncCode", draft.isEmpty ? L10n.text("12-character code") : draft, enabled: !busy)],
                details: [L10n.text("Enter the code from your other device.")],
                footer: [.init("syncCancel", L10n.text("Back"), enabled: !busy),
                         .init("syncJoin", L10n.text("Link device"), enabled: !busy && draft.count == 12, primary: true)])
        }
        if !code.isEmpty {
            let grouped = stride(from: 0, to: code.count, by: 4).map { offset in
                String(code.dropFirst(offset).prefix(4))
            }.joined(separator: " ")
            return .init(title: L10n.text("Link device"), subtitle: subtitle,
                details: [grouped, L10n.text("One use · Expires after 10 minutes"),
                          L10n.text("On your other device, choose Enter code.")],
                footer: [.init("syncCancel", L10n.text("Back"), primary: true)])
        }
        return .init(title: L10n.text("Cloud saves"), subtitle: subtitle,
            rows: [.init("syncMake", L10n.text("Link device"), enabled: !busy, primary: true),
                   .init("syncEnter", L10n.text("Enter code"), enabled: !busy)],
            details: [L10n.text("Same iCloud account: automatic"), L10n.text("All players · Solo · Hot Seat")],
            footer: [.init("syncBack", L10n.text("Back"))])
    }
}
