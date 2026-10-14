import Foundation
import NxlvKit

/// Build metadata is bundled with the app, so local rebuilds have their own identity.
public struct MobileBuildInfo: Codable, Equatable, Sendable {
    public let version: String
    public let build: String
    public let identity: String
    public let builtAt: String
    public let changes: [String]

    public init(version: String, build: String, identity: String, builtAt: String, changes: [String]) {
        self.version = version; self.build = build; self.identity = identity
        self.builtAt = builtAt; self.changes = changes
    }

    public static func current(in bundle: Bundle = .main) -> Self {
        if let url = bundle.url(forResource: "BuildInfo", withExtension: "json"),
           let data = try? Data(contentsOf: url), let info = try? JSONDecoder().decode(Self.self, from: data) {
            return info
        }
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return .init(version: version, build: build, identity: version + ":" + build, builtAt: "", changes: [])
    }

    public var label: String { L10n.text("Version \(version) - Build \(build)") }
    public var dateLabel: String {
        guard let date = ISO8601DateFormatter().date(from: builtAt) else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium; formatter.timeStyle = .medium
        return L10n.text("Built \(formatter.string(from: date))")
    }

    private static let seenKey = "tv.whatsNew.seenIdentity"
    public func needsWelcome(in defaults: UserDefaults) -> Bool {
        defaults.string(forKey: Self.seenKey) != identity
    }
    public func acknowledge(in defaults: UserDefaults) {
        defaults.set(identity, forKey: Self.seenKey)
    }
}
