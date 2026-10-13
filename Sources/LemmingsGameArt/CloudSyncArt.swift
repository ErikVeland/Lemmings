import Foundation

/// The same stone controls and bitmap targets on Mac, iPhone and iPad.
public enum CloudSyncArt {
    public static func page(status: String, providers: String, enabled: Bool, busy: Bool = false,
                            code: String? = nil, draft: String? = nil, message: String = "") -> GameFrontEnd.Page {
        if let draft {
            return .init(title: "Link library", subtitle: message,
                rows: [.init("syncCodeField", "Code: " + grouped(draft) + "_", selected: true)],
                details: ["Shares your whole library.", "Profiles and Hot Seats."],
                footer: [.init("syncCancel", "Cancel"),
                         .init("syncJoin", "Link library", enabled: draft.count == 12 && !busy, primary: true)])
        }
        if let code {
            return .init(title: "Link device", subtitle: message,
                details: [grouped(code), "Valid for 10 minutes.", "One use.", "Shares your whole library."],
                footer: [.init("syncCancel", "Back"), .init("syncCopy", "Copy code", primary: true)])
        }
        return .init(title: "Cloud saves", subtitle: message.isEmpty ? status : message,
            rows: [.init("syncToggle", enabled ? "Cloud saves: On" : "Cloud saves: Off", primary: !enabled, selected: enabled),
                   .init("syncNow", "Sync now", enabled: enabled && !busy, primary: enabled),
                   .init("syncMakeLink", "Link another device", enabled: enabled && !busy),
                   .init("syncEnterCode", "Enter device code", enabled: enabled && !busy),
                   .init("syncExportKey", "Save recovery key", enabled: !busy),
                   .init("syncImportKey", "Restore recovery key", enabled: !busy)],
            details: providers.isEmpty ? [] : [providers], footer: [.init("syncBack", "Back")])
    }
    public static func grouped(_ code: String) -> String {
        stride(from: 0, to: code.count, by: 4).map { start in
            String(code.dropFirst(start).prefix(4))
        }.joined(separator: " ")
    }
}
