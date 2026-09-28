import Foundation

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()

    func progressKey(_ key: String) -> String { key }
}
