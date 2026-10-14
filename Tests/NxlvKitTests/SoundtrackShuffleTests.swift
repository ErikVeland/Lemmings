import Foundation
import Testing
@testable import NxlvKit

struct SoundtrackShuffleTests {
    private func catalogue() throws -> SoundtrackCatalogue {
        let variant: (String, String) -> [String: String] = { id, confidence in
            ["id": id, "path": id + ".mod", "port": "amiga", "quality": "native-module",
             "remix": "original", "confidence": confidence, "sourcePath": id + ".mod"]
        }
        let tracks: [[String: Any]] = [
            ["id": "classic.theme", "game": "classic", "title": "Theme", "role": "level",
             "variants": [variant("current", "documented"), variant("alternate", "documented"), variant("missing", "documented"), variant("guess", "unverified")]],
            ["id": "lemmings2.theme", "game": "lemmings2", "title": "Tribe", "role": "level", "variants": [variant("tribe", "documented")]],
            ["id": "lemmings3.theme", "game": "lemmings3", "title": "Chronicles", "role": "level", "variants": [variant("chronicles", "documented")]],
            ["id": "menu", "game": "classic", "title": "Menu", "role": "menu", "variants": [variant("menu", "documented")]]]
        return try SoundtrackCatalogue(data: JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "tracks": tracks]))
    }
    @Test func sameTrackKeepsCompositionAndExcludesUnavailableAndCurrentVersions() throws {
        let catalogue = try catalogue()
        let available: Set<String> = ["current.mod", "alternate.mod", "guess.mod", "tribe.mod", "chronicles.mod", "menu.mod"]
        #expect(catalogue.shuffleCandidates(currentPath: "current.mod", scope: .sameTrack, availablePaths: available).map(\.id) == ["alternate"])
        #expect(catalogue.shuffleCandidates(currentPath: "unknown.mod", scope: .sameTrack, availablePaths: available).isEmpty)
        #expect(catalogue.shuffleCandidates(currentPath: "unknown.mod", scope: .sameTrack, availablePaths: available,
            fallbackTrackID: "classic.theme").map(\.id) == ["alternate", "current"])
    }
    @Test func allTracksIncludesAllThreeGamesWithoutMenuAndResultCues() throws {
        let catalogue = try catalogue()
        #expect(catalogue.shuffleCandidates(currentPath: "current.mod", scope: .allTracks,
            availablePaths: ["current.mod", "alternate.mod", "tribe.mod", "chronicles.mod", "menu.mod"]).map(\.id) == ["alternate", "chronicles", "tribe"])
        #expect(catalogue.shuffleCandidates(currentPath: "current.mod", scope: .sameTrack, availablePaths: ["current.mod"]).isEmpty)
    }
    @Test func mainBundleShuffleChangesMusicInAllThreeGames() throws {
        let catalogue = try catalogue()
        let available: Set<String> = ["current.mod", "tribe.mod", "chronicles.mod", "menu.mod", "guess.mod"]
        for current in ["current.mod", "tribe.mod", "chronicles.mod"] {
            let candidates = catalogue.shuffleCandidates(currentPath: current, scope: .sameTrack, availablePaths: available)
            #expect(candidates.count == 2)
            #expect(!candidates.contains { $0.path == current || $0.path == "menu.mod" || $0.path == "guess.mod" })
        }
    }
}
