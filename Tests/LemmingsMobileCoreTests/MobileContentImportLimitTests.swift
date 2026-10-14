import Testing
@testable import LemmingsMobileCore

struct MobileContentImportLimitTests {
    @Test func importEntryCountStopsAtTheConfiguredLimit() throws {
        try MobileContentStore.validateImportEntryCount(MobileContentStore.maximumImportEntries)

        do {
            try MobileContentStore.validateImportEntryCount(MobileContentStore.maximumImportEntries + 1)
            Issue.record("An import above the entry limit was accepted.")
        } catch let error as MobileContentStoreError {
            #expect(error == .tooManyEntries)
        }
    }

    @Test func fileCopyEnforcesTheActualByteLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mobile-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.dat")
        let destination = root.appendingPathComponent("copy.dat")
        let payload = Data(repeating: 0x5a, count: 1_048_577)
        try payload.write(to: source)

        do {
            _ = try MobileContentStore.copyFile(at: source, to: destination, maximumBytes: 1_048_576)
            Issue.record("A file larger than the remaining import budget was copied.")
        } catch let error as MobileContentStoreError {
            #expect(error == .tooLarge)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }

        let copiedBytes = try MobileContentStore.copyFile(at: source, to: destination,
                                                          maximumBytes: Int64(payload.count))
        #expect(copiedBytes == Int64(payload.count))
        #expect(try Data(contentsOf: destination) == payload)
    }
}
