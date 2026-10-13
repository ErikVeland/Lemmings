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
                             ("ipad-landscape", .init(width: 1112, height: 814))] {
            let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                hasRate: true, skillCount: session.snapshot.skills.count, supportsRewind: true)
            let targets = MobileHUDRenderer.targets(layout: layout, snapshot: session.snapshot, selectedSkill: 0,
                paused: true, speed: 1, endRunArmed: false)
            for (index, target) in targets.enumerated() {
                guard target.inputFrame.width >= 44 - 0.001, target.inputFrame.height >= 44,
                    cg(layout.interface.safeFrame).contains(target.inputFrame) else { throw Failure.invalidTargets }
                for other in targets.dropFirst(index + 1) {
                    let overlap = target.inputFrame.intersection(other.inputFrame)
                    guard overlap.isNull || overlap.width <= 0.001 || overlap.height <= 0.001 else { throw Failure.invalidTargets }
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
            guard !effects.isEmpty,
                MobileRescueArt.effects(sprites: [sprite], viewport: viewport, amount: 1, enabled: false, image: { _ in nil }).isEmpty,
                MobileRescueArt.effects(sprites: [sprite], viewport: viewport, amount: 0, enabled: true, image: { _ in nil }).isEmpty
                else { throw Failure.invalidTargets }
            for effect in effects { LemmingSelectionRenderer.draw(effect, in: context) }
            context.restoreGState()
            let width = min(240, max(0, field.width - 16))
            let panel = CGRect(x: field.maxX - width - 8, y: field.minY + 8, width: width,
                height: width * MobileReplaySkillArt.size.height / MobileReplaySkillArt.size.width)
            guard field.contains(panel), targets.allSatisfy({ !panel.intersects($0.inputFrame) }) else { throw Failure.invalidTargets }
            if layout.canPlay { MobileReplaySkillArt.draw(uses: uses, tick: 146, in: panel, typography: typography, context: context) }
            MobileHUDRenderer(layout: layout, snapshot: session.snapshot, selectedSkill: 0, paused: true, speed: 1, endRunArmed: false,
                panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image), typography: typography, readOnly: true)
                .draw(in: context, bounds: .init(x: 0, y: 0, width: size.width, height: size.height))
            if !layout.canPlay {
                let page = GameFrontEnd.Page(title: "Paused", footer: [.init("library", "Library", primary: true)])
                let menu = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard menu.targets.allSatisfy({ $0.frame.width >= 44 && $0.frame.height >= 44 }) else { throw Failure.invalidTargets }
                GameFrontEnd.draw(page, layout: menu, typography: typography, in: context)
            }
            let file = name + "-replay-rescue.png"
            try save(context: context, to: output.appendingPathComponent(file))
            captures.append(["device": name, "file": file, "targets": targets.count, "rescueMasks": effects.count, "canPlay": layout.canPlay])
        }
        try JSONSerialization.data(withJSONObject: ["captures": captures, "windows": "none", "audio": "muted",
            "replayPanelOverlapsControls": false, "physicalUIKitAcceptance": "pending"], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("current-fixes.json"))
        print("PASS: six replay and rescue renders, control targets and reduced-effect gates.")
    }
}
