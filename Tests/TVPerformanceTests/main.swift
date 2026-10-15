import Foundation
import NxlvKit
import LemmingsMobileCore
import CryptoKit

@main struct TVPerformanceTests {
    @MainActor static func main() throws {
        let width = 320, height = 80, total = 80
        var solid = [Bool](repeating: false, count: width * height)
        var pixels = [UInt8](repeating: 0, count: solid.count)
        var attributes = [UInt16](repeating: 0x1000, count: solid.count)
        for y in 60..<height { for x in 0..<width {
            solid[y * width + x] = true; pixels[y * width + x] = 6
            attributes[y * width + x] = 0x20
        } }
        for y in 0..<height { for x in [0, width - 1] {
            solid[y * width + x] = true; pixels[y * width + x] = 6; attributes[y * width + x] = 0x20
        } }
        let terrain = try ClassicDOSTerrain(width: width, height: height,
            solidMask: Data(solid.map { $0 ? 1 : 0 }), steelMask: Data(repeating: 0, count: solid.count))
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let data = try ClassicDataSet.detect(directory: directory)
        let ground = try ClassicGroundSet.load(style: data.campaign.levels[0].level.groundStyle, from: directory)
        let assets = try ClassicMainDATAssets.load(from: directory)
        let rendered = try JSONDecoder().decode(ClassicRenderedLevel.self, from: JSONSerialization.data(withJSONObject: [
            "width": width, "height": height, "rgba": Data(repeating: 0, count: width * height * 4).base64EncodedString(),
            "solidMask": terrain.solidMask.base64EncodedString(), "steelMask": terrain.steelMask.base64EncodedString(),
            "entrances": [], "triggers": [], "objects": []]))
        let classic = ClassicMobileSession(simulation: try ClassicDOSSimulation(terrain: terrain,
            configuration: .init(totalLemmings: total, requiredToSave: 1, timeLimitTicks: 100_000,
                initialReleaseRate: 99, entrances: [.init(x: 20, y: 45)],
                initialSkills: [.climber: 99],
                maximumX: width - 1, maximumY: height - 1)), renderedLevel: rendered, assets: assets,
            palette: try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette),
            levelIdentifier: "crowd", levelIndex: 0)
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8),
            miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame,
            stacker: Array(repeating: frame, count: 2), platformer: frame, laser: [frame], blast: frame)
        let l2 = Lemmings2MobileSession(runtime: try Lemmings2Runtime(configuration: .init(
            width: width, height: height, pixels: pixels, solid: solid, palette: [UInt8](repeating: 255, count: 1024),
            entrance: .init(x: 20, y: 45, width: 1, height: 1), exits: [],
            skills: [.jumper, .laserBlaster, .bazooka], supplies: [99, 99, 99], total: total,
            timeLimit: 3_600, releaseInterval: 1, terrainMasks: masks, firstReleaseTick: 1, isPractice: true)),
            engineFingerprint: "crowd", levelIdentifier: "crowd", levelIndex: 0, levelFingerprint: "crowd")
        let l3 = Lemmings3MobileSession(runtime: try Lemmings3Runtime(configuration: .init(
            width: width, height: height, attributes: attributes, entrance: .init(x: 20, y: 45), exits: [.init(x: width - 20, y: 4)],
            total: 10, releaseInterval: 1, releaseDelay: 0,
            extras: (0..<70).map { .init(x: 20 + $0 * 3, y: 59, direction: 1) })),
            engineFingerprint: "crowd", levelIdentifier: "crowd", levelIndex: 0, levelFingerprint: "crowd")
        for session in [classic, l2, l3] as [any MobileGameSession] {
            for _ in 0..<500 where session.snapshot.released < total { session.tick() }
            for _ in 0..<20 { session.tick() }
            print("CROWD \(session.engineIdentifier): \(session.activeLemmingCount) active, \(session.snapshot.released) released")
            precondition(session.activeLemmingCount == total)
            let before = try JSONSerialization.jsonObject(with: session.checkpointPayload()) as! NSDictionary
            let expected = session.snapshot.skills.indices.map { session.targetCandidates(for: $0) }
            let started = ProcessInfo.processInfo.systemUptime
            var count = 0
            let iterations = 40
            for _ in 0..<iterations {
                for control in session.snapshot.skills.indices {
                    let candidates = session.targetCandidates(for: control)
                    precondition(candidates == expected[control])
                    count += candidates.count
                }
            }
            let ms = (ProcessInfo.processInfo.systemUptime - started) * 1_000 / Double(iterations)
            let after = try JSONSerialization.jsonObject(with: session.checkpointPayload()) as! NSDictionary
            precondition(after == before)
            print(String(format: "%@ 80 actors: %.3f ms per all-skill targeting pass (%d candidates)",
                session.engineIdentifier, ms, count))
        }
        for (index, actor) in classic.targetCandidates(for: 0).enumerated() where index % 3 == 0 {
            precondition(classic.assign(control: 0, to: actor.id))
        }
        for backpacks in [false, true, false] {
            var settings = ClassicSettings()
            settings.graphics = .dosVGA; settings.colorDepth = .full; settings.showClassicSkillBackpacks = backpacks
            classic.applySettings(settings)
            let expected = try classic.render(highlight: nil)
            let started = ProcessInfo.processInfo.systemUptime
            for _ in 0..<40 { precondition(tryRender(classic) == expected) }
            let ms = (ProcessInfo.processInfo.systemUptime - started) * 25
            let digest = SHA256.hash(data: expected.rgba).map { String(format: "%02x", $0) }.joined()
            let originalDigest = backpacks
                ? "384f1a2fb7c2ceb0ba474f31148e85c7d04a735843125f4844003405179b3d73"
                : "7c6b6fc7749859e790b570ddad10012172214fb06df3bb9edef1035ec3609347"
            precondition(digest == originalDigest, "Crowd pixels changed from the uncached renderer")
            print(String(format: "Classic 80 actors same-tick redraw, backpacks=%@: %.3f ms, SHA256 %@", String(backpacks), ms, digest))
        }
        var settings = ClassicSettings()
        settings.graphics = .dosVGA; settings.colorDepth = .full; settings.showClassicSkillBackpacks = true
        classic.applySettings(settings)
        let checkpoint = try classic.checkpointPayload()
        let beforeAssignment = try classic.render(highlight: nil)
        let actor = classic.targetCandidates(for: 0).first { $0.assignment == .eligible }!
        let selection = MobileTargetSelection(id: actor.id, point: actor.point, state: .eligible)
        let selectedFrame = try classic.render(highlight: selection)
        precondition(selectedFrame != beforeAssignment, "A changed selection must refresh the reticle")
        precondition(tryRender(classic) == beforeAssignment, "Clearing selection must remove the cached reticle")
        precondition(classic.assign(control: 0, to: actor.id))
        precondition(tryRender(classic) != beforeAssignment, "Same-tick assignment must invalidate the frame")
        try classic.restoreCheckpointPayload(checkpoint)
        precondition(tryRender(classic) == beforeAssignment, "Same-tick restore must invalidate the frame")
        classic.releaseTransientResources()
        precondition(tryRender(classic) == beforeAssignment, "Purging caches must preserve pixels")
        let started = ProcessInfo.processInfo.systemUptime
        var frames = Set<Data>()
        for _ in 0..<40 { classic.tick(); frames.insert(tryRender(classic).rgba) }
        precondition(frames.count > 1, "Physics ticks must refresh cached sprites")
        print(String(format: "Classic 80 actors tick and render: %.3f ms", (ProcessInfo.processInfo.systemUptime - started) * 25))
    }
    static func tryRender(_ game: ClassicMobileSession) -> MobilePixelFrame { try! game.render(highlight: nil) }
}
