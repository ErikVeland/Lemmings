import Foundation
import Testing
import NxlvKit
@testable import LemmingsAppCore

@MainActor private final class AutomaticRankingTransport: HostedRankingsTransport, AnonymousTelemetryTransport {
    var requests: [URLRequest] = []
    var onRegistration: (() -> Void)?
    var offline = false
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if offline { throw URLError(.notConnectedToInternet) }
        if request.url?.path.hasSuffix("/players") == true { onRegistration?() }
        return (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { try await data(for: request) }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) { throw URLError(.unsupportedURL) }
    var runs: [URLRequest] { requests.filter { $0.url?.path.hasSuffix("/runs") == true } }
}

@MainActor struct AutomaticRankingSharingTests {
    private func run(profile: String, game: String) -> ArcadeRun {
        let conditions = TrolleyConditions(gameID: game, packID: "test", levelID: "1", levelFingerprint: "test",
            rulesetVersion: "v1", physicsMode: game, population: 10, rescueRequirement: 5,
            startingSkills: ["builder": 5], timeLimitSeconds: 300)
        return .init(profileID: profile, level: .init(id: game, title: "Test", game: game, rules: "v1", total: 10,
            required: 5, conditions: conditions), saved: 10, didWin: true, skills: ["builder": 1], seconds: 10,
            telemetry: .init(released: 10))
    }
    private func service(storage: AppStorage, store: ArcadeStore, telemetry: AnonymousTelemetry,
                         transport: AutomaticRankingTransport) -> HostedRankingsService {
        let service = HostedRankingsService(endpoint: URL(string: "https://example.invalid/rankings"), transport: transport,
            defaults: storage.defaults, credentials: { "test-credential-" + $0 }, countSharing: { telemetry.sharesCounts },
            recordsStoreProvider: { store })
        service.networkEnabled = true
        telemetry.onSharingChanged = { [weak service] in service?.countSharingChanged() }
        return service
    }
    private func drain(_ service: HostedRankingsService) async throws {
        for _ in 0..<500 where service.syncing || service.busy { try await Task.sleep(for: .milliseconds(1)) }
        #expect(!service.syncing && !service.busy)
    }

    @Test func enablingCountsBackfillsEveryProfileAndEngineWithoutOpeningABoard() async throws {
        let storage = try AppStorage.temporary(named: "automatic-rankings")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let host = store.records.activeProfileID
        let guest = try #require(store.addProfile(initials: "PAL", portrait: 2, select: false))
        for game in ["lemmings", "lemmings2", "lemmings3"] { #expect(store.record(run(profile: host, game: game)) != nil) }
        #expect(store.record(run(profile: guest.id, game: "neolemmix")) != nil)
        let transport = AutomaticRankingTransport()
        let telemetry = AnonymousTelemetry(storage: storage, endpoint: URL(string: "https://example.invalid/counts"), transport: transport)
        let service = service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        service.countSharingChanged()
        #expect(transport.requests.isEmpty)
        telemetry.setSharing(true)
        try await drain(service)
        #expect(service.sharing(host) && service.sharing(guest.id))
        #expect(transport.runs.count == 4)
        let games = try transport.runs.map { request in
            let data = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let conditions = try #require(payload["conditionsJSON"] as? String)
            return try JSONDecoder().decode(TrolleyConditions.self, from: Data(conditions.utf8)).gameID
        }
        #expect(Set(games) == ["lemmings", "lemmings2", "lemmings3", "neolemmix"])
        #expect(Set(transport.runs.compactMap { $0.value(forHTTPHeaderField: "Authorization") }).count == 2)
        #expect(storage.defaults.object(forKey: "HostedRankings.share." + host) == nil)
        service.countSharingChanged(); try await drain(service)
        #expect(transport.runs.count == 4)
    }

    @Test func alreadySharingCountsBackfillsAtLaunchAndRetriesOfflineRecords() async throws {
        let storage = try AppStorage.temporary(named: "automatic-restart")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), transport = AutomaticRankingTransport()
        let host = store.records.activeProfileID
        #expect(store.record(run(profile: host, game: "lemmings3")) != nil)
        storage.defaults.set(true, forKey: AnonymousTelemetry.consentKey)
        let telemetry = AnonymousTelemetry(storage: storage, endpoint: URL(string: "https://example.invalid/counts"), transport: transport)
        let service = service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        transport.offline = true
        service.countSharingChanged(); try await drain(service)
        #expect(transport.runs.isEmpty)
        transport.offline = false
        service.completed(profileID: host); try await drain(service)
        #expect(transport.runs.count == 1)
        telemetry.setSharing(false)
        #expect(!service.sharing(host))
        service.completed(profileID: host); try await drain(service)
        #expect(transport.runs.count == 1)
    }

    @Test func explicitOptOutAndRemovalSurviveCountsChangesAndRestart() async throws {
        let storage = try AppStorage.temporary(named: "automatic-optout")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), transport = AutomaticRankingTransport()
        let host = store.records.activeProfileID
        #expect(store.record(run(profile: host, game: "lemmings")) != nil)
        let telemetry = AnonymousTelemetry(storage: storage, endpoint: URL(string: "https://example.invalid/counts"), transport: transport)
        let service = service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        service.setSharing(false, profile: host)
        telemetry.setSharing(true); try await drain(service)
        #expect(transport.runs.isEmpty && !service.sharing(host))
        service.setSharing(true, profile: host); try await drain(service)
        #expect(transport.runs.count == 1)
        service.remove(profile: host); try await drain(service)
        telemetry.setSharing(false); telemetry.setSharing(true); try await drain(service)
        let restarted = self.service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        restarted.countSharingChanged(); try await drain(restarted)
        #expect(!restarted.sharing(host) && !restarted.hasShared(host))
        #expect(transport.runs.count == 1)
        #expect(transport.requests.contains { $0.httpMethod == "DELETE" })
    }

    @Test func disablingCountsDuringRegistrationStopsScoreUploads() async throws {
        let storage = try AppStorage.temporary(named: "automatic-stop")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), transport = AutomaticRankingTransport()
        let host = store.records.activeProfileID
        #expect(store.record(run(profile: host, game: "lemmings2")) != nil)
        let telemetry = AnonymousTelemetry(storage: storage, endpoint: URL(string: "https://example.invalid/counts"), transport: transport)
        let service = service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        transport.onRegistration = { telemetry.setSharing(false) }
        telemetry.setSharing(true); try await drain(service)
        #expect(transport.runs.isEmpty && !service.sharing(host))
    }

    @Test func explicitRecordsOptInWorksWithoutCountSharing() async throws {
        let storage = try AppStorage.temporary(named: "automatic-separate-optin")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), transport = AutomaticRankingTransport()
        let host = store.records.activeProfileID
        #expect(store.record(run(profile: host, game: "lemmings")) != nil)
        let telemetry = AnonymousTelemetry(storage: storage, endpoint: URL(string: "https://example.invalid/counts"), transport: transport)
        let service = service(storage: storage, store: store, telemetry: telemetry, transport: transport)
        service.setSharing(true, profile: host); try await drain(service)
        #expect(service.sharing(host) && !telemetry.sharesCounts && transport.runs.count == 1)
    }
}
