import Foundation
import NxlvKit
import LemmingsMobileCore

/// Each engine supplies its native library; the television shell has no Classic-only routes.
public struct TVLibrarySource: Sendable {
    public let id: String
    public let title: String
    public let makeLibrary: @Sendable () throws -> any MobileGameLibrary
    public init(id: String, title: String, makeLibrary: @escaping @Sendable () throws -> any MobileGameLibrary) {
        self.id = id; self.title = title; self.makeLibrary = makeLibrary
    }
    public static func classic(directory: URL) -> TVLibrarySource {
        .init(id: "classic", title: L10n.text("Lemmings"), makeLibrary: { try ClassicMobileLibrary(directory: directory) })
    }
}

public actor TVLibraryCatalogue {
    private let source: TVLibrarySource
    public init(source: TVLibrarySource) { self.source = source }
    public func levels() throws -> [MobileLevelSummary] {
        try Task.checkCancellation()
        return try source.makeLibrary().levels
    }
}

/// Small profile and turn metadata belongs in defaults, independent of purgeable level caches.
public struct TVLocalState: Codable, Sendable {
    public var profiles = MobileProfiles()
    public var seats: [String: MobileHotSeat] = [:]
    public var activeSeatScope: String?
    public var checkpointSources: [String: String] = [:]
    public var completed: [String: Set<Int>] = [:]
    public var preferences = TVPreferences()
    public init() {}
    public func progressKey(source: String, owner: String, scope: String?) -> String {
        source + ":" + (scope ?? "solo." + owner)
    }
}
