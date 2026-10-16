import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkRoundedHUD(typography: GameMenuTypography, content: URL, output: URL) throws {
        let ports = content.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let libraries: [any MobileGameLibrary] = [try ClassicMobileLibrary(directory: content),
            try Lemmings2MobileLibrary(directory: ports.appendingPathComponent("Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: ports.appendingPathComponent("LEM3CD"), storage: storage)]
        let poses: [(String, MobileSize, MobileInsets, MobileInsets, CGFloat, [MobileReservedRegion])] = [
            ("landscape", .init(width: 650, height: 465), .init(top: 20, bottom: 20), .init(left: 48, right: 48), 90, []),
            ("portrait", .init(width: 465, height: 650), .init(top: 20, bottom: 20), .init(left: 48, right: 48), 90, []),
            ("book", .init(width: 1194, height: 834), .init(top: 20, bottom: 20), .init(left: 56, right: 56), 110,
                [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            ("stacked", .init(width: 834, height: 1194), .init(top: 20, bottom: 20), .init(left: 56, right: 56), 110,
                [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))]),
            ("edge-to-edge", .init(width: 844, height: 390), .init(bottom: 21), .init(left: 80, right: 80), 72, []),
            ("existing-safe-area", .init(width: 844, height: 390), .init(left: 47, bottom: 21, right: 47), .init(left: 8, right: 8), 50, [])
        ]
        var captures = 0
        for library in libraries {
            let session = try library.loadLevel(at: 0).session
            var settings = ClassicSettings(); settings.music = .silent
            session.applySettings(settings)
            for _ in 0..<100 { session.tick() }
            let image = MobileBitmapRenderer.image(try session.render(highlight: nil))
            let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
            let icons = session.snapshot.skills.indices.map { session.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
            for (pose, size, safe, clearance, radius, regions) in poses {
                let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                let screen = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
                func fits(_ frame: CGRect) -> Bool {
                    let box = frame.insetBy(dx: 0.01, dy: 0.01)
                    return [CGPoint(x: box.minX, y: box.minY), .init(x: box.maxX, y: box.minY),
                        .init(x: box.minX, y: box.maxY), .init(x: box.maxX, y: box.maxY)].allSatisfy { screen.contains($0) }
                }
                for state in ["running", "paused", "selected-last", "undo"] {
                    let original = session.snapshot
                    let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                        saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                        releaseRate: original.releaseRate, isComplete: false, didWin: false,
                        isEndingRun: state == "undo", skills: original.skills)
                    let layout = MobileHUDLayout.make(container: size, safeArea: safe, hasRate: snapshot.releaseRate != nil,
                        skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: session.engineIdentifier, topBarInsets: clearance)
                    let baseline = MobileHUDLayout.make(container: size, safeArea: safe, hasRate: snapshot.releaseRate != nil,
                        skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: session.engineIdentifier)
                    let selected = state == "selected-last" ? snapshot.skills.count - 1 : 0
                    let paused = state == "paused"
                    let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot,
                        selectedSkill: selected, paused: paused, speed: 1, endRunArmed: false)
                    let identity = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                    guard layout.canPlay, layout.interface.playfieldFrame == baseline.interface.playfieldFrame,
                          layout.interface.controlsFrame == baseline.interface.controlsFrame,
                          let menu = targets.first(where: { $0.action == .menu }), fits(menu.inputFrame),
                          menu.inputFrame.width == 44 && menu.inputFrame.height == 44,
                          targets.first(where: { $0.inputFrame.contains(.init(x: menu.frame.midX, y: menu.frame.midY)) })?.action == .menu,
                          targets.filter({ $0.action != .menu }).allSatisfy({ !$0.inputFrame.intersects(menu.inputFrame) })
                    else { throw invalidTargets(line: #line) }
                    for frame in [identity.player, identity.counters].compactMap({ $0 }) {
                        guard fits(frame), !frame.intersects(menu.inputFrame),
                              regions.allSatisfy({ !frame.intersects(cg($0.frame)) }) else { throw invalidTargets(line: #line) }
                    }
                    for field in MobileHUDRenderer.statusFields(in: identity.counters, snapshot: snapshot, details: nil,
                        engineIdentifier: session.engineIdentifier, paused: paused, speed: 1, typography: typography) {
                        guard fits(field.frame), identity.counters.contains(field.frame) else { throw invalidTargets(line: #line) }
                    }
                    let context = try bitmapContext(size: bounds.size)
                    context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(bounds)
                    context.saveGState(); context.addPath(screen); context.clip()
                    context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(bounds)
                    let field = cg(layout.interface.playfieldFrame)
                    var viewport = MobileViewport(levelSize: session.levelSize, viewSize: field.size.mobileSize,
                        pixelAspect: session.renderScale == 1 ? 1.2 : 1)
                    viewport.fitGameplay(in: field.size.mobileSize, centring: session.entrancePoint)
                    if let image {
                        context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                        MobileBitmapRenderer.draw(image, viewport: viewport, in: context); context.restoreGState()
                    }
                    MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selected, paused: paused, speed: 1,
                        endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons, playerName: "PLA")
                        .draw(in: context, bounds: bounds)
                    context.restoreGState()
                    for region in regions { context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame)) }
                    try save(context: context, to: output.appendingPathComponent("\(session.engineIdentifier)-\(pose)-\(state).png"))
                    captures += 1
                }
            }
        }
        print("PASS: \(captures) rounded-screen HUD captures across Classic/L2/L3, both orientations and Duo poses; complete header rectangles, bitmap fields, Menu input, reserved regions and unchanged gameplay geometry. Windowless and muted.")
    }
}

private extension CGSize {
    var mobileSize: MobileSize { .init(width: width, height: height) }
}
