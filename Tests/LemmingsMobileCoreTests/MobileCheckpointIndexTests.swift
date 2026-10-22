import Foundation
import Testing
@testable import LemmingsMobileCore

private final class ReorderedCheckpointLibrary: MobileGameLibrary {
    let displayName = "Fixture"
    let identifiers: [String?]
    var levels: [MobileLevelSummary] {
        identifiers.indices.map { .init(index: $0, rank: "Fixture", number: $0 + 1, title: "Level") }
    }
    init(_ identifiers: [String?]) { self.identifiers = identifiers }
    func checkpointLevelIdentifier(at index: Int) throws -> String? { identifiers[index] }
    func loadLevel(at index: Int) throws -> MobileLevelContent { throw MobileSessionError.changedLevel }
}

struct MobileCheckpointIndexTests {
    private func checkpoint(_ identifier: String, index: Int) -> MobileCheckpointEnvelope {
        .init(runID: UUID(), engine: "classic", engineFingerprint: "fixture", levelIdentifier: identifier,
              levelIndex: index, levelFingerprint: "fixture", tick: 0, selectedControl: 0,
              camera: .init(origin: .init(x: 0, y: 0), zoom: 1), payload: Data())
    }

    @Test func movedLevelsResumeByIdentityIncludingAnOldIndexBeyondTheEnd() throws {
        let library = ReorderedCheckpointLibrary(["retained-a", "retained-b"])
        #expect(try library.checkpointLevelIndex(for: checkpoint("retained-a", index: 1)) == 0)
        #expect(try library.checkpointLevelIndex(for: checkpoint("retained-b", index: 2)) == 1)
    }

    @Test func removedLevelsNeverResumeTheirReplacement() {
        let library = ReorderedCheckpointLibrary(["retained-a", "retained-b"])
        #expect(throws: MobileSessionError.changedLevel) {
            try library.checkpointLevelIndex(for: checkpoint("removed", index: 1))
        }
    }

    @Test func unchangedAndIndexOnlyLibrariesKeepTheirExistingIndex() throws {
        #expect(try ReorderedCheckpointLibrary(["a", "b"]).checkpointLevelIndex(for: checkpoint("b", index: 1)) == 1)
        #expect(try ReorderedCheckpointLibrary([nil, nil]).checkpointLevelIndex(for: checkpoint("legacy", index: 1)) == 1)
    }
}
