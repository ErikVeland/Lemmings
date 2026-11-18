import Foundation

enum AppleMobileLaunchURL {
    /**
     * Accepts Desk Clock links registered by this publication's Info.plist.
     */
    static func opensDeskClock(_ url: URL, info: [String: Any]) -> Bool {
        guard url.host == "desk-clock", let scheme = url.scheme,
              let types = info["CFBundleURLTypes"] as? [[String: Any]] else { return false }
        return types.contains { type in
            (type["CFBundleURLSchemes"] as? [String] ?? []).contains {
                $0.caseInsensitiveCompare(scheme) == .orderedSame
            }
        }
    }
}
