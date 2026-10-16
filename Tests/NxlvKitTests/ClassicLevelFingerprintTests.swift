import Foundation
import Testing
@testable import NxlvKit

struct ClassicLevelFingerprintTests {
    @Test func fingerprintDistinguishesLevelsThatShareTheLegacyStateHash() throws {
        let solid = Data(repeating: 0, count: 192 * 96)
        let steel = Data(repeating: 0, count: solid.count)
        let firstTerrain = try ClassicDOSTerrain(
            width: 192, height: 96, solidMask: solid, steelMask: steel)
        let secondTerrain = try ClassicDOSTerrain(
            width: 96, height: 192, solidMask: solid, steelMask: steel)
        func configuration(
            entranceX: Int = 40,
            triggers: [ClassicDOSTrigger] = []
        ) -> ClassicDOSConfiguration {
            ClassicDOSConfiguration(
                totalLemmings: 1, requiredToSave: 1, timeLimitTicks: 300,
                initialReleaseRate: 50, entrances: [.init(x: entranceX, y: 0)],
                triggers: triggers, maximumX: 191, maximumY: 95)
        }
        func emptyMask(width: Int, height: Int, filled: Bool = false) throws -> ClassicDOSMask {
            try ClassicDOSMask(width: width, height: height,
                pixels: Data(repeating: filled ? 1 : 0, count: width * height))
        }
        func maskSet(filled: Bool) throws -> ClassicDOSDestructionMaskSet {
            try ClassicDOSDestructionMaskSet(
                explosion: emptyMask(width: 16, height: 22, filled: filled),
                bashRight: (0..<4).map { _ in try emptyMask(width: 16, height: 10) },
                bashLeft: (0..<4).map { _ in try emptyMask(width: 16, height: 10) },
                mineRight: (0..<2).map { _ in try emptyMask(width: 16, height: 13) },
                mineLeft: (0..<2).map { _ in try emptyMask(width: 16, height: 13) })
        }
        let first = try ClassicDOSSimulation(terrain: firstTerrain, configuration: configuration())
        let triggerVariant = try ClassicDOSSimulation(terrain: firstTerrain,
            configuration: configuration(triggers: [.init(id: 0, effect: .triggeredTrap,
                bounds: .init(x1: 60, y1: 20, x2: 80, y2: 40))]))
        let entranceVariant = try ClassicDOSSimulation(terrain: firstTerrain,
            configuration: configuration(entranceX: 41))
        let dimensionVariant = try ClassicDOSSimulation(terrain: secondTerrain,
            configuration: configuration())
        let masksVariant = try ClassicDOSSimulation(terrain: firstTerrain,
            configuration: configuration(), destructionMasks: maskSet(filled: true))
        let masksBase = try ClassicDOSSimulation(terrain: firstTerrain,
            configuration: configuration(), destructionMasks: maskSet(filled: false))
        let variants = [triggerVariant, entranceVariant, dimensionVariant, masksVariant]

        #expect(ClassicDOSReplayRecorder.stateHash(of: first)
            == ClassicDOSReplayRecorder.stateHash(of: triggerVariant))
        #expect(ClassicDOSReplayRecorder.stateHash(of: first)
            == ClassicDOSReplayRecorder.stateHash(of: entranceVariant))
        #expect(ClassicDOSReplayRecorder.stateHash(of: first)
            == ClassicDOSReplayRecorder.stateHash(of: dimensionVariant))
        #expect(ClassicDOSReplayRecorder.stateHash(of: masksBase)
            == ClassicDOSReplayRecorder.stateHash(of: masksVariant))
        #expect(variants.allSatisfy { first.levelSourceFingerprint != $0.levelSourceFingerprint })
        #expect(masksBase.levelSourceFingerprint != masksVariant.levelSourceFingerprint)

        let replay = ClassicDOSReplay(
            rank: "Test", number: 1, title: "Fingerprint",
            initialStateHash: ClassicDOSReplayRecorder.stateHash(of: first),
            initialLevelFingerprint: first.levelSourceFingerprint,
            events: [])
        #expect(throws: ClassicDOSReplayError.self) {
            try ClassicDOSReplayPlayer.run(replay, simulation: triggerVariant)
        }
    }

    @Test func legacyReplayDecodesWithoutLevelFingerprint() throws {
        let data = Data("""
        {"rank":"Test","number":1,"title":"Legacy","initialStateHash":"legacy","events":[]}
        """.utf8)

        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: data)
        #expect(replay.initialLevelFingerprint == nil)
    }
}
