import Foundation
import NxlvKit

/// Normal sync is automatic. Testers can join one shared library with one action.
public enum CloudSyncArt {
    public static func page(testerEnabled: Bool = false, busy: Bool = false, message: String = "", status: String = "") -> GameFrontEnd.Page {
        .init(title: L10n.text("Tester sync"), subtitle: busy ? L10n.text("Enabling") : (message.isEmpty ? status : message),
            details: [L10n.text("All players · Solo · Hot Seat"),
                      L10n.text("Shared tester library")],
            footer: [.init("syncBack", L10n.text("Back"), primary: testerEnabled),
                     .init("syncTester", testerEnabled ? L10n.text("Tester sync: On") : L10n.text("Enable tester sync"),
                           enabled: !testerEnabled && !busy, primary: !testerEnabled, selected: testerEnabled)])
    }
}
