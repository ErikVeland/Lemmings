import Foundation
import NxlvKit
import Testing
@testable import LemmingsAppCore

@MainActor private final class ProgressCloud {
    var files: [String: [Data]] = [:]
}
@MainActor private final class ProgressTransport: GameProgressTransport {
    var available = true
    var accountID: String? = "same-apple-player"
    let cloud: ProgressCloud
    var offline = false
    var writes = 0
    var afterLoad: (() -> Void)?
    init(_ cloud: ProgressCloud = ProgressCloud()) { self.cloud = cloud }
    func load(name: String) async throws -> [Data] {
        if offline { throw URLError(.notConnectedToInternet) }
        let data = cloud.files[name] ?? []
        afterLoad?()
        return data
    }
    func save(_ data: Data, name: String) async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        writes += 1
        cloud.files[name] = [data]
    }
}

@MainActor struct GameCenterProgressTests {
    private func run(_ owner: String, index: Int = 0, saved: Int = 10) -> ArcadeRun {
        let conditions = TrolleyConditions(gameID: "lemmings", packID: "lemmings-LEVEL-120", levelID: "level-\(index)",
            levelFingerprint: String(repeating: "a", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let level = ArcadeLevel(id: "lemmings:level-\(index)", title: "Level \(index)", game: "Lemmings", rules: "classic-dos-v1",
            total: 10, required: 5, conditions: conditions)
        return .init(profileID: owner, level: level, saved: saved, didWin: true, skills: ["digger": 1], seconds: 10,
            telemetry: .init(released: 10))
    }

    @Test func twoDevicesMergeProgressAndMapTheirDifferentPlayerIDs() async throws {
        let mac = try AppStorage.temporary(named: "cloud-mac"), ios = try AppStorage.temporary(named: "cloud-ios")
        defer { mac.removeTemporaryFiles(); ios.removeTemporaryFiles() }
        let a = ArcadeStore(storage: mac, bundledProofs: nil), b = ArcadeStore(storage: ios, bundledProofs: nil)
        #expect(b.importProfiles([.init(id: "default", initials: "IOS")], activeID: "default"))
        let ownerA = a.records.mainProfileID, ownerB = b.records.mainProfileID
        let guest = try #require(a.addProfile(initials: "GST", portrait: 3, select: false))
        #expect(a.record(run(ownerA, index: 0)) != nil)
        #expect(a.record(run(guest.id, index: 9)) != nil)
        #expect(b.record(run(ownerB, index: 1)) != nil)
        ios.defaults.set([1], forKey: "mobile.completed.release/lemmings")
        mac.defaults.set([0], forKey: GameProgressPreferences.completedKey(pack: "release/lemmings", profileID: ownerA))
        let cloud = ProgressCloud(), ta = ProgressTransport(cloud), tb = ProgressTransport(cloud)
        let sa = GameCenterProgressSync(store: a, defaults: mac.defaults, transport: ta)
        let sb = GameCenterProgressSync(store: b, defaults: ios.defaults, transport: tb)
        await sa.syncNow(); await sb.syncNow(); await sa.syncNow()
        #expect(sa.state == .idle && sb.state == .idle)
        #expect(a.records.trolley.attempts.filter { $0.run.profileID == ownerA }.count == 2)
        #expect(b.records.trolley.attempts.count == 2)
        #expect(b.records.runs.allSatisfy { $0.profileID == ownerB })
        #expect(b.records.profiles.count == 1 && a.records.profile(guest.id) != nil)
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: ownerA, defaults: mac.defaults) == [0, 1])
        #expect(GameProgressPreferences.completed(pack: "release/lemmings", profileID: ownerB, defaults: ios.defaults) == [0, 1])
        let writes = ta.writes + tb.writes
        await sa.syncNow(); await sb.syncNow()
        #expect(ta.writes + tb.writes == writes)
        #expect(a.records.activeProfileID == ownerA && b.records.activeProfileID == ownerB)
    }

