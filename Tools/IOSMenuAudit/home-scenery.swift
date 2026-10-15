import Foundation
import CoreGraphics
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkHomeScenery(typography: GameMenuTypography, content: URL, output: URL) async throws {
        let ports = content.deletingLastPathComponent()
        let root = ports.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let native: [MobileGameDataKind: URL] = [.lemmings2: ports.appendingPathComponent("Lemm2"),
                                                .lemmings3: ports.appendingPathComponent("LEM3CD")]
        let loader = MobileHomeBackdropLoader()
        var settings = ClassicSettings(); settings.music = .silent
        let libraries: [(MobileGameDataKind, any MobileGameLibrary)] = [
            (.classic, try ClassicMobileLibrary(directory: content)),
            (.lemmings2, try Lemmings2MobileLibrary(directory: native[.lemmings2]!, storage: storage)),
            (.lemmings3, try Lemmings3MobileLibrary(directory: native[.lemmings3]!, storage: storage))]
        let families: [GameFrontEnd.Action] = [
            .init("family.classic", "Classic Lemmings  10/120"), .init("family.ohNo", "Oh No! More Lemmings  24/100"),
            .init("family.holiday", "Holiday Lemmings  3/72"), .init("family.ohYes", "Oh Yes! More Lemmings  0/60"),
            .init("family.fan", "Fan Lemmings  0/6022"), .init("neolemmix", "NeoLemmix  2/788"),
            .init("l2", "Lemmings 2", gameLogo: .lemmings2), .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        let devices: [(String, CGSize, Bool)] = [("ipad-landscape", CGSize(width: 1366, height: 1024), false),
            ("ipad-portrait", CGSize(width: 1024, height: 1366), false),
            ("ipad-small", CGSize(width: 1024, height: 768), false),
            ("ipad-split", CGSize(width: 390, height: 1024), false),
            ("tv-1080", CGSize(width: 1920, height: 1080), true),
            ("tv-safe-area", CGSize(width: 1728, height: 972), true),
            ("tv-4k", CGSize(width: 3840, height: 2160), true)]
        var captures = 0
        for (kind, library) in libraries {
            let index = kind == .lemmings3 ? 30 : 0
            let key = library.levelKey(at: index)
            let reference = MobileHomeBackdropReference(kind: kind, level: key)
            try storage.save(reference, name: "home-scenery-solo")
            guard storage.load(MobileHomeBackdropReference.self, name: "home-scenery-solo") == reference,
                  storage.load(MobileHomeBackdropReference.self, name: "home-scenery-hotseat.test") == nil else { throw invalidTargets(line: #line) }
            guard let scenery = try await loader.load(preferred: reference, recent: nil, ports: ports, fanFolders: [],
                native: native, classicDirectory: content, storage: storage, settings: settings),
                  let image = MobileBitmapRenderer.image(scenery.frame) else { throw invalidTargets(line: #line) }
            let expected = try library.loadLevel(at: index).session
            expected.applySettings(settings)
            guard scenery.frame == (try expected.render(highlight: nil)), expected.snapshot.tick == 0,
                  expected.goalPoint.x != expected.levelSize.width else { throw invalidTargets(line: #line) }
            let map = CGSize(width: image.width, height: image.height)
            for (device, size, television) in devices {
                for interface in ClassicInterfaceSize.allCases {
                    let scale = MobileSettingsArt.interfaceScale(interface, width: size.width, television: television)
                    let viewport = CGSize(width: size.width / scale, height: size.height / scale)
                    let resume = interface == .standard ? [] : [GameFrontEnd.Action("resume", "Resume level - AB v CD")]
                    var page = MobileHomeArt.page(resume: resume, journey: .init("journey", "Journey map  4/227 solved"),
                        families: families, initials: "AB v CD", subtitle: television ? "Version 2.0\n15 October 2026" : "")
                    // Unavailable import and selected actions retain the same geometry.
                    page.rows[page.rows.count - 3].enabled = interface != .extraLarge
                    let layout = GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height, boxedHome: true)
                    for (index, target) in layout.targets.enumerated() {
                        guard layout.board.contains(target.frame), target.frame.width >= 44, target.frame.height >= 44,
                              layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                            else { throw invalidTargets(line: #line) }
                        for other in layout.targets.dropFirst(index + 1) where target.frame.intersects(other.frame) { throw invalidTargets(line: #line) }
                    }
                    if viewport.height > layout.board.height + 80 {
                        guard layout.board.minY > 20, layout.board.maxY < viewport.height - 20 else { throw invalidTargets(line: #line) }
                    }
                    let source = GameHomeBackdropArt.source(imageSize: map, viewSize: size,
                        start: CGPoint(x: scenery.start.x, y: scenery.start.y), goal: CGPoint(x: scenery.goal.x, y: scenery.goal.y), elapsed: 60)
                    guard CGRect(origin: .zero, size: map).insetBy(dx: -0.001, dy: -0.001).contains(source) else { throw invalidTargets(line: #line) }
                    let footer = layout.targets.first { $0.action.id == "collections" }!.frame
                    let offset = max(0, min(layout.size.height - viewport.height, footer.maxY - viewport.height + 8))
                    for (position, scroll) in [("top", CGFloat.zero), ("footer", offset)] {
                        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw invalidTargets(line: #line) }
                        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                        GameHomeBackdropArt.draw(image: image, source: source, in: CGRect(origin: .zero, size: size), context: context)
                        context.saveGState(); context.scaleBy(x: scale, y: scale); context.translateBy(x: 0, y: -scroll)
                        GameFrontEnd.draw(page, layout: layout, typography: typography,
                            highlighted: position == "top" ? "journey" : "collections", fillsCanvas: false, in: context)
                        context.restoreGState()
                        guard let rendered = context.makeImage(), let destination = CGImageDestinationCreateWithURL(
                            output.appendingPathComponent("\(kind.rawValue)-\(device)-\(interface.rawValue)-\(position).png") as CFURL,
                            "public.png" as CFString, 1, nil) else { throw invalidTargets(line: #line) }
                        CGImageDestinationAddImage(destination, rendered, nil)
                        guard CGImageDestinationFinalize(destination) else { throw invalidTargets(line: #line) }
                        captures += 1
                    }
                }
            }
        }
        var clock = GameHomeBackdropClock()
        clock.advance(at: 0, active: true, reduceMotion: false)
        clock.advance(at: 0.1, active: true, reduceMotion: false)
        let moving = clock.elapsed
        clock.advance(at: 10, active: true, reduceMotion: true)
        clock.advance(at: 20, active: false, reduceMotion: false)
        clock.advance(at: 1000, active: true, reduceMotion: false)
        guard moving > 0, clock.elapsed == moving else { throw invalidTargets(line: #line) }
        clock.advance(at: 1000.1, active: true, reduceMotion: false)
        guard abs(clock.elapsed - 0.2) < 0.001 else { throw invalidTargets(line: #line) }
        let missing = MobileHomeBackdropReference(kind: .classic, pack: "missing", level: "missing")
        guard try await loader.load(preferred: missing, recent: nil, ports: ports, fanFolders: [], native: [:],
            classicDirectory: content, storage: storage, settings: settings) != nil,
              try await loader.load(preferred: nil, recent: nil, ports: nil, fanFolders: [], native: [:],
            classicDirectory: nil, storage: storage, settings: settings) == nil else { throw invalidTargets(line: #line) }
        let start = CGPoint(x: 160, y: 80), goal = CGPoint(x: 1440, y: 80)
        let imageSize = CGSize(width: 1600, height: 160), viewSize = CGSize(width: 900, height: 620)
        let opening = GameHomeBackdropArt.source(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal, elapsed: 0)
        let duration = max(60, (goal.x - opening.midX) * .pi / 6)
        let end = GameHomeBackdropArt.source(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal, elapsed: duration)
        let back = GameHomeBackdropArt.source(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal, elapsed: duration * 2)
        guard abs(end.midX - goal.x) < 0.001, abs(back.minX - opening.minX) < 0.001 else { throw invalidTargets(line: #line) }
        print("PASS \(captures) iPad/TV Home renders, three interface sizes, targets, full Classic/L2/L3 scenery, scoped references, missing/random fallback, reduced-motion/inactive clock and exit camera bounds/return; windowless and muted. Resources: \(root.lastPathComponent)")
    }
}
