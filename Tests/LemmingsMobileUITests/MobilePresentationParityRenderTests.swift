import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import Testing
@testable import LemmingsMobileUI

@MainActor struct MobilePresentationParityRenderTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test func nativeSequelHighlightsUseTheLiveSpriteGeometry() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let storage = MobileStorage(directory: temporary)
        let libraries: [any MobileGameLibrary] = [
            try Lemmings2MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage),
        ]
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            for _ in 0..<120 { session.tick() }
            let target = try #require(session.targetCandidates(for: 0).first)
            let plain = try session.render(highlight: nil)
            let sprite = try #require(session.spriteHighlight(for: target.id))
            let a = try capture(plain, session: session, target: target.point, sprite: nil,
                name: session.engineIdentifier + "-plain")
            let b = try capture(plain, session: session, target: target.point, sprite: sprite,
                name: session.engineIdentifier + "-selection")
            #expect(a != b)
        }
    }

    @Test func neoGhostsUseTheSharedArchiveWithoutChangingTargetsOrState() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let library = try NeoLemmixMobileLibrary(directory: Self.root.appendingPathComponent("Content/NeoLemmix"),
            storage: MobileStorage(directory: temporary))
        let index = try #require(library.styleResolvedLevelIndices.first)
        let first = try library.loadLevel(at: index).session
        var assignmentTick: Int?
        for _ in 0..<1000 where assignmentTick == nil {
            first.tick()
            for control in first.snapshot.skills.indices where assignmentTick == nil {
                if let candidate = first.targetCandidates(for: control).first(where: { $0.assignment == .eligible }),
                   first.assign(control: control, to: candidate.id) { assignmentTick = first.snapshot.tick }
            }
        }
        let assigned = try #require(assignmentTick)
        for _ in 0..<5000 where first.snapshot.released < first.snapshot.total && !first.snapshot.isComplete { first.tick() }
        #expect(first.snapshot.released == first.snapshot.total)
        #expect(first.beginEndRun())
        for _ in 0..<5000 where !first.snapshot.isComplete { first.tick() }
        #expect(first.snapshot.isComplete)
        let recorded = try #require(try first.actionCapture())
        let conditions = TrolleyConditions(gameID: "neolemmix", packID: "parity", levelID: "1",
            levelFingerprint: first.levelFingerprint, rulesetVersion: "fixture", physicsMode: "fixture",
            population: recorded.initial.population, rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: nil)
        let level = ArcadeLevel(id: "neo", title: "Neo", game: "NeoLemmix", rules: "fixture",
            total: recorded.initial.population, required: 1, conditions: conditions)
        let run = ArcadeRun(profileID: "other", level: level, saved: recorded.final.saved,
            didWin: recorded.final.didWin, skills: first.assignedSkills,
            seconds: Double(recorded.final.tick) / first.ticksPerSecond)
        let replay = try LeaderboardActionReplay.capture(run: run, initial: recorded.initial,
            final: recorded.final, commands: recorded.commands)
        _ = try replay.checked(initial: recorded.initial)
        let game = try library.loadLevel(at: index).session
        game.hotSeatGhosts = HotSeatGhostPlayback(attempts: [.init(playerID: "other", colour: .pink, replay: replay)], initial: recorded.initial)
        for _ in 0..<(assigned + 20) where game.snapshot.tick < assigned + 20 && !game.snapshot.isComplete { game.tick() }
        #expect(game.snapshot.tick == assigned + 20)
        let state = try #require(JSONSerialization.jsonObject(with: game.checkpointPayload()) as? NSDictionary)
        let targets = game.targetCandidates(for: 0).map(\.id)
        let target = try #require(game.targetCandidates(for: 0).first)
        let ghosts = try game.render(highlight: nil)
        game.hotSeatGhosts?.hidden = true
        let plain = try game.render(highlight: nil)
        #expect(ghosts != plain)
        #expect(try JSONSerialization.jsonObject(with: game.checkpointPayload()) as? NSDictionary == state)
        #expect(game.targetCandidates(for: 0).map(\.id) == targets)
        #expect(game.spriteHighlight(for: target.id) != nil)
        _ = try capture(ghosts, session: game, target: target.point, sprite: nil, name: "neo-ghosts")
        _ = try capture(plain, session: game, target: target.point,
            sprite: game.spriteHighlight(for: target.id), name: "neo-selection")
    }

    private func capture(_ frame: MobilePixelFrame, session: any MobileGameSession,
                         target: MobilePoint, sprite: MobileSpriteHighlight?, name: String) throws -> Data {
        let width = 640, height = 320
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        let viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: 640, height: 320),
            origin: .init(x: target.x - 80, y: target.y - 40), zoom: 4)
        MobileBitmapRenderer.draw(try #require(MobileBitmapRenderer.image(frame)), viewport: viewport, in: context)
        if let sprite {
            let point = viewport.viewPoint(fromLevel: .init(x: sprite.rect.x, y: sprite.rect.y))
            let rect = CGRect(x: point.x, y: point.y, width: sprite.rect.width * viewport.zoom,
                height: sprite.rect.height * viewport.zoom)
            LemmingSelectionRenderer.draw(.init(sprite: try #require(MobileBitmapRenderer.image(sprite.frame)),
                rect: rect, clipRect: CGRect(x: 0, y: 0, width: width, height: height), bloom: false), in: context)
        }
        let image = try #require(context.makeImage())
        let output = Self.root.appendingPathComponent(".build/platform-parity/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let path = output.appendingPathComponent(name + ".png")
        let destination = try #require(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return try Data(contentsOf: path)
    }
}
