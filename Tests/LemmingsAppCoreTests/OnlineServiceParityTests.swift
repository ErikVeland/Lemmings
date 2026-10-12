import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

@MainActor private final class ScoreTransport: GameCenterServiceTransport {
    let account: GameCenterAccount? = .init(id: "apple-account", name: "Player")
    var submissions: [(String, Int)] = []
    func authenticate(completion: @escaping @MainActor (Result<GameCenterAccount, Error>) -> Void) {
        completion(.success(account!))
    }
    func submit(_ score: Int, boardID: String) async throws { submissions.append((boardID, score)) }
    func load(_ boardID: String) async throws -> WorldwideBoard { .init(entries: [], personal: nil, players: 0) }
}

@MainActor struct OnlineServiceParityTests {
    @Test func sharedGameCenterKeepsConfiguredIDsAndGuestOwnership() async throws {
        let storage = try AppStorage.temporary(named: "online")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let owner = store.records.mainProfileID
        let guest = try #require(store.addProfile(initials: "AB", portrait: 1, select: false))
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "pack", levelID: "level-0",
            levelFingerprint: String(repeating: "a", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let config = TrolleyOnlineConfiguration(enabled: true, starsID: "ul.v1.career.stars", clearsID: "ul.v1.career.cleared",
            perfectID: "ul.v1.career.perfect", levels: [.init(conditions: conditions,
                maximum: .init(value: 10, status: .verified, source: "fixture", date: Date(), buildVersion: "test"), leaderboardID: "ul.v1.level.test", fastestClearID: "ul.v1.speed.test")])
        let level = ArcadeLevel(id: "level", title: "Test", game: "Classic", rules: "classic-dos-v1", total: 10,
                                required: 5, conditions: conditions)
        let run = ArcadeRun(profileID: owner, level: level, saved: 10, didWin: true, skills: ["digger": 1], seconds: 12.34,
                            telemetry: .init(released: 10))
        #expect(store.record(run) != nil)
        let expected = config.scores(attempts: store.records.trolley.attempts, profileID: owner)
        #expect(expected["ul.v1.speed.test"] == 12340)
        let transport = ScoreTransport()
        let service = GameCenterService(configuration: config, transport: transport, defaults: storage.defaults,
                                        recordsStoreProvider: { store })
        service.refresh(profileID: guest.id, boardID: config.starsID, history: store.records.trolley)
        for _ in 0..<100 where service.busy { await Task.yield() }
        #expect(transport.submissions.isEmpty)
        service.refresh(profileID: owner, boardID: config.starsID, history: store.records.trolley)
        for _ in 0..<100 where service.busy { await Task.yield() }
        #expect(Dictionary(transport.submissions, uniquingKeysWith: { _, value in value }) == expected)
    }

    @Test func hostedBrowseRequiresNoSharingOrCredential() throws {
        let storage = try AppStorage.temporary(named: "hosted")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let service = HostedRankingsService(endpoint: URL(string: "https://example.invalid/rankings"), defaults: storage.defaults,
            credentials: { _ in Issue.record("Browsing requested a credential"); return "" }, recordsStoreProvider: { store })
        service.networkEnabled = true
        let request = try service.request("/v1/boards?board=stars")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!service.sharing(store.records.mainProfileID))
    }
}
