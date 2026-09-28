import Foundation
import Testing

@testable import NxlvKit

@Suite("NeoLemmix final-state oracle")
struct NeoLemmixFinalStateTests {
    private func simulation(solidX: Int) throws -> NeoLemmixSimulation {
        var terrain = try NeoLemmixTerrain(width: 64, height: 32)
        terrain.setSolid(true, x: solidX, y: 20)
        let configuration = try NeoLemmixConfiguration(
            totalLemmings: 1,
            requiredToSave: 1,
            spawnInterval: 4,
            entrances: [],
            preplacedLemmings: [.init(position: .init(x: 10, y: 20))],
            skills: [.builder: .finite(2), .walker: .infinite])
        return try NeoLemmixSimulation(terrain: terrain, configuration: configuration)
    }

    @Test("Stable encoding and terrain sensitivity")
    func stableSnapshot() throws {
        let first = NeoLemmixFinalState(try simulation(solidX: 10))
        let repeated = NeoLemmixFinalState(try simulation(solidX: 10))
        let changed = NeoLemmixFinalState(try simulation(solidX: 11))
        #expect(first == repeated)
        #expect(first != changed)
        #expect(first.skills.map(\.name) == ["builder", "walker"])
        #expect(first.lemmings.map(\.id) == [0])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(first)
        #expect(try JSONDecoder().decode(NeoLemmixFinalState.self, from: data) == first)
    }

    @Test("Manifest order follows replay hashes")
    func stableManifest() throws {
        let state = NeoLemmixFinalState(try simulation(solidX: 10))
        let manifest = NeoLemmixFinalStateManifest(records: [
            .init(replaySHA256: "b", levelID: "x2", levelVersion: "x1", state: state),
            .init(replaySHA256: "a", levelID: "x1", levelVersion: "x1", state: state),
        ])
        #expect(manifest.format == NeoLemmixFinalState.format)
        #expect(manifest.producer == "native")
        #expect(manifest.records.map(\.replaySHA256) == ["a", "b"])
        let matchingOracle = NeoLemmixFinalStateManifest(
            records: manifest.records,
            producer: "ce:test")
        #expect(manifest.comparisonIssues(against: matchingOracle).isEmpty)
        #expect(manifest.comparisonIssues(against: manifest)
            == ["oracle manifest is not marked as CE-produced"])

        let changedState = NeoLemmixFinalState(try simulation(solidX: 11))
        let changed = NeoLemmixFinalStateManifest(records: [
            .init(replaySHA256: "a", levelID: "x1", levelVersion: "x1", state: changedState),
            .init(replaySHA256: "c", levelID: "x3", levelVersion: "x1", state: state),
        ], producer: "ce:test")
        #expect(manifest.comparisonIssues(against: changed) == [
            "oracle replay missing b",
            "unexpected oracle replay c",
            "final state differs a",
        ])
    }
}
