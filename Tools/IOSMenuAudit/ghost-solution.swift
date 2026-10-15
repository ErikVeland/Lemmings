import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkGhostSolution(library: ClassicMobileLibrary, typography: GameMenuTypography,
                                             resources: URL, output: URL) throws {
        let live = try library.loadLevel(at: 0).session as! ClassicMobileSession
        guard let solution = VerifiedSolution.load(initial: live.initialSimulation, from: resources),
              let study = try live.makeReplaySession(document: JSONEncoder().encode(solution.replay)),
              live.installGhostSolution(solution.replay) else { throw Failure.missingArtwork }
        let tick = ReplayMoveNavigation.classic(initial: solution.initial, replay: solution.replay).ticks.first! + 60
        _ = study.seekReplay(to: tick + 30)
        let studyTick = study.snapshot.tick
        for _ in 0..<tick { live.tick() }
        _ = live.drainSoundCues()
        let before = try JSONSerialization.jsonObject(with: live.checkpointPayload()) as! NSDictionary
        let plain = try live.render(highlight: nil)
        live.ghostSolutionEnabled = true
        let ghost = try live.render(highlight: nil)
        guard ghost != plain, live.ghostSolutionTick == live.snapshot.tick,
              study.snapshot.tick == studyTick, live.drainSoundCues().isEmpty,
              before.isEqual(try JSONSerialization.jsonObject(with: live.checkpointPayload())) else { throw invalidTargets(line: #line) }
        // Every opaque live sprite stays above the ghosts.
        for sprite in live.rescueSprites {
            for y in 0..<sprite.frame.height { for x in 0..<sprite.frame.width {
                let src = (y * sprite.frame.width + x) * 4
                guard sprite.frame.rgba[src + 3] == 255 else { continue }
                let px = Int(sprite.rect.x * live.renderScale) + x, py = Int(sprite.rect.y * live.renderScale) + y
                guard px >= 0, py >= 0, px < plain.width, py < plain.height else { continue }
                let dst = (py * plain.width + px) * 4
                guard ghost.rgba[dst..<dst + 4] == plain.rgba[dst..<dst + 4] else { throw invalidTargets(line: #line) }
            } }
        }
        for enabled in [false, true] {
            live.ghostSolutionEnabled = enabled
            let frame = try live.render(highlight: nil)
            let image = MobileBitmapRenderer.image(frame)!
            for (name, size, _) in [("narrow", CGSize(width: 320, height: 548), CGFloat(1)),
                                        ("phone", CGSize(width: 390, height: 763), CGFloat(1)),
                                        ("landscape", CGSize(width: 756, height: 369), CGFloat(1)),
                                        ("ipad", CGSize(width: 1112, height: 814), CGFloat(1)),
                                        ("tv", CGSize(width: 1920, height: 1080), CGFloat(2))] {
                let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                    bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                let viewport = MobileViewport(levelSize: live.levelSize, viewSize: .init(width: size.width, height: size.height),
                    origin: live.initialCameraOrigin, zoom: name == "tv" ? 4 : 3)
                MobileBitmapRenderer.draw(image, viewport: viewport, in: context)
                // Replay choices live in the paused panel. Gameplay keeps only the ghost sprites.
                let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("\(name)-ghost-\(enabled).png") as CFURL,
                    "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, context.makeImage()!, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
            }
        }
        live.ghostSolutionEnabled = true
        guard live.rewind(seconds: 2) else { throw invalidTargets(line: #line) }
        _ = try live.render(highlight: nil)
        guard live.ghostSolutionTick == live.snapshot.tick, study.snapshot.tick == studyTick else { throw invalidTargets(line: #line) }
        live.ghostSolutionEnabled = false
        let parked = live.ghostSolutionTick
        _ = live.stepForward()
        _ = try live.render(highlight: nil)
        guard live.ghostSolutionTick == parked else { throw invalidTargets(line: #line) }
        let retry = try library.loadLevel(at: 0).session as! ClassicMobileSession
        live.ghostSolutionEnabled = true
        retry.inheritGhostSolution(from: live)
        _ = try retry.render(highlight: nil)
        guard retry.ghostSolutionEnabled, retry.ghostSolutionTick == 0 else { throw invalidTargets(line: #line) }
        let otherLevel = try library.loadLevel(at: 1).session as! ClassicMobileSession
        otherLevel.inheritGhostSolution(from: live)
        guard !otherLevel.hasGhostSolution else { throw invalidTargets(line: #line) }
        print("PASS ghost rendering, live sprite priority, checkpoint isolation, silent seeking, retained study cursor, rewind, retry and 10 platform renders.")
    }
}
