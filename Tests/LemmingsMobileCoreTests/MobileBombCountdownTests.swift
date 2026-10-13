import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

struct MobileBombCountdownTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func bombsAndNukesRenderEveryDigitWithAllClassicArtwork() throws {
        let directory = Self.root.appendingPathComponent(".build/ios-ports/lemmings_dos_1991-07-30")
        let level = try #require(ClassicDataSet.detect(directory: directory).campaign.levels.first).level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let assets = try ClassicMainDATAssets.load(from: directory)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
        let original = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        let config = original.configuration
        let simulation = try ClassicDOSSimulation(terrain: original.terrain,
            configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: nil,
                initialReleaseRate: 99, entrances: config.entrances, triggers: config.triggers,
                initialSkills: [.blocker: 1, .bomber: 1], maximumX: config.maximumX, maximumY: config.maximumY),
            destructionMasks: original.comparisonDestructionMasks)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundle) }
        for kind in ["MacArtwork", "AmigaArtwork"] {
            let export = kind == "MacArtwork" ? ".build/mac-artwork/export" : ".build/amiga-artwork/export"
            try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent(kind),
                withDestinationURL: Self.root.appendingPathComponent(export))
        }

        for graphics in [ClassicGraphicsSource.dosVGA, .macintosh, .amiga] {
            for nuke in [false, true] {
                let game = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets,
                    palette: palette, levelIdentifier: "countdown", levelIndex: 0, authoredLevel: level,
                    ground: ground, artworkFamily: "lemmings", artworkRoot: bundle)
                var settings = ClassicSettings()
                settings.graphics = graphics
                settings.colorDepth = .full
                game.applySettings(settings)
                #expect(game.renderScale == (graphics == .dosVGA ? 1 : 2))
                let blocker = try #require(ClassicSkill.allCases.firstIndex(of: .blocker))
                let bomber = try #require(ClassicSkill.allCases.firstIndex(of: .bomber))
                for _ in 0..<200 where !game.targetCandidates(for: blocker).contains(where: { $0.assignment == .eligible }) {
                    game.tick()
                }
                let target = try #require(game.targetCandidates(for: blocker).first(where: { $0.assignment == .eligible }))
                #expect(game.assign(control: blocker, to: target.id))
                let baseline = try game.render(highlight: nil)
                if nuke {
                    #expect(game.beginEndRun())
                    game.tick()
                } else {
                    #expect(game.assign(control: bomber, to: target.id))
                }
                let checkpoint = try game.checkpointPayload()
                let initialFrame = try game.render(highlight: nil)
                var digits: Set<Int> = []
                var lastFrame = initialFrame
                while let lemming = game.finalSimulation.lemmings.first,
                      let ticks = lemming.bomberCountdown {
                    let digit = (ticks + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond
                    let frame = try game.render(highlight: nil)
                    lastFrame = frame
                    let sprite = try #require(game.spriteHighlight(for: lemming.id))
                    let glyph = try #require(assets.countdownGlyphs.first(where: { $0.digit == digit })).bitmap
                    let scale = Int(game.renderScale)
                    let x = (lemming.foot.x - glyph.width / 2) * scale
                    let y = Int(sprite.rect.y * Double(scale)) - (glyph.height + 1) * scale
                    var changed = 0
                    for gy in 0..<(glyph.height * scale) {
                        for gx in 0..<(glyph.width * scale) {
                            let offset = ((y + gy) * frame.width + x + gx) * 4
                            let actual = frame.rgba[offset..<(offset + 4)]
                            if glyph.isSet(x: gx / scale, y: gy / scale) {
                                #expect(Array(actual) == [255, 255, 255, 255])
                                if actual != baseline.rgba[offset..<(offset + 4)] { changed += 1 }
                            } else {
                                #expect(actual == baseline.rgba[offset..<(offset + 4)])
                            }
                        }
                    }
                    #expect(changed > 0)
                    if digits.insert(digit).inserted {
                        try capture(frame, game: game, target: lemming,
                            name: "\(graphics)-\(nuke ? "nuke" : "bomb")-\(digit)")
                    }
                    game.tick()
                }
                #expect(digits == [1, 2, 3, 4, 5])
                let finished = try game.render(highlight: nil)
                let lemming = try #require(game.finalSimulation.lemmings.first)
                #expect(lemming.bomberCountdown == nil)
                // The upper digit area returns to the original scenery at Oh No.
                let sprite = try #require(game.spriteHighlight(for: lemming.id))
                let scale = Int(game.renderScale)
                let top = Int(sprite.rect.y * Double(scale)) - 9 * scale
                for y in top..<(top + 6 * scale) {
                    for x in (lemming.foot.x - 4) * scale..<(lemming.foot.x + 4) * scale {
                        let offset = (y * finished.width + x) * 4
                        #expect(finished.rgba[offset..<(offset + 4)] == baseline.rgba[offset..<(offset + 4)])
                    }
                }
                #expect(game.rewind(seconds: 1 / game.ticksPerSecond))
                #expect(game.finalSimulation.lemmings.first?.bomberCountdown == 1)
                #expect(try game.render(highlight: nil) == lastFrame)
                try game.restoreCheckpointPayload(checkpoint)
                #expect(try game.render(highlight: nil) == initialFrame)
                if nuke {
                    #expect(game.undoEndRun())
                    #expect(try game.render(highlight: nil) == baseline)
                }
            }
        }
    }

    private func capture(_ frame: MobilePixelFrame, game: ClassicMobileSession,
        target: ClassicDOSLemming, name: String) throws {
        #if canImport(CoreGraphics)
        guard let path = ProcessInfo.processInfo.environment["LEMMINGS_COUNTDOWN_CAPTURE_DIR"] else { return }
        let output = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let context = try #require(CGContext(data: nil, width: 390, height: 240, bitsPerComponent: 8,
            bytesPerRow: 390 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: 240)
        context.scaleBy(x: 1, y: -1)
        let viewport = MobileViewport(levelSize: game.levelSize, viewSize: .init(width: 390, height: 240),
            origin: .init(x: Double(target.foot.x) - 45, y: Double(target.foot.y) - 42),
            zoom: 4, pixelAspect: game.renderScale == 1 ? 1.2 : 1)
        MobileBitmapRenderer.draw(try #require(MobileBitmapRenderer.image(frame)), viewport: viewport, in: context)
        let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL,
            "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        #endif
    }
}
