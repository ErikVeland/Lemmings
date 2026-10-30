import CryptoKit
import Foundation
import Testing
@testable import LemmingsAppCore

@MainActor struct SavedHotSeatTests {
    @Test func legacyPointerRemainsVisibleAndSurvivesStartingAnotherSession() throws {
        let storage = try AppStorage.temporary(named: "legacy-saved-seats")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let owner = store.records.activeProfileID
        _ = try #require(store.addProfile(initials: "UVA", portrait: 0, select: false))
        store.prepareHotSeat()
        let original = try #require(store.hotSeatID)
        #expect(store.passSessionTurn(after: owner))
        let turn = store.playingProfileID
        let fileID = SHA256.hash(data: Data(ArcadeStore.recordsFile(storage: storage).path.utf8))
            .map { String(format: "%02x", $0) }.joined()
        storage.defaults.removeObject(forKey: "HotSeat.saved.\(fileID).\(owner).history")
        #expect(store.libraryHotSeats.map(\.id) == [original])
        #expect(store.startNewHotSeat())
        let current = try #require(store.hotSeatID)
        #expect(store.savedHotSeats.map(\.id) == [original])
        let outsider = try #require(store.addProfile(initials: "NEW", portrait: 1, select: true))
        #expect(store.records.activeProfileID == outsider.id)
        #expect(Set(store.savedHotSeats.map(\.id)) == [original, current])
        let reopened = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(Set(reopened.savedHotSeats.map(\.id)) == [original, current])
        #expect(reopened.resumeHotSeat(id: original))
        #expect(reopened.records.activeProfileID == owner)
        #expect(reopened.playingProfileID == turn)
        #expect(reopened.savedHotSeats.map(\.id) == [current])
    }
}
