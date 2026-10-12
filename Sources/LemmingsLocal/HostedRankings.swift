#if os(macOS)
import Foundation
import LemmingsAppCore

/// Mac adapter retains its established shared records instance and settings keys.
@MainActor final class HostedRankings: HostedRankingsService {
    static var shared = HostedRankings()
    init(endpoint: URL? = nil, transport: (any HostedRankingsTransport)? = nil, defaults: UserDefaults = .standard,
         credentials: ((String) throws -> String)? = nil) {
        super.init(endpoint: endpoint, transport: transport, defaults: defaults, credentials: credentials,
                   recordsStoreProvider: { ArcadeStore.shared })
    }
}
#endif
