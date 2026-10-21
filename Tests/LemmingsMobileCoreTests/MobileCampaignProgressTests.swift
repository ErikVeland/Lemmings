import Foundation
import LemmingsAppCore
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileCampaignProgressTests {
    @Test func futureChroniclesProgressCannotFallBackToAnOlderBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = MobileStorage(directory: root)
        var saved = MobileCampaignProgress.Chronicles()
        saved.tribes["Classic"] = .init(index: 1, population: 20, completed: [0: 20], tribe: .classic)
        try storage.save(saved, name: "lemmings3-campaign")
        var future = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        var tribes = try #require(future["tribes"] as? [String: [String: Any]])
        tribes["Classic"]?["version"] = 99
        future["tribes"] = tribes
        let bytes = try JSONSerialization.data(withJSONObject: future)
        let primary = root.appendingPathComponent("lemmings3-campaign.json")
        try bytes.write(to: primary)
        #expect(throws: MobileCheckpointError.version) { try MobileCampaignProgress.reconcile(.init(), storage: storage) }
        #expect(try Data(contentsOf: primary) == bytes)
    }
    @Test func aFutureCampaignCannotBeReplacedByCloudProgress() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = MobileStorage(directory: root)
        let saved = Lemmings2Campaign.Progress(tribe: 0, level: 1, results: [0: result(1)])
        try storage.save(saved, name: "lemmings2-campaign")
        let primary = root.appendingPathComponent("lemmings2-campaign.json")
        var future = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        future["version"] = 99
        let bytes = try JSONSerialization.data(withJSONObject: future)
        try bytes.write(to: primary)
        #expect(throws: (any Error).self) { try MobileCampaignProgress.reconcile(.init(), storage: storage) }
        #expect(try Data(contentsOf: primary) == bytes)
    }
    @Test func translatedLegacyTribeLabelsKeepTheirProgressAndStableCloudKeys() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = MobileStorage(directory: root)
        var old = MobileCampaignProgress.Chronicles()
        old.currentTribe = 2
        old.tribes["Schatten"] = .init(index: 2, population: 20, completed: [0: 20, 1: 20], tribe: .shadow)
        try storage.save(old, name: "lemmings3-campaign")
        let loaded = try #require(storage.load(MobileCampaignProgress.Chronicles.self, name: "lemmings3-campaign"))
        #expect(loaded.progress(for: .shadow)?.completed == [0: 20, 1: 20])
        #expect(loaded.currentTribe == 2)
        #expect(try MobileCampaignProgress.capture(storage: storage).values["nativeL3ShadowPreview.v1.bundled"]
            == .chronicles(loaded.progress(for: .shadow)!))
    }
    private func result(_ saved: Int) -> Lemmings2Campaign.Result {
        .init(startingPopulation: 60, saved: saved, medal: .bronze, levelFingerprint: "fixture")
    }

    @Test func sequelFilesJoinCloudWithoutLearningAndPreserveWholeTribeChains() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let solo = MobileStorage(directory: root.appendingPathComponent("solo"))
        let seat = MobileStorage(directory: root.appendingPathComponent("hotseat.team"))
        let local = Lemmings2Campaign.Progress(tribe: 0, level: 1, results: [0: result(50)])
        try solo.save(local, name: "lemmings2-campaign")
        var chronicles = MobileCampaignProgress.Chronicles()
        chronicles.currentTribe = 2
        chronicles.tribes["Shadow"] = .init(index: 2, population: 20, completed: [0: 20, 1: 20], tribe: .shadow)
        try solo.save(chronicles, name: "lemmings3-campaign")
        let captured = try MobileCampaignProgress.capture(storage: solo)
        #expect(captured.values["nativeL2Campaign.v1.bundled"] == .tribes(local))
        #expect(captured.values["nativeL3ShadowPreview.v1.bundled"] == .chronicles(chronicles.tribes["Shadow"]!))
        #expect(try MobileCampaignProgress.capture(storage: seat).values.isEmpty)

        // A farther low-survivor chain must not borrow the earlier high-survivor result.
        let farther = Lemmings2Campaign.Progress(tribe: 0, level: 2, results: [0: result(1), 1: result(1)])
        var incoming = captured
        incoming.values["nativeL2Campaign.v1.bundled"] = .tribes(farther)
        try MobileCampaignProgress.reconcile(incoming, storage: solo)
        let merged = try MobileCampaignProgress.capture(storage: solo)
        #expect(merged.values["nativeL2Campaign.v1.bundled"] == .tribes(farther))
        #expect(solo.load(MobileCampaignProgress.Chronicles.self, name: "lemmings3-campaign")?.currentTribe == 2)
        #expect(try MobileCampaignProgress.capture(storage: seat).values.isEmpty)
        try MobileCampaignProgress.reconcile(captured, storage: seat)
        #expect(try MobileCampaignProgress.capture(storage: seat) == captured)
        #expect(try MobileCampaignProgress.capture(storage: solo) == merged)
    }

    @Test func corruptCampaignReadsKeepBytesAndRejectDestructiveReconciliation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = MobileStorage(directory: root)
        let saved = Lemmings2Campaign.Progress(tribe: 0, level: 1, results: [0: result(1)])
        try storage.save(saved, name: "lemmings2-campaign")
        let primary = root.appendingPathComponent("lemmings2-campaign.json")
        let backup = root.appendingPathComponent("lemmings2-campaign.json.bak")
        let corrupt = Data("damaged campaign".utf8)
        try corrupt.write(to: primary)
        #expect(try MobileCampaignProgress.capture(storage: storage).values["nativeL2Campaign.v1.bundled"] == .tribes(saved))
        #expect(try Data(contentsOf: primary) == corrupt)
        try corrupt.write(to: backup)
        #expect(throws: (any Error).self) { try MobileCampaignProgress.reconcile(.init(), storage: storage) }
        #expect(try Data(contentsOf: primary) == corrupt && Data(contentsOf: backup) == corrupt)
    }
}
