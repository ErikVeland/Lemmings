import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkRoundedHUD(typography: GameMenuTypography, content: URL, output: URL) throws {
        let cornerSample = CGRect(x: 0, y: 0, width: 64, height: 80)
        let ordinary = GameControlGroupArt.path(in: cornerSample)
        let left = GameControlGroupArt.path(in: cornerSample, bottomLeft: true)
        let right = GameControlGroupArt.path(in: cornerSample, bottomRight: true)
        let leftPoint = CGPoint(x: 1, y: 52), rightPoint = CGPoint(x: 63, y: 52)
        guard ordinary.contains(leftPoint), ordinary.contains(rightPoint),
              !left.contains(leftPoint), left.contains(rightPoint),
              !right.contains(rightPoint), right.contains(leftPoint) else { throw invalidTargets(line: #line) }
        let ports = content.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let libraries: [any MobileGameLibrary] = [try ClassicMobileLibrary(directory: content),
            try Lemmings2MobileLibrary(directory: ports.appendingPathComponent("Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: ports.appendingPathComponent("LEM3CD"), storage: storage)]
        let poses: [(String, MobileSize, MobileInsets, MobileInsets, CGFloat, [MobileReservedRegion])] = [
            ("ipad-landscape", .init(width: 1024, height: 768), .init(bottom: 20), .init(), 20, []),
            ("ipad-wide", .init(width: 1366, height: 1024), .init(bottom: 20), .init(), 20, []),
            ("duo-main", .init(width: 834, height: 1194), .init(left: 64), .init(), 90, []),
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
                let menuLeading = regions.isEmpty && pose != "duo-main"
                let rail: MobileRect? = pose == "duo-main" ? .init(x: 0, y: 110, width: 64, height: 974) : nil
                let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                let screen = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
                func fits(_ frame: CGRect) -> Bool {
                    let box = frame.insetBy(dx: 0.01, dy: 0.01)
                    return [CGPoint(x: box.minX, y: box.minY), .init(x: box.maxX, y: box.minY),
                        .init(x: box.minX, y: box.maxY), .init(x: box.maxX, y: box.maxY)].allSatisfy { screen.contains($0) }
                }
                // Model corner adaptation on the longer axis without consuming the
                // short playfield dimension. Every visible control must fit the screen.
                let cornerSafe = size.width > size.height
                    ? MobileInsets(top: safe.top, left: max(safe.left, radius), bottom: safe.bottom, right: max(safe.right, radius))
                    : MobileInsets(top: max(safe.top, radius), left: safe.left, bottom: max(safe.bottom, radius), right: safe.right)
                for state in ["running", "paused", "selected-last", "undo"] {
                    let original = session.snapshot
                    let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                        saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                        releaseRate: original.releaseRate, isComplete: false, didWin: false,
                        isEndingRun: state == "undo", skills: original.skills)
                    let layout = MobileHUDLayout.make(container: size, safeArea: cornerSafe, hasRate: snapshot.releaseRate != nil,
                        skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: session.engineIdentifier, topBarInsets: clearance, navigationRail: rail,
                        menuLeading: menuLeading)
                    let baseline = MobileHUDLayout.make(container: size, safeArea: cornerSafe, hasRate: snapshot.releaseRate != nil,
                        skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true, hasPlayer: true,
                        engineIdentifier: session.engineIdentifier, navigationRail: rail)
                    let selected = state == "selected-last" ? snapshot.skills.count - 1 : 0
                    let paused = state == "paused"
                    let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot,
                        selectedSkill: selected, paused: paused, speed: 1, endRunArmed: false)
                    let visibleTargets = targets.filter { item in
                        guard let portrait = layout.portrait, case .skill = item.action else { return true }
                        return portrait.skills.contains(item.inputFrame)
                    }
                    guard visibleTargets.allSatisfy({ fits($0.inputFrame) }) else { throw invalidTargets(line: #line) }
                    let identity = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: true)
                    if menuLeading, let menu = targets.first(where: { $0.action == .menu }),
                       menu.frame.maxX + 4 != layout.interface.statusFrame.minX {
                        print("Header geometry \(session.engineIdentifier) \(pose): menu=\(menu.frame) status=\(layout.interface.statusFrame) safe=\(layout.interface.safeFrame)")
                    }
                    guard layout.canPlay, layout.interface.playfieldFrame == baseline.interface.playfieldFrame,
                          layout.interface.controlsFrame == baseline.interface.controlsFrame,
                          let menu = targets.first(where: { $0.action == .menu }), fits(menu.inputFrame),
                          menu.inputFrame.width == (rail?.width ?? 44) && menu.inputFrame.height == 44,
                          (!menuLeading || (menu.frame.maxX + 4 == layout.interface.statusFrame.minX &&
                              layout.interface.statusFrame.maxX == layout.interface.safeFrame.maxX - clearance.right)),
                          targets.first(where: { $0.inputFrame.contains(.init(x: menu.frame.midX, y: menu.frame.midY)) })?.action == .menu,
                          targets.filter({ $0.action != .menu }).allSatisfy({ !$0.inputFrame.intersects(menu.inputFrame) })
                    else { throw invalidTargets(line: #line) }
                    for item in targets where item.action == .pause || item.action == .endRun {
                        let centre = CGPoint(x: item.inputFrame.midX, y: item.inputFrame.midY)
                        guard targets.first(where: { $0.inputFrame.contains(centre) })?.action == item.action
                        else { throw invalidTargets(line: #line) }
                    }
                    let skills = targets.filter { if case .skill = $0.action { return true }; return false }
                    if layout.portrait != nil {
                        for group in GameHUDControlGroup.groups(skills.map(\.frame), maximumGap: 0.01) {
                            let frames = group.map { skills[$0].frame }
                            if frames.allSatisfy({ $0.minY == frames.first?.minY }) {
                                let ordered = frames.sorted { $0.minX < $1.minX }
                                for (left, right) in zip(ordered, ordered.dropFirst()) {
                                    guard abs(left.maxX - right.minX) < 0.01 else { throw invalidTargets(line: #line) }
                                }
                            }
                        }
                        for skill in visibleTargets where skills.contains(where: { $0.action == skill.action }) {
                            let centre = CGPoint(x: skill.inputFrame.midX, y: skill.inputFrame.midY)
                            guard targets.first(where: { $0.inputFrame.contains(centre) })?.action == skill.action
                            else { throw invalidTargets(line: #line) }
                        }
                    }
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
                        endRunArmed: false, panelImage: panel, typography: typography, skillIcons: icons, playerName: "PLA", shape: .rounded,
                        duoCorners: !pose.hasPrefix("ipad-"))
                        .draw(in: context, bounds: bounds)
                    context.restoreGState()
                    for region in regions { context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame)) }
                    try save(context: context, to: output.appendingPathComponent("\(session.engineIdentifier)-\(pose)-\(state).png"))
                    captures += 1
                }
            }
        }
        print("PASS: \(captures) rounded-screen HUD captures across Classic/L2/L3, both orientations and Duo poses; complete visible control rectangles, bitmap fields, Menu input, reserved regions and unchanged gameplay geometry. Windowless and muted.")
    }
}

private extension CGSize {
    var mobileSize: MobileSize { .init(width: width, height: height) }
}
