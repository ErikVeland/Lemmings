import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileBuildInfoTests {
    @Test func welcomeTracksInstalledBuildIdentityInsteadOfReusedBuildNumber() throws {
        let suite = "MobileBuildInfoTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        // An older TV frontend can already have acknowledged build 1.
        defaults.set(1, forKey: "mobile.whatsNew.seenBuild")
        let first = MobileBuildInfo(version: "2.0", build: "1", identity: "first",
                                    builtAt: "2026-10-14T13:00:00Z", changes: ["First change"])
        #expect(first.needsWelcome(in: defaults))
        #expect(first.needsWelcome(in: defaults)) // Opening alone must not acknowledge it.
        first.acknowledge(in: defaults)
        #expect(!first.needsWelcome(in: defaults))
        let installedAgain = try JSONDecoder().decode(MobileBuildInfo.self, from: JSONEncoder().encode(first))
        #expect(!installedAgain.needsWelcome(in: defaults))
        let rebuild = MobileBuildInfo(version: "2.0", build: "1", identity: "second",
                                      builtAt: first.builtAt, changes: ["Second change"])
        #expect(rebuild.needsWelcome(in: defaults))
        #expect(defaults.integer(forKey: "mobile.whatsNew.seenBuild") == 1)
    }

    @Test func missingManifestRetainsVersionAndBuildWithoutInventingChanges() {
        let info = MobileBuildInfo.current(in: Bundle(for: NSObject.self))
        #expect(!info.identity.isEmpty)
        #expect(info.changes.isEmpty)
        #expect(info.dateLabel.isEmpty)
    }
}
