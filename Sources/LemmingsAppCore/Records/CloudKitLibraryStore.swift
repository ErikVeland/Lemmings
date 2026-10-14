@preconcurrency import CloudKit
import Foundation
import NxlvKit

/// Private iCloud records share the encrypted library across Mac, iOS and TV.
/// Fixed record names avoid query indexes. Conditional writes retain concurrent devices.
@MainActor protocol CloudKitLibraryDatabase: AnyObject {
    func prepare() async throws
    func record(_ id: CKRecord.ID) async throws -> CKRecord
    func save(_ records: [CKRecord]) async throws
}

@MainActor private final class AppleCloudKitLibraryDatabase: CloudKitLibraryDatabase {
    private let container = CKContainer(identifier: "iCloud.academy.glasscode.lemmings")
    private var owner: CKRecord.ID?
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    private var database: CKDatabase { container.privateCloudDatabase }
    func prepare() async throws {
        let current = try await container.userRecordID()
        if let bound = defaults.string(forKey: "CloudLibrary.CloudKitOwner"), bound != current.recordName {
            throw URLError(.userAuthenticationRequired)
        }
        if let owner, owner != current { throw URLError(.userAuthenticationRequired) }
        owner = current
        _ = try await database.save(CKRecordZone(zoneID: CloudKitLibraryStore.zone))
        defaults.set(current.recordName, forKey: "CloudLibrary.CloudKitOwner")
    }
    private func checkAccount() async throws {
        guard try await container.userRecordID() == owner else { throw URLError(.userAuthenticationRequired) }
    }
    func record(_ id: CKRecord.ID) async throws -> CKRecord {
        try await checkAccount()
        let record = try await database.record(for: id)
        try await checkAccount()
        return record
    }
    func save(_ records: [CKRecord]) async throws {
        try await checkAccount()
        let result = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true)
        for value in result.saveResults.values { _ = try value.get() }
        try await checkAccount()
    }
}

@MainActor final class CloudKitLibraryStore {
    static let zone = CKRecordZone.ID(zoneName: "ULPrivateLibraryV2", ownerName: CKCurrentUserDefaultName)
    private func id(_ name: String) -> CKRecord.ID { .init(recordName: name, zoneID: Self.zone) }
    private let database: any CloudKitLibraryDatabase
    init(database: (any CloudKitLibraryDatabase)? = nil, defaults: UserDefaults = .standard) {
        self.database = database ?? AppleCloudKitLibraryDatabase(defaults: defaults)
    }
    private func read(_ name: String) async throws -> CKRecord? {
        do { return try await database.record(id(name)) }
        catch let error as CKError where error.code == .unknownItem { return nil }
    }
    private func conflict(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        if error.code == .serverRecordChanged { return true }
        if error.code == .partialFailure, let errors = error.partialErrorsByItemID {
            return errors.values.contains { ($0 as? CKError)?.code == .serverRecordChanged }
        }
        return false
    }
    private func keys(_ record: CKRecord?) throws -> [CloudLibraryIdentity] {
        guard let record else { return [] }
        guard let data = record["keys"] as? Data, data.count <= 16384 else {
            throw SequelDataError.invalid(L10n.text("The iCloud library keys could not be read. Existing saves were kept."))
        }
        let identities = try JSONDecoder().decode([CloudLibraryIdentity].self, from: data)
        return try Self.merge([], identities)
    }
    static func merge(_ local: [CloudLibraryIdentity], _ remote: [CloudLibraryIdentity]) throws -> [CloudLibraryIdentity] {
        var result: [String: CloudLibraryIdentity] = [:]
        for key in local + remote {
            try key.validate()
            if let previous = result[key.id], previous != key {
                throw SequelDataError.invalid(L10n.text("The library keys conflict. Existing saves were kept."))
            }
            result[key.id] = key
        }
        guard result.count <= 16 else { throw SequelDataError.invalid(L10n.text("Too many linked libraries.")) }
        return result.values.sorted { $0.id < $1.id }
    }
    func discover(_ local: [CloudLibraryIdentity]) async throws -> [CloudLibraryIdentity] {
        try await database.prepare()
        for attempt in 0..<3 {
            let existing = try await read("library-keys-v2")
            let found = try keys(existing)
            var merged = try Self.merge(local, found)
            if merged.isEmpty { merged = [CloudLibraryIdentity()] }
            if merged == found { return merged }
            let record = existing ?? CKRecord(recordType: "ULPrivateLibrary", recordID: id("library-keys-v2"))
            record["keys"] = try JSONEncoder().encode(merged) as NSData
            do { try await database.save([record]); return merged }
            catch { if attempt == 2 || !conflict(error) { throw error } }
        }
        throw URLError(.cannotWriteToFile)
    }
    private func devices(_ record: CKRecord?) throws -> [String] {
        guard let record else { return [] }
        guard let devices = record["devices"] as? [String], devices.count <= 32,
              Set(devices).count == devices.count, devices.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            throw SequelDataError.invalid(L10n.text("Invalid iCloud device list. Existing saves were kept."))
        }
        return devices
    }
    func load(_ identity: CloudLibraryIdentity) async throws -> [Data] {
        let manifest = try await read("vault-" + identity.id)
        var data: [Data] = []
        for device in try devices(manifest) {
            guard let record = try await read("save-" + identity.id + "-" + device),
                  let asset = record["snapshot"] as? CKAsset, let file = asset.fileURL else {
                throw SequelDataError.invalid(L10n.text("An iCloud save could not be read. Existing saves were kept."))
            }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= CloudLibraryArchive.maximumBytes + 28 else { throw SequelDataError.invalid(L10n.text("The cloud save is too large.")) }
            let opened = try identity.open(Data(contentsOf: file))
            _ = try CloudLibraryArchive.decode(opened)
            data.append(opened)
        }
        return data
    }
    func save(_ data: Data, identity: CloudLibraryIdentity, device: String) async throws {
        _ = try CloudLibraryArchive.decode(data)
        guard UUID(uuidString: device) != nil else { throw SequelDataError.invalid("Invalid cloud device.") }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try identity.seal(data).write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }
        for attempt in 0..<3 {
            let existing = try await read("vault-" + identity.id)
            let manifest = existing ?? CKRecord(recordType: "ULPrivateLibrary", recordID: id("vault-" + identity.id))
            // A missing manifest is new. An existing malformed manifest must never be replaced.
            let members = try devices(existing)
            let merged = Array(Set(members + [device])).sorted()
            guard merged.count <= 32 else { throw SequelDataError.invalid(L10n.text("Too many iCloud devices.")) }
            manifest["devices"] = merged as NSArray
            let snapshot = try await read("save-" + identity.id + "-" + device)
                ?? CKRecord(recordType: "ULPrivateLibrary", recordID: id("save-" + identity.id + "-" + device))
            snapshot["snapshot"] = CKAsset(fileURL: file)
            do { try await database.save([manifest, snapshot]); return }
            catch { if attempt == 2 || !conflict(error) { throw error } }
        }
    }
}
