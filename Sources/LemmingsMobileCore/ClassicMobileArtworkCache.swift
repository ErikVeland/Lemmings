import Foundation
import NxlvKit

/// Bundle artwork is immutable. Share its decoded banks across fresh sessions.
final class ClassicMobileArtworkCache: @unchecked Sendable {
    static let shared = ClassicMobileArtworkCache()
    private final class Banks: NSObject {
        let artwork: ClassicMacArtwork
        init(_ artwork: ClassicMacArtwork) { self.artwork = artwork }
    }
    private let cache = NSCache<NSURL, Banks>()
    private init() { cache.countLimit = 4; cache.totalCostLimit = 64 * 1024 * 1024 }
    func load(_ directory: URL) throws -> ClassicMacArtwork {
        if let banks = cache.object(forKey: directory as NSURL) { return banks.artwork }
        let artwork = try ClassicMacArtwork(directory: directory)
        let cost = artwork.banks.values.reduce(0) { sum, bank in sum + bank.compactMap { $0 }.reduce(0) { $0 + $1.rgba.count } }
        cache.setObject(Banks(artwork), forKey: directory as NSURL, cost: cost)
        return artwork
    }
}
