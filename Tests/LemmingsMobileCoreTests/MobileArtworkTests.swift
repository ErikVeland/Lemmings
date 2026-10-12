import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileArtworkTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func nativeArtworkKeepsAuthoredPixelsAndSimulation() throws {
        let directory = Self.root.appendingPathComponent(".build/ios-ports/lemmings_dos_1991-07-30")
        let set = try ClassicDataSet.detect(directory: directory)
        let level = try #require(set.campaign.levels.first).level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let assets = try ClassicMainDATAssets.load(from: directory)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
        let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundle) }
        try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent("MacArtwork"), withDestinationURL: Self.root.appendingPathComponent(".build/mac-artwork/export"))
        try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent("AmigaArtwork"), withDestinationURL: Self.root.appendingPathComponent(".build/amiga-artwork/export"))
        let game = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets, palette: palette,
            levelIdentifier: "fixture", levelIndex: 0, authoredLevel: level, ground: ground, artworkFamily: "lemmings", artworkRoot: bundle)
        for (source, kind) in [(ClassicGraphicsSource.macintosh, "MacArtwork"), (.amiga, "AmigaArtwork")] {
            var settings = ClassicSettings(); settings.graphics = source; settings.colorDepth = .full
            game.applySettings(settings)
            let art = try ClassicMacArtwork(directory: bundle.appendingPathComponent(kind + "/lemmings"))
            let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: art, groundSet: ground,
                reconstructUnmatched: source == .macintosh)
            let frame = try game.render(highlight: nil)
            #expect(frame.width == rendered.width * 2)
            #expect(frame.height == rendered.height * 2)
            #expect(frame.rgba == scene.rgba(simulation: simulation))
            #expect(game.renderScale == 2)
            #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == ClassicDOSReplayRecorder.stateHash(of: simulation))
            for _ in 0..<60 { game.tick() }
            let target = try #require(game.targetCandidates(for: 0).first)
            _ = try game.render(highlight: .init(id: target.id, point: target.point, state: target.assignment))
            #expect(game.skillCursorFrame(control: 0) != nil)
            #expect(game.rewind(seconds: 60 / game.ticksPerSecond))
        }
        var settings = ClassicSettings(); settings.graphics = .dosVGA; settings.colorDepth = .amigaOCS
        game.applySettings(settings)
        let frame = try game.render(highlight: nil)
        #expect(frame.width == rendered.width)
        #expect(game.renderScale == 1)
        #expect(stride(from: 0, to: frame.rgba.count, by: 4).allSatisfy {
            frame.rgba[$0] % 17 == 0 && frame.rgba[$0 + 1] % 17 == 0 && frame.rgba[$0 + 2] % 17 == 0
        })
    }

    @Test func countdownHoldsWhenHiddenAndCancelsForPlanning() {
        var countdown = GameplayStartCountdown()
        countdown.arm()
        #expect(countdown.number == 3)
        _ = countdown.advance(seconds: 5, visible: false)
        #expect(countdown.number == 3)
        _ = countdown.advance(seconds: 1, visible: true)
        #expect(countdown.number == 2)
        countdown.cancel()
        #expect(!countdown.isActive)
        #expect(countdown.number == nil)
    }
}
