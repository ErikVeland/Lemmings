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
}
