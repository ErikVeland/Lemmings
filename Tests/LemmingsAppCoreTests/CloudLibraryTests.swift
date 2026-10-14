import CryptoKit
import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor private final class LibraryServer {
    var files: [String: [String: Data]] = [:]
}
@MainActor private final class LibraryTransport: CloudLibraryTransport {
    let server: LibraryServer
    var offline = false
    var writes = 0
    var afterLoad: (() -> Void)?
    init(_ server: LibraryServer) { self.server = server }
    func discover(_ identities: [CloudLibraryIdentity]) async throws -> [CloudLibraryIdentity] { identities }
    func load(_ identity: CloudLibraryIdentity) async throws -> [Data] {
        if offline { throw URLError(.notConnectedToInternet) }
        let result = Array(server.files[identity.id, default: [:]].values)
        afterLoad?(); return result
    }
    func save(_ data: Data, identity: CloudLibraryIdentity, device: String) async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        writes += 1; server.files[identity.id, default: [:]][device] = data
    }
}

@MainActor struct CloudLibraryTests {
    private func run(_ owner: String, index: Int, saved: Int = 10) -> ArcadeRun {
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "release/lemmings", levelID: "level-\(index)",
            levelFingerprint: String(repeating: "b", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        return .init(profileID: owner,
            level: .init(id: "level-\(index)", title: "Level \(index)", game: "Classic", rules: "DOS", total: 10, required: 5, conditions: conditions),
            saved: saved, didWin: true, skills: ["digger": 1], seconds: Double(15 + index), telemetry: .init(released: 10))
    }
    @Test func restoresEveryProfilePortraitRecordAndAchievementWithoutMergingNames() async throws {
        let mac = try AppStorage.temporary(named: "library-mac"), mobile = try AppStorage.temporary(named: "library-ios")
        defer { mac.removeTemporaryFiles(); mobile.removeTemporaryFiles() }
        let a = ArcadeStore(storage: mac, bundledProofs: nil), b = ArcadeStore(storage: mobile, bundledProofs: nil)
        #expect(b.importProfiles([.init(id: "default", initials: "LEM")], activeID: "default"))
        let guest = try #require(a.addProfile(initials: "LEM", portrait: 6, select: false))
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        #expect(a.record(run(guest.id, index: 1)) != nil)
        mac.defaults.set([0], forKey: GameProgressPreferences.completedKey(pack: "release/lemmings", profileID: a.records.mainProfileID))
        let identity = CloudLibraryIdentity(), server = LibraryServer()
        let sa = CloudLibrarySync(store: a, storage: mac, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: mobile, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow(); await sb.syncNow()
        #expect(sa.state == .synced && sb.state == .synced)
        #expect(b.records.profiles.count == 2)
        #expect(b.records.profiles.filter { $0.initials == "LEM" }.count == 2)
        let restoredGuest = try #require(b.records.profiles.first { $0.portrait == 6 })
        #expect(b.records.runs.filter { $0.profileID == restoredGuest.id }.count == 1)
        #expect(b.records.careerAchievements(profileID: restoredGuest.id).contains(.allHome))
        #expect(b.records.runs.filter { $0.profileID == "default" }.count == 1)
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: "default", defaults: mobile.defaults) == [0])
        #expect(b.records.activeProfileID == "default")
    }
    @Test func existingIndependentPlayersRemainSeparateWhenLibrariesAreLinked() async throws {
        let aa = try AppStorage.temporary(named: "existing-a"), bb = try AppStorage.temporary(named: "existing-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        #expect(b.record(run(b.records.mainProfileID, index: 1)) != nil)
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        #expect(a.records.profiles.count == 2 && b.records.profiles.count == 2)
        #expect(a.records.runs.filter { $0.profileID == a.records.mainProfileID }.count == 1)
        #expect(b.records.runs.filter { $0.profileID == b.records.mainProfileID }.count == 1)
    }
    @Test func copiedPlayerIDsRestoreNewerProgressWithoutDuplicatingPlayers() async throws {
        let aa = try AppStorage.temporary(named: "copied-a"), bb = try AppStorage.temporary(named: "copied-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        let player = ArcadeProfile(initials: "TEST", portrait: 4)
        #expect(a.importProfiles([player], activeID: player.id))
        #expect(b.importProfiles([player], activeID: player.id))
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        #expect(a.record(run(player.id, index: 0)) != nil)
        await sa.syncNow(); await sb.syncNow()
        #expect(b.records.profiles == [player])
        #expect(b.records.runs.count == 1)
        #expect(b.record(run(player.id, index: 1)) != nil)
        await sb.syncNow(); await sa.syncNow()
        #expect(a.records.profiles == [player] && a.records.runs.count == 2)
        await sa.syncNow(); await sb.syncNow()
        #expect(b.records.runs.count == 2)
    }
    @Test func originalPlayerUUIDFindsAnOlderCloudIdentityWithoutResultHistory() async throws {
        let storage = try AppStorage.temporary(named: "older-cloud-id")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        let player = ArcadeProfile(initials: "TEST", portrait: 4)
        #expect(store.importProfiles([player], activeID: player.id))
        let global = UUID().uuidString.lowercased(), device = UUID().uuidString.lowercased()
        let progress = GameProgressPreferences(values: ["cleared/release/lemmings": .completed([0, 1, 2])])
        let cloud = CloudLibraryArchive.Player(profile: .init(id: global, initials: player.initials, portrait: player.portrait),
            records: try ArcadeRecords().cloudRecords(profileID: ArcadeProfile.legacyID), progress: progress,
            stamp: .init(counter: 9, device: device), sourceProfileIDs: [player.id.lowercased()])
        let identity = CloudLibraryIdentity(), server = LibraryServer()
        server.files[identity.id] = [device: try CloudLibraryArchive(players: [global: cloud], primary: global).encoded()]
        let sync = CloudLibrarySync(store: store, storage: storage, transport: LibraryTransport(server), identities: [identity])
        await sync.syncNow(); await sync.syncNow()
        #expect(sync.state == .synced && store.records.profiles == [player])
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: player.id, defaults: storage.defaults) == [0, 1, 2])
        let versions = try server.files[identity.id]!.values.map { try CloudLibraryArchive.decode($0) }
        #expect(versions.allSatisfy { $0.players.count == 1 && $0.players[global] != nil })
    }
    @Test func copiedLegacyResultsRecoverIdentityAndIdenticalHotSeatRevision() async throws {
        let aa = try AppStorage.temporary(named: "legacy-copy-a"), bb = try AppStorage.temporary(named: "legacy-copy-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        _ = try #require(a.addProfile(initials: "GF", portrait: 7, select: false))
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        a.prepareHotSeat(); a.turnPolicy = .atFirstFail
        #expect(a.passSessionTurn(after: a.records.mainProfileID))
        let seat = try #require(a.hotSeatID)
        let progress = GameProgressPreferences(values: ["cleared/release/lemmings": .completed([0]),
            "nativeL2Campaign.v1.bundled": .tribes(.init(tribe: 0, level: 1, results: [0: .init(startingPopulation: 60, saved: 48, medal: .gold, levelFingerprint: "fixture")])),
            "nativeL3ClassicPreview.v1.bundled": .chronicles(.init(index: 1, population: 28, completed: [0: 28], tribe: .classic))])
        try progress.apply(defaults: aa.defaults, profileID: a.records.mainProfileID, sessionID: seat)
        // Copy the records and session without copying the device sync file.
        _ = try b.mergeLibraryPlayers(try a.records.profiles.map { ($0, try a.records.cloudRecords(profileID: $0.id)) }, deleted: [])
        try b.importLibraryHotSeats(a.libraryHotSeats)
        try progress.apply(defaults: bb.defaults, profileID: b.records.mainProfileID, sessionID: seat)
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        #expect(sa.state == .synced && sb.state == .synced)
        #expect(a.records.profiles.count == 2 && b.records.profiles.count == 2)
        #expect(b.libraryHotSeats.map(\.id) == [seat])
        // Advance the original campaign, then restore its descendant on the copy.
        var advanced = progress; advanced.addCompleted([1], pack: "release/lemmings")
        try advanced.apply(defaults: aa.defaults, profileID: a.records.mainProfileID, sessionID: seat)
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow(); await sb.syncNow()
        #expect(b.libraryHotSeats.map(\.id) == [seat])
        #expect(GameProgressPreferences.capture(defaults: bb.defaults, profileID: b.records.mainProfileID,
            profileIDs: b.records.profiles.map(\.id), sessionID: seat) == advanced)
        #expect(!b.hotSeatIsActive)
        #expect(b.resumeHotSeat(id: seat))
        #expect(b.playingProfile?.portrait == 7 && b.turnPolicy == .atFirstFail)
    }
    @Test func deletingAnOlderIdentityAlsoRemovesItsOriginalUUID() throws {
        let global = UUID().uuidString.lowercased(), source = UUID().uuidString.lowercased()
        let device = UUID().uuidString.lowercased()
        let player = CloudLibraryArchive.Player(profile: .init(id: global, initials: "TEST"),
            records: try ArcadeRecords().cloudRecords(profileID: ArcadeProfile.legacyID), progress: .init(),
            stamp: .init(counter: 1, device: device), sourceProfileIDs: [source])
        var archive = CloudLibraryArchive(players: [global: player], primary: global)
        try archive.merge(.init(deleted: [global]))
        #expect(archive.deleted == [global, source] && archive.players.isEmpty)
        var copy = player; copy.profile = .init(id: source, initials: "TEST")
        try archive.merge(.init(players: [source: copy], primary: source))
        #expect(archive.players.isEmpty)
    }
    @Test func previewBuildRestoresLatestSharedLibraryByDefault() async throws {
        let aa = try AppStorage.temporary(named: "preview-source"), bb = try AppStorage.temporary(named: "preview-destination")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let preview = AppStorage(applicationSupport: bb.applicationSupport, resources: bb.resources,
            defaults: bb.defaults, isPreviewBuild: true)
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: preview, bundledProofs: nil)
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: preview, transport: LibraryTransport(server), identities: [identity])
        try GameProgressPreferences(values: ["cleared/release/lemmings": .completed([]),
            "ClassicGameProgress": .classic(.init(furthestReached: ["Fun": 0], passed: []))])
            .apply(defaults: bb.defaults, profileID: b.records.mainProfileID)
        sb.captureExtra = { _, _ in .init(values: ["LearningJourneyProgress": .learning(.init())]) }
        #expect(sb.enabled)
        await sa.syncNow(); await sb.syncNow()
        #expect(b.records.runs.count == 1 && b.records.profiles.count == 1)
        let integration = AppStorage(applicationSupport: bb.applicationSupport, resources: bb.resources,
            defaults: bb.defaults, isIntegrationTestBuild: true)
        #expect(!CloudLibrarySync(store: b, storage: integration, transport: LibraryTransport(server)).enabled)
        sb.enabled = false
        #expect(!CloudLibrarySync(store: b, storage: preview, transport: LibraryTransport(server)).enabled)
    }
    @Test func sharedLearningProgressUsesItsSessionAndKeepsSoloSeparate() throws {
        let storage = try AppStorage.temporary(named: "shared-learning")
        defer { storage.removeTemporaryFiles() }
        var solo = LearningJourneyProgress(), shared = LearningJourneyProgress()
        let first = LevelCatalogueIdentity(engine: .classic, packID: "release/lemmings", levelID: "level-0")
        let second = LevelCatalogueIdentity(engine: .classic, packID: "release/lemmings", levelID: "level-1")
        solo.record(first, won: true); shared.record(second, won: true)
        try GameProgressPreferences(values: ["LearningJourneyProgress": .learning(solo)])
            .apply(defaults: storage.defaults, profileID: "default")
        try GameProgressPreferences(values: ["LearningJourneyProgress": .learning(shared)])
            .apply(defaults: storage.defaults, profileID: "default", sessionID: "seat")
        #expect(GameProgressPreferences.learning(profileID: "default", defaults: storage.defaults) == solo)
        #expect(GameProgressPreferences.learning(profileID: "default", sessionID: "seat", defaults: storage.defaults) == shared)
        #expect(GameProgressPreferences.learning(profileID: "another-player", sessionID: "seat", defaults: storage.defaults) == shared)
    }
    @Test func offlineResultsMergeOnReconnectAndRepeatedReceiptDoesNotDuplicateAttempts() async throws {
        let aa = try AppStorage.temporary(named: "offline-a"), bb = try AppStorage.temporary(named: "offline-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        let server = LibraryServer(), identity = CloudLibraryIdentity(), ta = LibraryTransport(server), tb = LibraryTransport(server)
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        let sa = CloudLibrarySync(store: a, storage: aa, transport: ta, identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: tb, identities: [identity])
        await sa.syncNow(); await sb.syncNow()
        ta.offline = true; tb.offline = true
        #expect(a.record(run(a.records.mainProfileID, index: 1)) != nil)
        #expect(b.record(run(b.records.mainProfileID, index: 2)) != nil)
        await sa.syncNow(); await sb.syncNow()
        #expect(sa.state == .offline && sb.state == .offline)
        ta.offline = false; tb.offline = false
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        #expect(a.records.trolley.attempts.count == 3 && b.records.trolley.attempts.count == 3)
    }
    @Test func importsWaitForSafeMenuAndLocalMutationDuringFetchGetsAnotherPass() async throws {
        let aa = try AppStorage.temporary(named: "safe-a"), bb = try AppStorage.temporary(named: "safe-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        let server = LibraryServer(), identity = CloudLibraryIdentity(), ta = LibraryTransport(server), tb = LibraryTransport(server)
        #expect(a.record(run(a.records.mainProfileID, index: 0)) != nil)
        let sa = CloudLibrarySync(store: a, storage: aa, transport: ta, identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: tb, identities: [identity])
        sb.canImport = { false }
        await sa.syncNow(); await sb.syncNow()
        #expect(sb.state == .pending && b.records.runs.isEmpty)
        sb.canImport = { true }; await sb.syncNow()
        #expect(b.records.runs.count == 1)
        tb.afterLoad = { b.notifyProgressChanged() }
        let writes = tb.writes
        await sb.syncNow()
        #expect(sb.state == .pending && tb.writes == writes)
        sb.stop()
    }
    @Test func tombstonesPreventAnOfflineDeviceFromResurrectingADeletedPlayer() async throws {
        let aa = try AppStorage.temporary(named: "delete-a"), bb = try AppStorage.temporary(named: "delete-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        let guest = try #require(a.addProfile(initials: "GF", portrait: 7, select: false))
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow()
        #expect(a.deleteProfile(guest.id))
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        #expect(a.records.profiles.count == 1 && b.records.profiles.count == 1)
        #expect(b.records.profiles.allSatisfy { $0.portrait != 7 })
    }
    @Test func hotSeatRestoresRosterPolicyTurnAndSharedProgressAcrossEngines() async throws {
        let aa = try AppStorage.temporary(named: "seat-a"), bb = try AppStorage.temporary(named: "seat-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        let guest = try #require(a.addProfile(initials: "GF", portrait: 7, select: false))
        a.prepareHotSeat(); a.turnPolicy = .atFirstFail
        #expect(a.passSessionTurn(after: a.records.activeProfileID))
        let seat = try #require(a.hotSeatID)
        let progress = GameProgressPreferences(values: ["cleared/release/lemmings": .completed([0, 1]),
            "nativeL2Campaign.v1.bundled": .tribes(.init(tribe: 0, level: 1, results: [0: .init(startingPopulation: 60, saved: 50, medal: .gold, levelFingerprint: "fixture")])),
            "nativeL3ClassicPreview.v1.bundled": .chronicles(.init(index: 1, population: 30, completed: [0: 30], tribe: .classic))])
        try progress.apply(defaults: aa.defaults, profileID: a.records.mainProfileID, sessionID: seat)
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow()
        let restored = try #require(b.savedHotSeats.first { $0.id == seat })
        #expect(restored.policy == .atFirstFail)
        #expect(b.records.profile(restored.turn ?? "")?.portrait == guest.portrait)
        #expect(!b.hotSeatIsActive)
        #expect(b.resumeHotSeat(id: seat))
        #expect(b.playingProfile?.portrait == 7)
        #expect(GameProgressPreferences.capture(defaults: bb.defaults, profileID: b.records.mainProfileID,
            profileIDs: b.records.profiles.map(\.id), sessionID: seat) == progress)
        b.endHotSeat()
        let girlfriend = try #require(b.records.profiles.first { $0.portrait == 7 })
        b.selectProfile(girlfriend.id)
        #expect(b.savedHotSeats.contains { $0.id == seat })
        b.prepareHotSeat()
        #expect(b.hotSeatID == seat && b.playingProfile?.portrait == 7)
        #expect(b.records.activeProfileID == restored.host)
    }
    @Test func divergentHotSeatVersionsRetainBothBranchesAndAdvanceIndependently() throws {
        let device = UUID().uuidString.lowercased(), p = UUID().uuidString.lowercased(), q = UUID().uuidString.lowercased(), id = UUID().uuidString.lowercased()
        var archive = CloudLibraryArchive()
        for player in [p, q] {
            archive.players[player] = .init(profile: .init(id: player, initials: "LEM"), records: try ArcadeRecords().cloudRecords(profileID: ArcadeProfile.legacyID),
                progress: .init(), stamp: .init(counter: 1, device: device))
        }
        let parent = CloudLibraryArchive.Seat(id: id, host: p, players: [p, q], turn: p, everyLevel: true, progress: .init(), stamp: .init(counter: 2, device: device))
        var left = parent, right = parent
        left.revision = UUID().uuidString.lowercased(); left.ancestors = [parent.revision]; left.turn = q
        right.revision = UUID().uuidString.lowercased(); right.ancestors = [parent.revision]
        right.progress.addCompleted([0], pack: "release/lemmings")
        archive.seats[id] = [left]
        var incoming = archive; incoming.seats[id] = [right]
        try archive.merge(incoming)
        #expect(archive.seats[id]?.count == 2)
        let first = archive
        try archive.merge(incoming); #expect(archive == first)
        #expect(left.branchID != right.branchID)
        var descendant = left; descendant.revision = UUID().uuidString.lowercased(); descendant.ancestors.insert(left.revision)
        incoming.seats[id] = [descendant]
        try archive.merge(incoming)
        #expect(Set(archive.seats[id]!.map(\.revision)) == [descendant.revision, right.revision])
    }
    @Test func offlineHotSeatForksKeepProgressAfterRepeatedImports() async throws {
        let aa = try AppStorage.temporary(named: "fork-a"), bb = try AppStorage.temporary(named: "fork-b")
        defer { aa.removeTemporaryFiles(); bb.removeTemporaryFiles() }
        let a = ArcadeStore(storage: aa, bundledProofs: nil), b = ArcadeStore(storage: bb, bundledProofs: nil)
        _ = try #require(a.addProfile(initials: "GF", portrait: 7, select: false))
        a.prepareHotSeat()
        let original = try #require(a.hotSeatID)
        let server = LibraryServer(), identity = CloudLibraryIdentity()
        let sa = CloudLibrarySync(store: a, storage: aa, transport: LibraryTransport(server), identities: [identity])
        let sb = CloudLibrarySync(store: b, storage: bb, transport: LibraryTransport(server), identities: [identity])
        await sa.syncNow(); await sb.syncNow()
        #expect(b.resumeHotSeat(id: original))
        try GameProgressPreferences(values: ["cleared/release/lemmings": .completed([0])])
            .apply(defaults: aa.defaults, profileID: a.records.mainProfileID, sessionID: original)
        try GameProgressPreferences(values: ["cleared/release/lemmings": .completed([1])])
            .apply(defaults: bb.defaults, profileID: b.records.mainProfileID, sessionID: original)
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        let fork = try #require(b.libraryHotSeats.first { $0.id != original })
        let old = GameProgressPreferences.capture(defaults: bb.defaults, profileID: fork.host,
            profileIDs: b.records.profiles.map(\.id), sessionID: fork.id)
        var advanced = old; advanced.addCompleted([5], pack: "release/lemmings")
        try advanced.apply(defaults: bb.defaults, profileID: fork.host, sessionID: fork.id)
        await sb.syncNow(); await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        let restored = GameProgressPreferences.capture(defaults: aa.defaults, profileID: a.records.mainProfileID,
            profileIDs: a.records.profiles.map(\.id), sessionID: fork.id)
        #expect(restored == advanced)
        #expect(a.libraryHotSeats.contains { $0.id == original })
        #expect(b.libraryHotSeats.contains { $0.id == fork.id })
    }
    @Test func encryptionRejectsWrongLibraryKeyAndTamperedBytes() throws {
        let identity = CloudLibraryIdentity(), other = CloudLibraryIdentity()
        let archive = try CloudLibraryArchive().encoded(), sealed = try identity.seal(archive)
        #expect(try identity.open(sealed) == archive)
        #expect(throws: (any Error).self) { try other.open(sealed) }
        var corrupt = sealed; corrupt[corrupt.count / 2] ^= 1
        #expect(throws: (any Error).self) { try identity.open(corrupt) }
        #expect(!String(decoding: sealed, as: UTF8.self).contains("players"))
    }
    @Test func linkLookupDoesNotRevealTheKeyThatDecryptsLibraryCredentials() throws {
        let code = "ABCDEFGH2345"
        let data = try JSONEncoder().encode([CloudLibraryIdentity()])
        let encrypted = try AES.GCM.seal(data, using: AppleCloudLibraryTransport.linkKey(code))
        #expect(try AES.GCM.open(encrypted, using: AppleCloudLibraryTransport.linkKey(code)) == data)
        #expect(throws: (any Error).self) {
            try AES.GCM.open(encrypted, using: SymmetricKey(data: AppleCloudLibraryTransport.linkLookup(code)))
        }
    }
    @Test func malformedCloudArchiveNeverImportsOrOverwritesIt() async throws {
        let storage = try AppStorage.temporary(named: "bad-library")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), server = LibraryServer(), identity = CloudLibraryIdentity()
        server.files[identity.id] = [UUID().uuidString: Data("{\"version\":999}".utf8)]
        let transport = LibraryTransport(server)
        let sync = CloudLibrarySync(store: store, storage: storage, transport: transport, identities: [identity])
        let before = store.records
        await sync.syncNow()
        if case .failed = sync.state {} else { Issue.record("Expected a preserved malformed archive") }
        #expect(transport.writes == 0 && store.records == before)
    }
}
