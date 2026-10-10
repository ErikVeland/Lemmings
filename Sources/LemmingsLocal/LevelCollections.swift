import AppKit
import NxlvKit

/// Personal shortcuts share the playlist file's atomic writes and recovery guards.
@MainActor enum LevelCollections {
    static let catalogueRevision = "1.2-runtime-v2"
    private static var stores: [URL: LevelPlaylistStore] = [:]
    private static var attempts: [UUID: LevelPlaylistEntry] = [:]
    private static var attemptOrder: [UUID] = []

    static func store(profileID: String) throws -> LevelPlaylistStore {
        let file = ArcadeStore.shared.collectionsFile(profileID: profileID)
        if let store = stores[file] { return store }
        let store = try LevelPlaylistStore(file: file)
        stores[file] = store
        return store
    }

    static func entry(attemptID: UUID) -> LevelPlaylistEntry? { attempts[attemptID] }
    static func reload(profileID: String) throws {
        let file = ArcadeStore.shared.collectionsFile(profileID: profileID)
        stores[file] = try LevelPlaylistStore(file: file)
    }

    static func record(_ entry: LevelPlaylistEntry?, profileID: String, attemptID: UUID) {
        guard let entry else { return }
        if attempts[attemptID] == nil { attemptOrder.append(attemptID) }
        attempts[attemptID] = entry
        while attemptOrder.count > 32 { attempts[attemptOrder.removeFirst()] = nil }
        do { try store(profileID: profileID).recordVisit(entry) }
        catch { NSLog("Recently Played could not save: %@", error.localizedDescription) }
    }

    static func isFavourite(_ entry: LevelPlaylistEntry, profileID: String) -> Bool {
        (try? store(profileID: profileID).favourites.contains { $0.identity == entry.identity }) == true
    }

    static func toggle(_ entry: LevelPlaylistEntry, profileID: String, owner: NSWindow?) {
        do { try store(profileID: profileID).toggleFavourite(entry) }
        catch { GameScreen.shared.message("Favourite not saved", detail: error.localizedDescription) }
    }
}
