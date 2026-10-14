import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

@main struct TVControlFeedbackChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/playtest-control-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let storage = MobileStorage(directory: output.appendingPathComponent("temporary-saves"))
        let classic = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let l2 = try Lemmings2MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/Lemm2"), storage: storage)
        let l3 = try Lemmings3MobileLibrary(directory: root.appendingPathComponent("Sources/Ports/LEM3CD"), storage: storage)
        let typography = GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let libraries: [(String, any MobileGameLibrary)] = [("classic", classic), ("l2", l2), ("l3", l3)]
        for (name, library) in libraries {
            let content = try library.loadLevel(at: 0)
            let session = content.session
            for _ in 0..<140 where !session.snapshot.isComplete { session.tick() }
            let snapshot = session.snapshot
            let layout = MobileHUDLayout.make(container: .init(width: 1280, height: 720), safeArea: .init(),
                hasRate: snapshot.releaseRate != nil, skillCount: snapshot.skills.count,
                supportsRewind: session.supportsRewind, engineIdentifier: session.engineIdentifier)
            for paused in [false, true] {
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: 0,
                    paused: paused, speed: 1, endRunArmed: false)
                precondition(targets.contains { $0.action == .pause } && targets.contains { $0.action == .menu })
                let skills = targets.filter { if case .skill = $0.action { return true }; return false }
                precondition(skills.count == snapshot.skills.count)
                for (index, target) in skills.enumerated() {
                    precondition(target.inputFrame.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)))
                    for other in skills.dropFirst(index + 1) { precondition(!target.inputFrame.intersects(other.inputFrame)) }
                }
                let context = CGContext(data: nil, width: 1280, height: 720, bitsPerComponent: 8, bytesPerRow: 1280 * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.translateBy(x: 0, y: 720); context.scaleBy(x: 1, y: -1)
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1280, height: 720))
                let field = layout.interface.playfieldFrame
                context.saveGState(); context.translateBy(x: field.x, y: field.y)
                var viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: field.width, height: field.height), zoom: 1)
                viewport.fitGameplay(in: viewport.viewSize, centring: session.entrancePoint)
                MobileBitmapRenderer.draw(MobileBitmapRenderer.image(try session.render(highlight: nil))!, viewport: viewport, in: context)
                context.restoreGState()
                let icons = snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
                let renderer = MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: 0, paused: paused,
                    speed: 1, endRunArmed: false, panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image),
                    typography: typography, skillIcons: icons)
                renderer.draw(in: context, bounds: CGRect(x: 0, y: 0, width: 1280, height: 720))
                TVPlayfieldArt.drawAimPointer(at: CGPoint(x: 80, y: 80), eligible: false, occupied: false, context: context)
                TVPlayfieldArt.drawAimPointer(at: CGPoint(x: 140, y: 80), eligible: false, occupied: true, context: context)
                if let target = skills.first {
                    TVPlayfieldArt.drawAimPointer(at: CGPoint(x: target.frame.midX, y: target.frame.midY), eligible: true, occupied: true, context: context)
                }
                let file = output.appendingPathComponent(name + (paused ? "-paused.png" : "-playing.png"))
                let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil)!
                CGImageDestinationAddImage(destination, context.makeImage()!, nil)
                precondition(CGImageDestinationFinalize(destination))
            }
            if let typography {
                let info = MobilePauseSummary(level: content.summary, snapshot: snapshot,
                    activeCount: session.activeLemmingCount, ticksPerSecond: session.ticksPerSecond,
                    speed: 1, assignedSkills: session.assignedSkillCount, supportsRewind: session.supportsRewind,
                    usedRewind: session.usedRewind, isReplay: false, soundtrack: "Amiga", track: "Original soundtrack", audio: "Music paused")
                let page = MobilePauseArt.page(info, actions: [.init("resume", "Resume", primary: true),
                    .init("library", "Library"), .init("restart", "Restart level"),
                    .init("controls", "Game controls"), .init("settings", "Settings")])
                for size in [CGSize(width: 1280, height: 720), CGSize(width: 844, height: 390)] {
                    let base = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                    let viewport = CGRect(origin: .zero, size: size)
                    let menu = MobilePauseArt.pinningFooter(base, viewport: viewport)
                    precondition(menu.targets.contains { $0.action.id == "settings" })
                    for (index, target) in menu.targets.enumerated() {
                        precondition(viewport.contains(target.frame) && target.frame.height >= 44)
                        precondition(menu.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                        for other in menu.targets.dropFirst(index + 1) { precondition(!target.frame.intersects(other.frame)) }
                    }
                    let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                        bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                    GameFrontEnd.draw(page, layout: menu, typography: typography, in: context)
                    let file = output.appendingPathComponent(name + "-menu-\(Int(size.width)).png")
                    let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil)!
                    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
                    precondition(CGImageDestinationFinalize(destination))
                }
            }
        }
        print("PASS twelve Classic/L2/L3 HUD/pause renders, pointer states, skill targets and direct Settings targets")
    }
}
