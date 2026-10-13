import AppKit
import Foundation
import LemmingsAppCore
import NxlvKit

private struct Failure: Error { let message: String }
private func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw Failure(message: message) }
}

@main struct MacPerformanceTests {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try verifyAdaptiveFXPolicy()
        try verifyMacFXRendering(root: root)
        try verifyReplayCaptureReuse()
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let level = try ClassicDataSet.detect(directory: directory).campaign.levels[0].level
        let assets = try ClassicMainDATAssets.load(from: directory)
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
        GameCursor.gameplaySuppressed = true
        for (name, artworkDirectory) in [("dos", Optional<URL>.none),
            ("mac", root.appendingPathComponent(".build/mac-artwork/export/lemmings")),
            ("amiga", root.appendingPathComponent(".build/amiga-artwork/export/lemmings"))] {
            let native = try artworkDirectory.map { directory in
                try ClassicMacScene(level: level, rendered: scene,
                    artwork: ClassicMacArtwork(directory: directory), groundSet: ground)
            }
            var session = ClassicSession(simulation: initial, width: scene.width, height: scene.height)
            let view = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 640, height: 320))
            view.classicScene = scene; view.macScene = native; view.session = session
            view.hdEffectsEnabled = false; view.phase = .playing
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            func drawAndCompare() throws {
                view.cacheDisplay(in: view.bounds, to: rep)
                let expected = native?.rgba(simulation: session.simulation)
                    ?? ClassicSceneFrame.rgba(scene, simulation: session.simulation)
                let actual = view.levelImage!.dataProvider!.data! as Data
                try check(actual == expected, "\(name): cached scene differs at tick \(session.currentTick)")
            }
            for _ in 0..<60 { session.tick(); try drawAndCompare() }
            try check(view.terrainRenderCount == 1, "\(name): unchanged terrain was rebuilt")
            var target: Int?
            for _ in 0..<120 {
                target = session.lemmings.first { session.canAssign(skillIndex: 7, to: $0.id) }?.id
                if target != nil { break }
                session.tick(); try drawAndCompare()
            }
            guard let target else { throw Failure(message: "No digger target") }
            try check(session.assign(skillIndex: 7, to: target) == nil, "Digger assignment failed")
            let beforeDig = view.terrainRenderCount
            for _ in 0..<24 { session.tick(); try drawAndCompare() }
            try check(view.terrainRenderCount > beforeDig, "\(name): digging retained stale terrain")
            let beforeRewind = view.terrainRenderCount
            try check(session.rewind(seconds: 1), "Rewind failed")
            try drawAndCompare()
            try check(view.terrainRenderCount == beforeRewind + 1, "\(name): rewind retained terrain")
            session.resumeFromRewind()
            session.nuke()
            for _ in 0..<2 { session.tick(); try drawAndCompare() }
            let beforeUndo = view.terrainRenderCount
            session.undoNuke(); try drawAndCompare()
            try check(view.terrainRenderCount == beforeUndo + 1, "\(name): undo retained terrain")
            let sameTick = ClassicSession(simulation: session.simulation, width: scene.width, height: scene.height)
            let beforeReplace = view.terrainRenderCount
            view.session = sameTick
            view.cacheDisplay(in: view.bounds, to: rep)
            try check(view.terrainRenderCount == beforeReplace + 1, "\(name): same-tick session replacement retained terrain")
            view.session = session
            view.macScene = native; view.classicScene = scene
            try drawAndCompare()
            try check(view.terrainRenderCount == beforeReplace + 2, "\(name): artwork replacement retained terrain")

            let saved = session.simulation
            let checkpoint = RunRecovery(engine: "test", profileID: "owner", runID: UUID(), dataSetID: "lemmings", levelIndex: 0,
                levelFingerprint: "level", initialStateHash: session.initialStateHash, tick: session.currentTick,
                events: session.recoveryEvents, stateHash: ClassicDOSReplayRecorder.stateHash(of: saved),
                usedRewind: session.usedRewind, nukeCount: session.nukeCount, rewindCount: session.rewindCount,
                undoCount: session.undoCount, selectedSkill: 7, scrollX: 0, scrollY: 0, classicState: saved)
            session = ClassicSession(simulation: initial, width: scene.width, height: scene.height)
            view.session = session
            try drawAndCompare()
            let beforeRestore = view.terrainRenderCount
            try session.restore(checkpoint)
            try drawAndCompare()
            try check(view.terrainRenderCount == beforeRestore + 1, "\(name): restore retained terrain")
            try check(ClassicDOSReplayRecorder.stateHash(of: session.simulation) == checkpoint.stateHash, "Restore changed physics")

            let c = initial.configuration
            let builderStart = try ClassicDOSSimulation(terrain: initial.terrain,
                configuration: .init(totalLemmings: c.totalLemmings, requiredToSave: c.requiredToSave,
                    timeLimitTicks: c.timeLimitTicks, initialReleaseRate: c.initialReleaseRate,
                    entrances: c.entrances, triggers: c.triggers, initialSkills: [.builder: 5],
                    maximumX: c.maximumX, maximumY: c.maximumY, mechanics: c.mechanics))
            session = ClassicSession(simulation: builderStart, width: scene.width, height: scene.height)
            view.session = session
            var builder: Int?
            for _ in 0..<180 {
                builder = session.lemmings.first { session.canAssign(skillIndex: 4, to: $0.id) }?.id
                if builder != nil { break }
                session.tick(); try drawAndCompare()
            }
            guard let builder else { throw Failure(message: "No builder target") }
            try check(session.assign(skillIndex: 4, to: builder) == nil, "Builder assignment failed")
            let beforeBuild = session.terrainRevision
            for _ in 0..<24 { session.tick(); try drawAndCompare() }
            try check(session.terrainRevision > beforeBuild, "\(name): construction did not invalidate terrain")
            let beforeExplosion = session.simulation.terrain.solidMask
            session.nuke()
            for _ in 0..<100 { session.tick(); try drawAndCompare() }
            try check(session.simulation.terrain.solidMask != beforeExplosion, "Nuke did not destroy test terrain")

            view.viewport.levelSize = CGSize(width: scene.width, height: scene.height)
            view.viewport.viewSize = view.bounds.size
            let captureStarted = ProcessInfo.processInfo.systemUptime
            for _ in 0..<32 {
                _ = ReplayFrameCapture.image(size: CGSize(width: 1280, height: 720)) {
                    ReplayFrameCapture.draw(view, in: CGRect(x: 0, y: 0, width: 1280, height: 640))
                }
            }
            print(String(format: "PROFILE %@ real playfield movie composition: %.3f ms/frame at 1280x720", name,
                (ProcessInfo.processInfo.systemUptime - captureStarted) * 1000 / 32))

            let simulation = session.simulation
            let iterations = 64
            let started = ProcessInfo.processInfo.systemUptime
            for _ in 0..<iterations {
                _ = native?.rgba(simulation: simulation) ?? ClassicSceneFrame.rgba(scene, simulation: simulation)
            }
            let uncachedMS = (ProcessInfo.processInfo.systemUptime - started) * 1000 / Double(iterations)
            let terrain = native?.terrainFrame(terrain: simulation.terrain)
                ?? ClassicSceneFrame.terrainRGBA(scene, terrain: simulation.terrain)
            let cachedStarted = ProcessInfo.processInfo.systemUptime
            for _ in 0..<iterations {
                _ = native?.rgba(simulation: simulation, terrain: terrain)
                    ?? ClassicSceneFrame.rgba(scene, simulation: simulation, terrain: terrain)
            }
            let cachedMS = (ProcessInfo.processInfo.systemUptime - cachedStarted) * 1000 / Double(iterations)
            print(String(format: "PASS %@ scene pixels, digging, construction, nuke, rewind, undo, restore, session/artwork replacement; render %.3f -> %.3f ms", name, uncachedMS, cachedMS))
        }
    }
}
