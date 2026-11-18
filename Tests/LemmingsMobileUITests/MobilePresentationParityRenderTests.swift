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

    @Test func chroniclesPressedArtworkIsClippedToTheActiveControls() throws {
        let storage = try AppStorage.temporary(named: "chronicles-pressed-art")
        defer { storage.removeTemporaryFiles() }
        let library = try Lemmings3MobileLibrary(directory: Self.root.appendingPathComponent("Sources/Ports/LEM3CD"),
            storage: MobileStorage(directory: storage.applicationSupport))
        let session = try #require(try library.loadLevel(at: 0).session as? Lemmings3MobileSession)
        let normal = try #require(session.panelFrame.flatMap(MobileBitmapRenderer.image))
        let pressed = try #require(session.pressedPanelFrame.flatMap(MobileBitmapRenderer.image))
        let snapshot = session.snapshot
        let active: [MobileHUDAction] = [.skill(2), .pause, .speed, .endRun]
        for (width, height, television) in [(320, 568, false), (834, 590, false), (1920, 1080, true)] {
            let layout = MobileHUDLayout.make(container: .init(width: Double(width), height: Double(height)),
                safeArea: .init(), hasRate: false, skillCount: snapshot.skills.count,
                engineIdentifier: session.engineIdentifier, television: television)
            let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 2,
                paused: true, speed: 2, endRunArmed: true)
            func render(_ panel: CGImage, readOnly: Bool = false) throws -> CGContext {
                let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                let bounds = CGRect(x: 0, y: 0, width: width, height: height)
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 2, paused: true,
                    speed: 2, endRunArmed: true, panelImage: normal, pressedPanelImage: panel,
                    typography: nil, readOnly: readOnly).draw(in: context, bounds: bounds)
                return context
            }
            let withPressed = try render(pressed)
            let baseline = try render(normal)
            let a = try #require(withPressed.data)
            let b = try #require(baseline.data)
            for target in targets {
                let box = target.frame.insetBy(dx: 3, dy: 3).integral
                #expect(target.frame.width >= 44 && target.frame.height >= 44)
                let changed = (Int(box.minY)..<Int(box.maxY)).contains { row in
                    let offset = row * withPressed.bytesPerRow + Int(box.minX) * 4
                    return memcmp(a.advanced(by: offset), b.advanced(by: offset), Int(box.width) * 4) != 0
                }
                let usesPressed = layout.panel?.style == .lemmings3 ? active.contains(target.action) : target.action == .skill(2)
                #expect(changed == usesPressed, "\(width)×\(height) \(target.action)")
            }
            #expect(active.allSatisfy { action in targets.contains { $0.action == action } })
            let replayPressed = try render(pressed, readOnly: true)
            let replayNormal = try render(normal, readOnly: true)
            #expect(memcmp(try #require(replayPressed.data), try #require(replayNormal.data), width * height * 4) == 0)
        }
    }

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
            let state = session.snapshot
            var settings = ClassicSettings()
            settings.graphics = .macintosh
            session.applySettings(settings)
            let mac = try session.render(highlight: nil)
            let macSprite = try #require(session.spriteHighlight(for: target.id))
            #expect(mac.width == plain.width * 2 && mac.height == plain.height * 2)
            #expect(macSprite.rect == sprite.rect)
            #expect(macSprite.frame.width == sprite.frame.width * 2)
            #expect(session.snapshot == state)
            _ = try capture(mac, session: session, target: target.point, sprite: macSprite,
                name: session.engineIdentifier + "-mac-selection")
        }
    }

    @Test func sequelMenusRenderReachableControlsAcrossDisplaySizes() throws {
        let typography = try #require(GameMenuTypography(directory: Self.root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let pages = [MobileSequelMenuArt.practice(choice: 0, skills: [.builder, .basher, .digger, .jumper, .climber, .floater, .roper, .runner], subtitle: ""),
            MobileSequelMenuArt.movies(engine: "lemmings2"), MobileSequelMenuArt.movies(engine: "lemmings3"),
            MobileSequelMenuArt.movie(.tribesEnding, paused: false, finished: false, failure: nil),
            MobileSequelMenuArt.movie(.chronicles(.introduction), paused: true, finished: false, failure: nil),
            ShortGamesArt.page(available: ["classic", "classic-follow-up", "lemmings2"], selected: "classic-follow-up")]
        let shortGames = try #require(pages.last)
        #expect(shortGames.rows.filter(\.selected).map(\.id) == ["shortSelect.classic-follow-up"])
        #expect(shortGames.footer.last?.enabled == true)
        #expect(ShortGamesArt.page(available: ["classic"], selected: "classic-follow-up").footer.last?.enabled == false)
        let output = Self.root.appendingPathComponent(".build/platform-parity/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (width, height) in [(320, 568), (590, 834), (834, 590), (1920, 1080)] {
            for (index, page) in pages.enumerated() {
                let layout = GameFrontEnd.layout(page, width: CGFloat(width), minimumHeight: CGFloat(height))
                #expect(Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)))
                for target in layout.targets {
                    #expect(target.frame.width >= 44 && target.frame.height >= 44)
                    #expect(target.frame.minX >= 0 && target.frame.maxX <= layout.size.width)
                    #expect(target.frame.minY >= 0 && target.frame.maxY <= layout.size.height)
                }
                let context = try #require(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("menu-\(width)-\(index).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
                #expect(CGImageDestinationFinalize(destination))
            }
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
