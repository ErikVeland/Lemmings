@preconcurrency import CloudKit
import Foundation
import Testing
@testable import LemmingsAppCore

@MainActor private final class PrivateLibraryDatabase: CloudKitLibraryDatabase {
    var records: [CKRecord.ID: CKRecord] = [:]
    var beforeSave: (() throws -> Void)?
    var writes = 0
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    func prepare() async throws { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    func record(_ id: CKRecord.ID) async throws -> CKRecord {
        guard let record = records[id] else { throw CKError(.unknownItem) }
        return record.copy() as! CKRecord
    }
    func save(_ values: [CKRecord]) async throws {
        let callback = beforeSave; beforeSave = nil; try callback?()
        for record in values {
            guard (record["testRevision"] as? Int ?? 0) == (records[record.recordID]?["testRevision"] as? Int ?? 0) else {
                throw CKError(.serverRecordChanged)
            }
        }
        var staged: [CKRecord.ID: CKRecord] = [:]
        for value in values {
            let record = value.copy() as! CKRecord
            record["testRevision"] = NSNumber(value: (record["testRevision"] as? Int ?? 0) + 1)
            if let asset = record["snapshot"] as? CKAsset, let source = asset.fileURL {
                let file = folder.appendingPathComponent(UUID().uuidString)
                try Data(contentsOf: source).write(to: file)
                record["snapshot"] = CKAsset(fileURL: file)
            }
            staged[record.recordID] = record
        }
        records.merge(staged) { _, new in new }; writes += 1
    }
    func clean() { try? FileManager.default.removeItem(at: folder) }
}

@MainActor struct CloudKitLibraryTests {
    private func id(_ name: String) -> CKRecord.ID { .init(recordName: name, zoneID: CloudKitLibraryStore.zone) }

    @Test func discoversTheSameLibraryAcrossDevicesAndMigratesExistingKeys() async throws {
        let database = PrivateLibraryDatabase(); defer { database.clean() }
        let mac = CloudKitLibraryStore(database: database), tv = CloudKitLibraryStore(database: database)
        let legacy = CloudLibraryIdentity()
        let first = try await mac.discover([legacy])
        #expect(first == [legacy])
        #expect(try await tv.discover([]) == first)
        #expect(database.writes == 1)
    }

    @Test func concurrentIdentityCreationRetainsBothLibraries() async throws {
        let database = PrivateLibraryDatabase(); defer { database.clean() }
        let a = CloudLibraryIdentity(), b = CloudLibraryIdentity()
        database.beforeSave = {
            let record = CKRecord(recordType: "ULPrivateLibrary", recordID: id("library-keys-v2"))
            record["keys"] = try JSONEncoder().encode([b]) as NSData
            record["testRevision"] = NSNumber(value: 1)
            database.records[record.recordID] = record
        }
        let found = try await CloudKitLibraryStore(database: database).discover([a])
        #expect(Set(found.map(\.id)) == [a.id, b.id])
        #expect(try await CloudKitLibraryStore(database: database).discover([]) == found)
    }

    @Test func deviceSnapshotsAreEncryptedAndRetainConcurrentDevices() async throws {
        let database = PrivateLibraryDatabase(); defer { database.clean() }
        let store = CloudKitLibraryStore(database: database)
        let identity = try #require(try await store.discover([]).first)
        let a = UUID().uuidString, b = UUID().uuidString
        let first = try CloudLibraryArchive().encoded()
        try await store.save(first, identity: identity, device: a)
        database.beforeSave = {
            let manifest = database.records[id("vault-" + identity.id)]!.copy() as! CKRecord
            manifest["devices"] = [a, b] as NSArray
            manifest["testRevision"] = NSNumber(value: 2)
            database.records[manifest.recordID] = manifest
            let second = database.records[id("save-" + identity.id + "-" + a)]!.copy() as! CKRecord
            let clone = CKRecord(recordType: second.recordType, recordID: id("save-" + identity.id + "-" + b))
            let asset = try #require(second["snapshot"] as? CKAsset)
            clone["snapshot"] = CKAsset(fileURL: try #require(asset.fileURL))
            database.records[clone.recordID] = clone
        }
        try await store.save(first, identity: identity, device: a)
        let restored = try await store.load(identity)
        #expect(restored.count == 2 && restored.allSatisfy { $0 == first })
        let asset = try #require(database.records[id("save-" + identity.id + "-" + a)]?["snapshot"] as? CKAsset)
        #expect(try Data(contentsOf: #require(asset.fileURL)) != first)
    }

    @Test func corruptKeysAndMissingSnapshotsPreventReplacement() async throws {
        let database = PrivateLibraryDatabase(); defer { database.clean() }
        let store = CloudKitLibraryStore(database: database)
        let identity = try #require(try await store.discover([]).first)
        let manifest = CKRecord(recordType: "ULPrivateLibrary", recordID: id("vault-" + identity.id))
        manifest["devices"] = [UUID().uuidString] as NSArray
        database.records[manifest.recordID] = manifest
        let writes = database.writes
        await #expect(throws: (any Error).self) { try await store.load(identity) }
        let keys = database.records[id("library-keys-v2")]!
        keys["keys"] = Data("broken".utf8) as NSData
        await #expect(throws: (any Error).self) { try await store.discover([identity]) }
        #expect(database.writes == writes)
    }
}
