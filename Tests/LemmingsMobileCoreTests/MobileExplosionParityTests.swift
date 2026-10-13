import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

struct MobileExplosionParityTests {
    @Test func bombAndNukeCutPopAndRemoveSelectionWithEveryArtwork() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent(".build/ios-ports/lemmings_dos_1991-07-30")
        let level = try #require(ClassicDataSet.detect(directory: directory).campaign.levels.first).level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
        let assets = try ClassicMainDATAssets.load(from: directory)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground)
        let original = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        let config = original.configuration
        let simulation = try ClassicDOSSimulation(terrain: original.terrain,
            configuration: .init(totalLemmings: 1, requiredToSave: 1, timeLimitTicks: nil,
                initialReleaseRate: 99, entrances: config.entrances, triggers: config.triggers,
                initialSkills: [.blocker: 1, .bomber: 1], maximumX: config.maximumX, maximumY: config.maximumY),
            destructionMasks: original.comparisonDestructionMasks)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        let artwork = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: artwork, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: artwork) }
        for (name, export) in [("MacArtwork", "mac-artwork"), ("AmigaArtwork", "amiga-artwork")] {
            try FileManager.default.createSymbolicLink(at: artwork.appendingPathComponent(name),
                withDestinationURL: root.appendingPathComponent(".build/\(export)/export"))
        }
        for graphics in [ClassicGraphicsSource.dosVGA, .macintosh, .amiga] {
            for enhanced in [false, true] {
                for nuke in [false, true] {
                    let game = ClassicMobileSession(simulation: simulation, renderedLevel: rendered,
                        assets: assets, palette: palette, levelIdentifier: "explosion", levelIndex: 0,
                        authoredLevel: level, ground: ground, artworkFamily: "lemmings", artworkRoot: artwork)
                    var settings = ClassicSettings()
                    settings.graphics = graphics; settings.hdEffectsEnabled = enhanced
                    settings.lemmingSelectionStyle = .modern
                    game.applySettings(settings)
                    let blocker = try #require(ClassicSkill.allCases.firstIndex(of: .blocker))
                    let bomber = try #require(ClassicSkill.allCases.firstIndex(of: .bomber))
                    for _ in 0..<200 where !game.targetCandidates(for: blocker).contains(where: { $0.assignment == .eligible }) { game.tick() }
                    let target = try #require(game.targetCandidates(for: blocker).first(where: { $0.assignment == .eligible }))
                    #expect(game.assign(control: blocker, to: target.id))
                    if nuke { #expect(game.beginEndRun()) }
                    else { #expect(game.assign(control: bomber, to: target.id)) }
                    for _ in 0..<250 where game.finalSimulation.lemmings.first?.action != .exploding { game.tick() }
                    #expect(game.finalSimulation.lemmings.first?.animationFrame == 0)
                    let highlight = MobileTargetSelection(id: target.id, point: target.point, state: .eligible)
                    let pop = try game.render(highlight: highlight)
                    #expect(game.selectionSprite == nil)
                    #expect(game.assignmentSprite == nil)
                    #expect(game.spriteHighlight(for: target.id) == nil)
                    #expect(game.targetCandidates(for: bomber).isEmpty)
                    let explosion = try #require(game.explosions.first)
                    let birth = explosion.birthTick
                    let actor = try #require(game.finalSimulation.lemmings.first)
                    #expect(explosion.sprayOrigin == .init(x: Double(actor.foot.x), y: Double(actor.foot.y - 6)))
                    if graphics == .dosVGA {
                        let animation = try #require(assets.animation(for: .explosion, direction: .none))
                        #expect(explosion.rect.x == Double(actor.foot.x + animation.offsetX))
                        #expect(explosion.rect.y == Double(actor.foot.y + animation.offsetY))
                        #expect(explosion.rect.width == Double(animation.frames[0].width))
                    }
                    for _ in 0..<4 { game.tick() }
                    let cut = try game.render(highlight: highlight)
                    #expect(pop != cut)
                    #expect(game.explosions.first?.birthTick == birth)
                    for _ in 0..<12 { game.tick() }
                    #expect(game.explosions.isEmpty)
                    #expect(game.finalSimulation.lemmings.first?.action == .exploding)
                    #expect(try game.render(highlight: highlight) == cut)
                    #expect(try game.render(highlight: nil) == cut)
                    #expect(game.rewind(seconds: 16 / game.ticksPerSecond))
                    #expect(try game.render(highlight: highlight) == pop)
                    #expect(game.explosions.first?.birthTick == birth)
                }
            }
        }
    }
}
