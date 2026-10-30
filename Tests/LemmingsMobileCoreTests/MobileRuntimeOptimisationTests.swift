import Foundation
import CoreGraphics
import ImageIO
import NxlvKit
import LemmingsAppCore
import Testing
@testable import LemmingsMobileCore

struct MobileRuntimeOptimisationTests {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @MainActor @Test func viewportPixelsMatchFullSceneAcrossGamesAndArtwork() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = MobileStorage(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let classic = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let assetRoot = directory.appendingPathComponent("art")
        try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: assetRoot.appendingPathComponent("MacArtwork"),
            withDestinationURL: root.appendingPathComponent(".build/mac-artwork/export"))
        let level = classic.dataSet.campaign.levels[0].level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: classic.directory)
        let assets = try ClassicMainDATAssets.load(from: classic.directory)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground)
        let native = ClassicMobileSession(simulation: try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets),
            renderedLevel: rendered, assets: assets, palette: try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette),
            levelIdentifier: "viewport", levelIndex: 0, startX: level.startX, authoredLevel: level, ground: ground,
            artworkFamily: "lemmings", artworkRoot: assetRoot)
        let l2 = try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let l3 = try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        for game in [native, try l2.loadLevel(at: 0).session, try l3.loadLevel(at: 0).session] {
            for graphics in [ClassicGraphicsSource.dosVGA, .macintosh] {
                var settings = ClassicSettings(); settings.graphics = graphics
                game.applySettings(settings)
                if graphics == .macintosh { #expect(game.renderScale == 2) }
                for _ in 0..<100 { game.tick() }
                let full = try game.render(highlight: nil)
                for x in [game.initialCameraOrigin.x, game.levelSize.width / 2, max(0, game.levelSize.width - 100)] {
                    let cropped = try game.render(highlight: nil, viewport: .init(x: x, y: 20, width: 80, height: 60))
                    if let rect = cropped.renderedRect {
                        let scale = Int(game.renderScale)
                        let request = SceneRasterContext.Viewport(levelWidth: Int(game.levelSize.width), levelHeight: Int(game.levelSize.height),
                            x: Int(rect.x), y: Int(rect.y), width: Int(rect.width), height: Int(rect.height))
                        let expected = SceneRasterContext.request.withValue(request) {
                            SceneRasterContext.crop(full.rgba, width: full.width, height: full.height)
                        }
                        #expect(cropped.rgba == expected, "\(game.engineIdentifier) \(graphics) at \(x)")
                        #expect(cropped.width == Int(rect.width) * scale)
                        #expect(cropped.height == Int(rect.height) * scale)
                        if x == game.initialCameraOrigin.x {
                            let camera = MobileViewport(levelSize: game.levelSize, viewSize: .init(width: 390, height: 240),
                                origin: .init(x: game.entrancePoint.x - 40.25, y: game.entrancePoint.y - 20.5), zoom: 3, pixelAspect: 1.2)
                            let surface = MobileBitmapSurface(), copySurface = MobileBitmapSurface(), viewportSurface = MobileBitmapSurface()
                            let direct = try #require(surface.prepare(width: 390, height: 240))
                            let copied = try #require(copySurface.prepare(width: 390, height: 240))
                            let clipped = try #require(viewportSurface.prepare(width: 390, height: 240))
                            direct.saveGState()
                            direct.translateBy(x: 0, y: 240); direct.scaleBy(x: 1, y: -1)
                            MobileBitmapRenderer.draw(try #require(MobileBitmapRenderer.image(full)), viewport: camera, in: direct)
                            direct.restoreGState()
                            let scene = try #require(direct.makeImage())
                            copied.draw(scene, in: CGRect(x: 0, y: 0, width: 390, height: 240))
                            #expect(Data(bytes: direct.data!, count: 390 * 240 * 4) == Data(bytes: copied.data!, count: 390 * 240 * 4))
                            let cameraFrame = try game.render(highlight: nil, viewport: camera.visibleLevelRect)
                            clipped.saveGState()
                            clipped.translateBy(x: 0, y: 240); clipped.scaleBy(x: 1, y: -1)
                            MobileBitmapRenderer.draw(try #require(MobileBitmapRenderer.image(cameraFrame)), viewport: camera,
                                in: clipped, renderedRect: cameraFrame.renderedRect)
                            clipped.restoreGState()
                            #expect(Data(bytes: direct.data!, count: 390 * 240 * 4) == Data(bytes: clipped.data!, count: 390 * 240 * 4),
                                "Viewport placement at fractional camera origin: \(game.engineIdentifier) \(graphics)")
                            let path = root.appendingPathComponent(".build/runtime-renders")
                            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
                            let url = path.appendingPathComponent("\(game.engineIdentifier)-\(graphics == .macintosh ? "mac" : "dos").png")
                            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                            CGImageDestinationAddImage(destination, scene, nil)
                            #expect(CGImageDestinationFinalize(destination))
                        }

                    } else { #expect(cropped == full) }
                }
                #expect(try game.render(highlight: nil).rgba == full.rgba)
            }
        }
    }

    @Test func boundedSeekCommitsExactStatesAndCancellationLeavesTheRunIntact() throws {
        var terrain = try NeoLemmixTerrain(width: 4096, height: 64)
        for x in 0..<4096 { terrain.setSolid(true, x: x, y: 48) }
        let initial = try NeoLemmixSimulation(terrain: terrain, configuration: .init(
            totalLemmings: 1, requiredToSave: 1, spawnInterval: 30, entrances: [],
            preplacedLemmings: [.init(position: .init(x: 30, y: 48))], skills: [.builder: .infinite]))
        let game = NeoLemmixMobileSession(simulation: initial, controls: [.builder], engineFingerprint: "sliced",
            levelIdentifier: "sliced", levelIndex: 0, levelFingerprint: "sliced")
        for _ in 0..<1800 { game.tick() }
        let original = try game.actionCapture()?.final.hash()
        let cancelled = try #require(game.prepareSeek(to: 101))
        _ = try cancelled.advance(seconds: 0)
        cancelled.cancel()
        #expect(try game.actionCapture()?.final.hash() == original)
        #expect(throws: CancellationError.self) { try cancelled.advance() }
        let seek = try #require(game.prepareSeek(to: 700))
        var slices = 0
        while try !seek.advance(seconds: 0) {
            slices += 1
            #expect(game.snapshot.tick == 1800)
            #expect(slices < 1800)
        }
        var reference = initial
        for _ in 0..<700 { reference.tick() }
        #expect(try game.actionCapture()?.final.hash() == ActionReplayState.neolemmix(reference).hash())
        #expect(game.usedRewind)
    }

    @MainActor @Test func sequelSlicedSeekKeepsExactCommandsAndAssistanceCounts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MobileStorage(directory: directory)
        let l2 = try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let l3 = try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        for game in [try l2.loadLevel(at: 0).session, try l3.loadLevel(at: 0).session] {
            for _ in 0..<150 { game.tick() }
            let target = game.snapshot.tick
            let expected = try game.actionCapture()?.final.hash()
            for _ in 0..<40 { game.tick() }
            let before = game.snapshot
            let previousRewinds = game.rewindCount
            let operation = try #require(game.prepareSeek(to: target))
            while try !operation.advance(seconds: 0) { #expect(game.snapshot == before) }
            #expect(try game.actionCapture()?.final.hash() == expected)
            #expect(game.rewindCount == previousRewinds + 1)
        }
    }

    @Test func colourLookupPreservesEveryOriginalQuantisationResult() {
        for value in 0...255 { #expect(MobileColourDepth.ocs[value] == UInt8((value * 15 + 127) / 255 * 17)) }
    }

    @Test func scopedRasterRequestsDoNotLeakIntoOtherTasks() async {
        let viewport = SceneRasterContext.Viewport(levelWidth: 160, levelHeight: 80, x: 32, y: 16, width: 64, height: 32)
        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<16 {
                group.addTask {
                    let request = SceneRasterContext.Viewport(levelWidth: 160, levelHeight: 80, x: index, y: 16, width: 64, height: 32)
                    return SceneRasterContext.request.withValue(request) {
                        SceneRasterContext.region(width: 160, height: 80).x == index
                    }
                }
            }
            for await valid in group { #expect(valid) }
        }
        #expect(SceneRasterContext.viewport == nil)
        let region = SceneRasterContext.request.withValue(viewport) { SceneRasterContext.region(width: 320, height: 160) }
        #expect(region.x == 64 && region.width == 128 && region.y == 32 && region.height == 64)
    }

    @Test func cacheLeasesBoundCombinedPixelStorage() {
        let budget = RuntimeMemoryBudget.shared.snapshot()
        let first = RuntimePixelCacheLease(), second = RuntimePixelCacheLease()
        #expect(!first.reserve(bytes: budget.cacheBytes + 1))
        #expect(first.reserve(bytes: 1024))
        #expect(second.reserve(bytes: 2048))
        #expect(RuntimeMemoryBudget.shared.retainedCacheBytes <= budget.cacheBytes)
        first.release(); second.release()
        #expect(RuntimeMemoryBudget.shared.retainedCacheBytes <= budget.cacheBytes)
    }
}