    @Test func simultaneousConflictsUnionResultsWithoutDoubleCounting() async throws {
        let storage = try AppStorage.temporary(named: "cloud-conflict")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        let local = run(owner, saved: 8), second = run(owner, saved: 10)
        #expect(store.record(local) != nil)
        var branch = ArcadeRecords()
        #expect(branch.record(local) != nil && branch.record(second) != nil)
        let cloudOwner = GameCenterProgressSync.ownerKey("same-apple-player")
        let first = GameProgressArchive(owner: cloudOwner, records: try store.records.cloudRecords(profileID: owner),
            preferences: .init(values: ["cleared/release/lemmings": .completed([0])]))
        let other = GameProgressArchive(owner: cloudOwner, records: try branch.cloudRecords(profileID: owner),
            preferences: .init(values: ["cleared/release/lemmings": .completed([1])]))
        let transport = ProgressTransport()
        transport.cloud.files[GameCenterProgressSync.fileName(owner: cloudOwner)] = [try JSONEncoder().encode(first), try JSONEncoder().encode(other)]
        let service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        await service.syncNow(); await service.syncNow()
        #expect(service.state == .idle && transport.writes == 1)
        #expect(store.records.trolley.attempts.count == 2)
        #expect(store.records.stats(level: local.level, profileID: owner, assisted: false).attempts == 2)
        #expect(store.records.stats(level: local.level, profileID: owner, assisted: false).clears == 2)
        #expect(store.records.leaderboard(level: local.level, board: .rescue, assisted: false).first?.saved == 10)
    }

    @Test func offlineProgressUploadsOnRetryAndGuestHotSeatKeysStayLocal() async throws {
        let storage = try AppStorage.temporary(named: "cloud-offline")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        let guest = try #require(store.addProfile(initials: "GST", portrait: 1, select: false))
        storage.defaults.set([0], forKey: "mobile.completed.release/lemmings." + owner)
        storage.defaults.set([99], forKey: "mobile.completed.release/lemmings." + guest.id)
        storage.defaults.set([98], forKey: "mobile.completed.release/lemmings.hotseat.match")
        storage.defaults.set(Data([1, 2]), forKey: "HotSeat.match.ClassicGameProgress")
        storage.defaults.set("private/path", forKey: "ClassicDataDirectory")
        #expect(store.record(run(owner)) != nil)
        let transport = ProgressTransport(); transport.offline = true
        let service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        await service.syncNow()
        #expect(service.state == .offline && transport.writes == 0 && store.records.runs.count == 1)
        transport.offline = false
        await service.syncNow()
        let data = try #require(transport.cloud.files.values.first?.first)
        let archive = try GameProgressArchive.decode(data, owner: GameCenterProgressSync.ownerKey("same-apple-player"))
        #expect(archive.preferences.values["cleared/release/lemmings"] == .completed([0]))
        #expect(!String(decoding: data, as: UTF8.self).contains("private/path"))
        #expect(!String(decoding: data, as: UTF8.self).contains(guest.id))
        #expect(archive.records.trolley.replays.isEmpty)
    }

    @Test func livePlayDefersImportAndKeepsTurnOwnership() async throws {
        let storage = try AppStorage.temporary(named: "cloud-live")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        _ = store.addProfile(initials: "GST", portrait: 1, select: false)
        store.prepareHotSeat()
        let turn = store.playingProfileID, seat = store.hotSeatID, roster = store.sessionProfileIDs
        var remote = ArcadeRecords(); #expect(remote.record(run(owner)) != nil)
        let transport = ProgressTransport(), cloudOwner = GameCenterProgressSync.ownerKey("same-apple-player")
        let archive = GameProgressArchive(owner: cloudOwner, records: try remote.cloudRecords(profileID: owner), preferences: .init())
        transport.cloud.files[GameCenterProgressSync.fileName(owner: cloudOwner)] = [try JSONEncoder().encode(archive)]
        let service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        service.canImport = { false }
        await service.syncNow()
        #expect(service.state == .deferred && store.records.runs.isEmpty)
        service.canImport = { true }
        await service.syncNow()
        #expect(service.state == .idle && store.records.runs.count == 1)
        #expect(store.playingProfileID == turn && store.hotSeatID == seat && store.sessionProfileIDs == roster)
    }

