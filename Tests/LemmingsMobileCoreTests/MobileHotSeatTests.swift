import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileHotSeatTests {
    private struct Missing: Error {}
    private func required<T>(_ value: T?) throws -> T {
        guard let value else { throw Missing() }
        return value
    }

    @Test func oneProfileIsNotAHotSeat() {
        #expect(MobileHotSeat(host: "a", players: []) == nil)
        #expect(MobileHotSeat(host: "a", players: ["a"]) == nil)
        #expect(!MobileHotSeatRoster(host: "a").canStart)
    }

    @Test func theHostStaysInTheRoster() {
        var roster = MobileHotSeatRoster(host: "a", players: ["b"])
        #expect(roster.canStart)
        roster.toggle("a")
        #expect(roster.contains("a"))
        roster.toggle("b")
        #expect(!roster.canStart)
        roster.toggle("c")
        #expect(roster.players == ["a", "c"])
    }

    @Test func turnsRotateAndWrap() throws {
        var seat = try #require(MobileHotSeat(host: "a", players: ["b", "c"]))
        #expect(seat.turn == "a")
        #expect(seat.next == "b")
        seat.pass(to: "c")
        #expect(seat.next == "a")
        seat.pass(to: "zzz")
        #expect(seat.turn == "c")
    }

    @Test func resultChoicesFollowTheHouseRule() throws {
        var seat = try #require(MobileHotSeat(host: "a", players: ["b"]))
        let loss = seat.choices(didWin: false)
        #expect(loss == [.init(kind: .retry, player: "b", primary: true), .init(kind: .retry, player: "a", primary: false)])
        let every = seat.choices(didWin: true)
        #expect(every.first == .init(kind: .next, player: "b", primary: true))
        #expect(every.filter { $0.kind == .retry }.map(\.player) == ["a", "b"])
        seat.policy = .atFirstFail
        let first = seat.choices(didWin: true)
        #expect(first.first == .init(kind: .next, player: "a", primary: true))
        #expect(first.filter(\.primary).count == 1)
    }

    @Test func aPlayerWhoLeavesLosesTheTurn() throws {
        var seat = try #require(MobileHotSeat(host: "a", players: ["b", "c"]))
        seat.pass(to: "b")
        let after = try #require(seat.removing("b"))
        #expect(after.players == ["a", "c"])
        #expect(after.turn == "c")
        #expect(after.removing("c") == nil)
        #expect(after.removing("a") == after)
    }

    @Test func sessionsSurviveSavingAndKeepTheirRule() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        var store = MobileHotSeatStore()
        store.policy = .atFirstFail
        var first = try required(store.start(roster: MobileHotSeatRoster(host: "a", players: ["b"])))
        #expect(first.policy == .atFirstFail)
        first.pass(to: "b")
        store.update(first)
        try store.save(to: storage)

        var loaded = MobileHotSeatStore.load(from: storage)
        #expect(loaded.current?.turn == "b")
        // Leaving keeps the campaign, and a new one does not replace it.
        loaded.endSession()
        #expect(loaded.current == nil)
        #expect(loaded.resumable(host: "a").map(\.id) == [first.id])
        #expect(loaded.resumable(host: "b").isEmpty)
        let second = try required(loaded.start(roster: MobileHotSeatRoster(host: "a", players: ["c"])))
        #expect(second.id != first.id)
        #expect(loaded.resumable(host: "a").map(\.id) == [first.id])
        let resumed = try required(loaded.resume(id: first.id))
        #expect(resumed.turn == "b" && resumed.policy == .atFirstFail)
        #expect(loaded.resumable(host: "a").map(\.id) == [second.id])
    }

    @Test func restartKeepsPlayersAndStartsWithTheHost() throws {
        var store = MobileHotSeatStore()
        var seat = try required(store.start(roster: MobileHotSeatRoster(host: "a", players: ["b"])))
        seat.pass(to: "b"); store.update(seat)
        let fresh = try required(store.restart())
        #expect(fresh.id != seat.id && fresh.turn == "a" && fresh.players == seat.players)
        #expect(fresh.scope != seat.scope)
    }

    @Test func deletingAPlayerEndsSessionsThatNeedThem() throws {
        var store = MobileHotSeatStore()
        _ = store.start(roster: MobileHotSeatRoster(host: "a", players: ["b"]))
        _ = store.start(roster: MobileHotSeatRoster(host: "a", players: ["b", "c"]))
        store.removePlayer("b")
        #expect(store.current?.players == ["a", "c"])
        #expect(store.saved.isEmpty)
    }

    @Test func cloudImportKeepsSoloModeAndLetsEitherParticipantResume() throws {
        var store = MobileHotSeatStore()
        var shared = try #require(MobileHotSeat(host: "a", players: ["b"], policy: .atFirstFail))
        shared.pass(to: "b")
        store.importCloudSessions([shared])
        #expect(store.current == nil)
        #expect(store.sharedSessions(player: "b").map(\.id) == [shared.id])
        #expect(store.sharedSessions(player: "c").isEmpty)
        _ = try required(store.resume(id: shared.id))
        #expect(store.current?.turn == "b" && store.policy == .atFirstFail)
        shared.policy = .everyLevel; shared.pass(to: "a")
        store.importCloudSessions([shared])
        #expect(store.current?.turn == "a" && store.policy == .everyLevel)
        let other = try #require(MobileHotSeat(host: "a", players: ["c"]))
        store.importCloudSessions([other])
        #expect(store.current?.id == shared.id)
    }
    @Test func oldCheckpointsDecodeWithoutAScope() throws {
        let envelope = MobileCheckpointEnvelope(runID: UUID(), engine: "e", engineFingerprint: "f", levelIdentifier: "l",
                                                levelIndex: 0, levelFingerprint: "g", tick: 0, selectedControl: 0,
                                                camera: MobileCameraState(origin: .init(x: 0, y: 0), zoom: 1), payload: Data())
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope)) as? [String: Any])
        object["scope"] = nil; object["owner"] = nil
        let decoded = try JSONDecoder().decode(MobileCheckpointEnvelope.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.scope == nil && decoded.owner == nil)
    }

    @Test func savedLibraryKeepsPreviousSyncedSessionsOutsideTheSelectedRoster() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        var store = MobileHotSeatStore()
        var previous = try #require(MobileHotSeat(host: "ekv", players: ["uva"],
            policy: .atFirstFail, id: "previous", savedAt: Date(timeIntervalSince1970: 100)))
        previous.pass(to: "uva"); previous.savedAt = Date(timeIntervalSince1970: 100)
        let recent = try #require(MobileHotSeat(host: "ekv", players: ["uva"],
            id: "recent", savedAt: Date(timeIntervalSince1970: 200)))
        _ = store.start(roster: MobileHotSeatRoster(host: "other", players: ["guest"]))
        store.importCloudSessions([recent, previous])
        store.importCloudSessions([previous, recent])
        #expect(store.sharedSessions(player: "other").isEmpty)
        #expect(store.savedSessions.map(\.id) == [recent.id, previous.id])
        try store.save(to: storage)
        var reopened = MobileHotSeatStore.load(from: storage)
        let current = try #require(reopened.current)
        #expect(reopened.savedSessions.map(\.id) == [recent.id, previous.id])
        #expect(reopened.resume(id: previous.id) == previous)
        #expect(reopened.current?.turn == "uva" && reopened.policy == .atFirstFail)
        #expect(Set(reopened.savedSessions.map(\.id)) == [current.id, recent.id])
        try reopened.save(to: storage)
        #expect(MobileHotSeatStore.load(from: storage).current == previous)
    }
}
