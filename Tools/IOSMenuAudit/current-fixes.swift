import Foundation
import CoreGraphics
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkCurrentFixes(library: ClassicMobileLibrary, typography: GameMenuTypography, output: URL) async throws {
        let session = try library.loadLevel(at: 0).session
        var settings = ClassicSettings()
        settings.lemmingSelectionStyle = .modern
        session.applySettings(settings)
        for _ in 0..<60 { session.tick() }
        guard let candidate = session.targetCandidates(for: 7).first else { throw Failure.missingArtwork }
        let highlighted = try session.render(highlight: .init(id: candidate.id, point: candidate.point, state: candidate.assignment))
        guard MobileBitmapRenderer.image(highlighted) != nil, let sprite = session.selectionSprite,
            let image = MobileBitmapRenderer.image(try session.render(highlight: nil)) else { throw Failure.missingArtwork }
        let uses = [MobileReplaySkillUse(tick: 104, name: "Builder"), .init(tick: 121, name: "Climber"), .init(tick: 146, name: "Floater")]
        var captures: [[String: Any]] = []
        for (name, size) in [("iphone-portrait", MobileSize(width: 390, height: 763)),
                             ("iphone-landscape", .init(width: 756, height: 369)),
                             ("narrow-portrait", .init(width: 320, height: 548)),
                             ("narrow-landscape", .init(width: 568, height: 300)),
                             ("ipad-portrait", .init(width: 834, height: 1092)),
                             ("ipad-landscape", .init(width: 1112, height: 814)),
                             ("ipad-pro-9-7-portrait", .init(width: 768, height: 1024)),
                             ("ipad-pro-12-9-portrait", .init(width: 1024, height: 1366)),
                             ("portrait-safe-edge-region", .init(width: 390, height: 844)),
                             ("portrait-playfield-region", .init(width: 390, height: 844))] {
            let regions: [MobileReservedRegion] = name == "portrait-safe-edge-region"
                ? [.init(kind: .occlusion, frame: .init(x: 160, y: 0, width: 70, height: 20))]
                : name == "portrait-playfield-region"
                ? [.init(kind: .occlusion, frame: .init(x: 0, y: 200, width: 20, height: 100))] : []
            let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                hasRate: true, skillCount: session.snapshot.skills.count, reservedRegions: regions,
                supportsRewind: true)
            if size.height > size.width, layout.portrait == nil { throw invalidTargets(line: #line) }
            let targets = MobileHUDRenderer.targets(layout: layout, snapshot: session.snapshot, selectedSkill: 0,
                paused: true, speed: 1, endRunArmed: false)
            for (index, target) in targets.enumerated() {
                guard target.inputFrame.width >= 44 - 0.001, target.inputFrame.height >= 44,
                    hudTargetFits(target, layout: layout), hudScrollTargetIsReachable(target, layout: layout) else { throw invalidTargets(line: #line) }
                for other in targets.dropFirst(index + 1) {
                    let overlap = hudVisibleInputFrame(target, layout: layout).intersection(hudVisibleInputFrame(other, layout: layout))
                    guard overlap.isNull || overlap.width <= 0.001 || overlap.height <= 0.001 else { throw invalidTargets(line: #line) }
                }
            }
            let context = try bitmapContext(size: .init(width: size.width, height: size.height))
            let field = cg(layout.interface.playfieldFrame)
            let viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: field.width, height: field.height),
                origin: session.initialCameraOrigin, zoom: 2, pixelAspect: 1.2)
            context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
            MobileBitmapRenderer.draw(image, viewport: viewport, in: context)
            let effects = MobileRescueArt.effects(sprites: [sprite], viewport: viewport, amount: 1, enabled: true) {
                MobileBitmapRenderer.image($0.frame)
            }
            var crowdImages = 0
            let crowd = MobileRescueArt.effects(sprites: Array(repeating: sprite, count: 500),
                viewport: viewport, amount: 1, enabled: true, maximumEffects: 2) {
                    crowdImages += 1
                    return MobileBitmapRenderer.image($0.frame)
                }
            guard crowd.count == 1, crowdImages == 1 else { throw invalidTargets(line: #line) }
            guard !effects.isEmpty,
                MobileRescueArt.effects(sprites: [sprite], viewport: viewport, amount: 1, enabled: false, image: { _ in nil }).isEmpty,
                MobileRescueArt.effects(sprites: [sprite], viewport: viewport, amount: 0, enabled: true, image: { _ in nil }).isEmpty
                else { throw invalidTargets(line: #line) }
            for effect in effects { LemmingSelectionRenderer.draw(effect, in: context) }
            context.restoreGState()
            if CommandLine.arguments.last == "--rescue-budget" {
                let file = name + "-rescue-budget.png"
                try save(context: context, to: output.appendingPathComponent(file))
                captures.append(["device": name, "file": file, "crowd": 500, "glows": crowd.count, "images": crowdImages])
                continue
            }
            let width = min(240, max(0, field.width - 16))
            let panel = CGRect(x: field.maxX - width - 8, y: field.minY + (layout.portrait != nil ? 56 : 8), width: width,
                height: width * MobileReplaySkillArt.size.height / MobileReplaySkillArt.size.width)
            guard field.contains(panel), targets.allSatisfy({ !panel.intersects($0.inputFrame) }) else { throw invalidTargets(line: #line) }
            if layout.canPlay { MobileReplaySkillArt.draw(uses: uses, tick: 146, in: panel, typography: typography, context: context) }
            MobileHUDRenderer(layout: layout, snapshot: session.snapshot, selectedSkill: 0, paused: true, speed: 1, endRunArmed: false,
                panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image), typography: typography, readOnly: true)
                .draw(in: context, bounds: .init(x: 0, y: 0, width: size.width, height: size.height))
            if let minimap = layout.minimapFrame {
                GameMinimapArt.draw(in: context, bounds: minimap, image: image, visible: cg(viewport.visibleLevelRect),
                    levelSize: CGSize(width: session.levelSize.width, height: session.levelSize.height), overlay: layout.portrait != nil)
            }
            if !layout.canPlay {
                let page = GameFrontEnd.Page(title: "Paused", footer: [.init("library", "Library", primary: true)])
                let menu = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard menu.targets.allSatisfy({ $0.frame.width >= 44 && $0.frame.height >= 44 }) else { throw invalidTargets(line: #line) }
                GameFrontEnd.draw(page, layout: menu, typography: typography, in: context)
            }
            let file = name + "-replay-rescue.png"
            try save(context: context, to: output.appendingPathComponent(file))
            captures.append(["device": name, "file": file, "targets": targets.count, "rescueMasks": effects.count,
                             "canPlay": layout.canPlay, "portrait": layout.portrait != nil])
        }
        try JSONSerialization.data(withJSONObject: ["captures": captures, "windows": "none", "audio": "muted",
            "replayPanelOverlapsControls": false, "physicalUIKitAcceptance": "pending"], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("current-fixes.json"))
        print("PASS: \(captures.count) renders, rescue crowd bounds, control targets and reduced-effect gates.")
    }
}
