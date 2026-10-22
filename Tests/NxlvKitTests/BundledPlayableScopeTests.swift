import Foundation
import Testing
@testable import NxlvKit

struct BundledPlayableScopeTests {
    private let root = URL(fileURLWithPath: "/bundled/LevelPacks")
    private let manifest = Data(#"{"version":1,"exclusions":[{"pack":"0001-fixture.zip","archiveSHA256":"verified","member":"levels.dat#2"}]}"#.utf8)

    @Test func onlyTheExactBundledArchiveIsExcluded() throws {
        let scope = try BundledPlayableScope(directory: root, manifest: manifest)
        let pack = root.appendingPathComponent("0001-fixture.zip")
        #expect(scope.members(in: pack, archiveSHA256: "verified") == ["levels.dat#2"])
        #expect(scope.members(in: pack, archiveSHA256: "changed").isEmpty)
        #expect(scope.members(in: root.appendingPathComponent("0002-fixture.zip"), archiveSHA256: "verified").isEmpty)
        #expect(scope.members(in: URL(fileURLWithPath: "/imports/0001-fixture.zip"), archiveSHA256: "verified").isEmpty)
    }

    @Test func futureManifestDoesNotChangePlayableScope() throws {
        let data = Data(String(decoding: manifest, as: UTF8.self).replacingOccurrences(of: "\"version\":1", with: "\"version\":2").utf8)
        let scope = try BundledPlayableScope(directory: root, manifest: data)
        #expect(scope.members(in: root.appendingPathComponent("0001-fixture.zip"), archiveSHA256: "verified").isEmpty)
    }
}
