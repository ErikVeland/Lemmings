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
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        let config = initial.configuration
        let simulation = try ClassicDOSSimulation(terrain: initial.terrain,
            configuration: .init(totalLemmings: config.totalLemmings, requiredToSave: config.requiredToSave,
                timeLimitTicks: config.timeLimitTicks, initialReleaseRate: config.initialReleaseRate,
                entrances: config.entrances, triggers: config.triggers,
                initialSkills: Dictionary(uniqueKeysWithValues: ClassicSkill.allCases.map { ($0, 20) }),
                maximumX: config.maximumX, maximumY: config.maximumY, mechanics: config.mechanics),
            destructionMasks: initial.comparisonDestructionMasks)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundle) }
        let macRoot = Self.root.appendingPathComponent(".build/mac-artwork/export/lemmings")
            .resolvingSymlinksInPath().deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent("MacArtwork"), withDestinationURL: macRoot)
        try FileManager.default.createSymbolicLink(at: bundle.appendingPathComponent("AmigaArtwork"), withDestinationURL: Self.root.appendingPathComponent(".build/amiga-artwork/export"))
        let game = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets, palette: palette,
            levelIdentifier: "fixture", levelIndex: 0, authoredLevel: level, ground: ground, artworkFamily: "lemmings", artworkRoot: bundle)
        for _ in 0..<120 { game.tick() }
        let runningState = try game.checkpointPayload()
        var switchedFrames = Set<Data>()
        for source in [ClassicGraphicsSource.amiga, .macintosh, .macintoshMonochrome, .dosVGA, .amiga] {
            var settings = ClassicSettings(); settings.graphics = source; settings.colorDepth = .full
            game.applySettings(settings)
            let frame = try game.render(highlight: nil)
            #expect(frame.width == rendered.width * (source == .dosVGA ? 1 : 2))
            #expect(try game.checkpointPayload() == runningState)
            switchedFrames.insert(frame.rgba)
        }
        #expect(switchedFrames.count == 4)
        #expect(game.rewind(seconds: Double(game.snapshot.tick) / game.ticksPerSecond))
        for (source, kind) in [(ClassicGraphicsSource.macintosh, "MacArtwork"), (.amiga, "AmigaArtwork"), (.macintoshMonochrome, "MacArtwork/monochrome")] {
            var settings = ClassicSettings(); settings.graphics = source; settings.colorDepth = .full
            game.applySettings(settings)
            let art = try ClassicMacArtwork(directory: bundle.appendingPathComponent(kind + "/lemmings"))
            let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: art, groundSet: ground,
                reconstructUnmatched: source != .amiga)
            let frame = try game.render(highlight: nil)
            #expect(frame.width == rendered.width * 2)
            #expect(frame.height == rendered.height * 2)
            #expect(frame.rgba == scene.rgba(simulation: simulation))
            #expect(game.renderScale == 2)
            if source == .macintoshMonochrome {
                #expect(art.monochrome)
                let pixels = [UInt8](frame.rgba)
                let binary = stride(from: 0, to: pixels.count, by: 4).allSatisfy { p -> Bool in
                    if pixels[p + 3] == 0 { return true }
                    let value: UInt8 = pixels[p]
                    guard value == 0 || value == 255 else { return false }
                    return value == pixels[p + 1] && value == pixels[p + 2]
                }
                #expect(binary)
            }
            #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == ClassicDOSReplayRecorder.stateHash(of: simulation))
            for _ in 0..<60 { game.tick() }
            if source == .macintoshMonochrome {
                let checkpoint = try game.checkpointPayload()
                let target = try #require(game.targetCandidates(for: 0).first)
                let original = try game.render(highlight: nil)
                var patterns = Set<Data>()
                for (climber, floater) in [(true, false), (false, true), (true, true)] {
                    try game.restoreCheckpointPayload(checkpoint)
                    if climber { #expect(game.assign(control: 0, to: target.id)) }
                    if floater { #expect(game.assign(control: 1, to: target.id)) }
                    let marked = try game.render(highlight: nil)
                    #expect(marked != original)
                    patterns.insert(marked.rgba)
                    let state = ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation)
                    settings.showClassicSkillBackpacks = false
                    game.applySettings(settings)
                    #expect(try game.render(highlight: nil) == original)
                    #expect(ClassicDOSReplayRecorder.stateHash(of: game.finalSimulation) == state)
                    #expect(game.targetCandidates(for: 0).contains { $0.id == target.id && $0.point == target.point })
                    settings.showClassicSkillBackpacks = true
                    game.applySettings(settings)
                    #expect(try game.render(highlight: nil) == marked)
                }
                #expect(patterns.count == 3)
                try game.restoreCheckpointPayload(checkpoint)
                #expect(try game.render(highlight: nil) == original)
            }
            let target = try #require(game.targetCandidates(for: 0).first)
            _ = try game.render(highlight: .init(id: target.id, point: target.point, state: target.assignment))
            #expect(game.skillCursorFrame(control: 0) != nil)
            for _ in 0..<60 where !game.targetCandidates(for: 7).contains(where: { $0.assignment == .eligible }) { game.tick() }
            let digger = try #require(game.targetCandidates(for: 7).first(where: { $0.assignment == .eligible }))
            #expect(game.assign(control: 7, to: digger.id))
            let checkpoint = try game.checkpointPayload()
            for _ in 0..<24 {
                game.tick()
                try checkTerrainCache(game)
            }
            #expect(game.rewind(seconds: 1))
            try checkTerrainCache(game)
            try game.restoreCheckpointPayload(checkpoint)
            try checkTerrainCache(game)
            #expect(game.rewind(seconds: Double(game.snapshot.tick) / game.ticksPerSecond))
        }
        var settings = ClassicSettings(); settings.graphics = .dosVGA; settings.colorDepth = .amigaOCS
        game.applySettings(settings)
        let frame = try game.render(highlight: nil)
        #expect(frame.width == rendered.width)
        #expect(game.renderScale == 1)
        #expect(stride(from: 0, to: frame.rgba.count, by: 4).allSatisfy {
            frame.rgba[$0] % 17 == 0 && frame.rgba[$0 + 1] % 17 == 0 && frame.rgba[$0 + 2] % 17 == 0
        })
        for _ in 0..<120 where !game.targetCandidates(for: 7).contains(where: { $0.assignment == .eligible }) { game.tick() }
        let digger = try #require(game.targetCandidates(for: 7).first(where: { $0.assignment == .eligible }))
        #expect(game.assign(control: 7, to: digger.id))
        for _ in 0..<24 { game.tick(); try checkTerrainCache(game) }
    }

    private func checkTerrainCache(_ game: ClassicMobileSession) throws {
        let cached = try game.render(highlight: nil)
        game.releaseTransientResources()
        #expect(try game.render(highlight: nil) == cached)
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