    @Test func accountSwitchAndLateSignOutCannotImportOrUploadAnotherPlayer() async throws {
        let storage = try AppStorage.temporary(named: "cloud-account")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil)
        #expect(store.record(run(store.records.mainProfileID)) != nil)
        let transport = ProgressTransport(), service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        transport.afterLoad = { transport.accountID = nil }
        await service.syncNow()
        #expect(service.state == .offline && transport.writes == 0)
        transport.afterLoad = nil; transport.accountID = "other-player"
        await service.syncNow()
        if case .failed = service.state {} else { Issue.record("Switched account was not isolated") }
        #expect(transport.writes == 0)
        transport.accountID = "same-apple-player"
        await service.syncNow()
        #expect(service.state == .idle && transport.writes == 1)
    }

    @Test func corruptFutureAndWrongOwnerSavesArePreserved() async throws {
        for kind in ["corrupt", "future", "owner"] {
            let storage = try AppStorage.temporary(named: "cloud-" + kind)
            defer { storage.removeTemporaryFiles() }
            let store = ArcadeStore(storage: storage, bundledProofs: nil), transport = ProgressTransport()
            let owner = GameCenterProgressSync.ownerKey("same-apple-player")
            let archive = GameProgressArchive(owner: kind == "owner" ? "wrong" : owner,
                records: try store.records.cloudRecords(profileID: store.records.mainProfileID), preferences: .init())
            var data = try JSONEncoder().encode(archive)
            if kind == "corrupt" { data = Data("broken".utf8) }
            if kind == "future" {
                var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]); json["version"] = 2
                data = try JSONSerialization.data(withJSONObject: json)
            }
            let name = GameCenterProgressSync.fileName(owner: owner)
            transport.cloud.files[name] = [data]
            let original = store.records
            let service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
            await service.syncNow()
            if case .failed = service.state {} else { Issue.record("Invalid save was accepted") }
            #expect(transport.writes == 0 && transport.cloud.files[name] == [data] && store.records == original)
        }
    }

    @Test func unsupportedPreferencesCannotWriteDeviceSettings() throws {
        let preferences = GameProgressPreferences(values: ["ClassicSettings": .completed([1])])
        #expect(throws: (any Error).self) { try preferences.validate() }
        let impossible = GameProgressPreferences(values: ["nativeL2Campaign.v1.bundled": .tribes(.init(tribe: 0, level: 0,
            results: [0: .init(startingPopulation: Int.max, saved: Int.max, medal: .gold, levelFingerprint: "invalid")]))])
        #expect(throws: (any Error).self) { try impossible.validate() }
    }

    @Test func failedLocalWriteDoesNotUploadOrReplaceRecords() async throws {
        let storage = try AppStorage.temporary(named: "cloud-write-failure")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        #expect(store.record(run(owner)) != nil)
        let original = store.records
        var other = ArcadeRecords(); #expect(other.record(run(owner, index: 1)) != nil)
        let transport = ProgressTransport(), cloudOwner = GameCenterProgressSync.ownerKey("same-apple-player")
        let archive = GameProgressArchive(owner: cloudOwner, records: try other.cloudRecords(profileID: owner), preferences: .init())
        transport.cloud.files[GameCenterProgressSync.fileName(owner: cloudOwner)] = [try JSONEncoder().encode(archive)]
        // A second writer changes the file after this store has opened it.
        try JSONEncoder().encode(other).write(to: ArcadeStore.recordsFile(storage: storage))
        let service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        await service.syncNow()
        if case .failed = service.state {} else { Issue.record("Failed local save was ignored") }
        #expect(transport.writes == 0 && store.records == original && store.storageError != nil)
    }

    @Test func removingTheLinkedPlayerCannotRestoreThemIntoAGuest() async throws {
        let storage = try AppStorage.temporary(named: "cloud-deleted-player")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        let guest = try #require(store.addProfile(initials: "GST", portrait: 1, select: true))
        #expect(store.record(run(owner)) != nil)
        let transport = ProgressTransport(), service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        await service.syncNow()
        #expect(store.deleteProfile(owner))
        await service.syncNow()
        if case .failed = service.state {} else { Issue.record("Deleted player binding was reassigned") }
        #expect(transport.writes == 1 && store.records.profiles.map(\.id) == [guest.id] && store.records.runs.isEmpty)
    }

    @Test func localChangesDuringMergeAreCapturedBeforeUpload() async throws {
        let storage = try AppStorage.temporary(named: "cloud-local-race")
        defer { storage.removeTemporaryFiles() }
        let store = ArcadeStore(storage: storage, bundledProofs: nil), owner = store.records.mainProfileID
        #expect(store.record(run(owner)) != nil)
        let transport = ProgressTransport(), service = GameCenterProgressSync(store: store, defaults: storage.defaults, transport: transport)
        var changed = false
        service.captureExtra = { _ in
            if !changed { changed = true; #expect(store.record(run(owner, index: 1)) != nil) }
            return .init()
        }
        await service.syncNow()
        #expect(transport.writes == 0)
        await service.syncNow()
        #expect(service.state == .idle && transport.writes == 1 && store.records.runs.count == 2)
    }

    @Test func classicBridgePreservesGapsAndKeepsOrderedAchievementsSeparate() throws {
        let ranks = [ClassicRank(name: "Fun", levelIndices: Array(0..<30)), ClassicRank(name: "Tricky", levelIndices: Array(30..<60))]
        let result = GameProgressPreferences.classicProgress(.init(furthestReached: ["Fun": 2], passed: ["Fun#0"]), completed: [2, 30], ranks: ranks)
        #expect(Set(result.passed) == ["Fun#0", "Fun#2", "Tricky#0"])
        #expect(result.furthestReached == ["Fun": 3, "Tricky": 1])
        var a = GameProgressPreferences(values: ["ClassicAchievementProgress": .achievements(.init(nextOrderedLevel: ["lemmings": 2]))])
        try a.merge(.init(values: ["ClassicAchievementProgress": .achievements(.init(nextOrderedLevel: ["lemmings": 4]))]))
        if case let .achievements(progress) = a.values["ClassicAchievementProgress"] {
            #expect(progress.orderedLevelsPassed(for: .lemmings) == 4 && progress.unlocked.isEmpty)
        } else { Issue.record("Achievement format changed") }
    }

    @Test func learningWinsOverrideDeferredVisitsWithoutChangingTheSavedQueue() throws {
        let storage = try AppStorage.temporary(named: "cloud-learning")
        defer { storage.removeTemporaryFiles() }
        let owner = ArcadeProfile.legacyID
        let lesson = LevelCatalogueIdentity(engine: .classic, packID: "lemmings", levelID: "lesson")
        let another = LevelCatalogueIdentity(engine: .classic, packID: "lemmings", levelID: "another")
        var local = LearningJourneyProgress(), remote = LearningJourneyProgress()
        local.record(lesson, won: false); remote.record(lesson, won: true); remote.record(another, won: false)
        let merged = try GameProgressValue.learning(local).merging(.learning(remote))
        #expect(merged == (try GameProgressValue.learning(remote).merging(.learning(local))))
        let preferences = GameProgressPreferences(values: ["LearningJourneyProgress": merged])
        try preferences.apply(defaults: storage.defaults, profileID: owner)
        #expect(GameProgressPreferences.capture(defaults: storage.defaults, profileID: owner, profileIDs: [owner]).values["LearningJourneyProgress"] == merged)
        let store = try LevelPlaylistStore(profileID: owner, storage: storage)
        let entry = try LevelPlaylistEntry(identity: lesson, catalogueRevision: "catalogue", sourceRevision: "source",
            packNameSnapshot: "Lemmings", levelNameSnapshot: "Lesson", levelNumberSnapshot: 1)
        let queue = try LevelSequenceRun(source: .randomTen, pool: .init(id: "learning-test", summary: "Journey"),
            entries: [entry], seed: 7, algorithm: .splitMix64FisherYatesV1)
        try store.startRun(queue, hotSeatID: "local-hot-seat")
        let originalRun = store.activeRun, originalSaved = store.savedRuns.map(\.run), originalSeat = store.activeRunHotSeatID
        try store.mergeLearningProgress(GameProgressPreferences.learning(profileID: owner, defaults: storage.defaults))
        #expect(store.learningProgress.completed == [lesson] && store.learningProgress.later == [another])
        #expect(store.activeRun == originalRun && store.savedRuns.map(\.run) == originalSaved && store.activeRunHotSeatID == originalSeat)
    }

    @Test func sequelMergesKeepWholeTribeChainsAndBestChroniclesResults() throws {
        let a = Lemmings2Campaign.Progress(tribe: 0, level: 2, results: [
            0: .init(startingPopulation: 60, saved: 50, medal: .gold, levelFingerprint: "0"),
            1: .init(startingPopulation: 50, saved: 40, medal: .gold, levelFingerprint: "1")])
        let b = Lemmings2Campaign.Progress(tribe: 1, level: 1, results: [
            0: .init(startingPopulation: 60, saved: 60, medal: .gold, levelFingerprint: "0"),
            1: .init(startingPopulation: 60, saved: 20, medal: .gold, levelFingerprint: "1"),
            10: .init(startingPopulation: 60, saved: 55, medal: .gold, levelFingerprint: "10")])
        let merged = try GameProgressValue.tribes(a).merging(.tribes(b))
        #expect(merged == (try GameProgressValue.tribes(b).merging(.tribes(a))))
        if case let .tribes(progress) = merged {
            #expect(progress.results[0]?.saved == 50 && progress.results[1]?.startingPopulation == 50)
            #expect(progress.results[10]?.saved == 55)
        } else { Issue.record("Tribes format changed") }
        let l3 = try GameProgressValue.chronicles(.init(index: 1, population: 18, completed: [0: 18], tribe: .classic))
            .merging(.chronicles(.init(index: 2, population: 16, completed: [0: 16, 1: 16], tribe: .classic)))
        if case let .chronicles(progress) = l3 { #expect(progress.completed == [0: 18, 1: 16] && progress.index == 2) }
        else { Issue.record("Chronicles format changed") }
    }
}
