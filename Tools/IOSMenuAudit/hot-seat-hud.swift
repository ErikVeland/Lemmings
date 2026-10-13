import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    @MainActor static func checkHotSeatHUD(library: ClassicMobileLibrary, typography: GameMenuTypography, output: URL) throws {
        let session = try library.loadLevel(at: 0).session
        for _ in 0..<60 { session.tick() }
        guard let image = MobileBitmapRenderer.image(try session.render(highlight: nil)) else { throw Failure.missingArtwork }
        let poses: [(String, MobileSize, MobileInsets, [MobileReservedRegion])] = [
            ("iphone-portrait", .init(width: 390, height: 844), .init(top: 59, bottom: 34), []),
            ("iphone-landscape", .init(width: 844, height: 390), .init(left: 59, bottom: 21, right: 59), []),
            ("iphone-narrow", .init(width: 320, height: 568), .init(top: 20), []),
            ("compact", .init(width: 568, height: 300), .init(), []),
            ("ipad-portrait", .init(width: 768, height: 1024), .init(top: 20, bottom: 20), []),
            ("ipad-landscape", .init(width: 1024, height: 768), .init(top: 20, bottom: 20), []),
            ("divided", .init(width: 1112, height: 834), .init(top: 20, bottom: 20),
                [.init(kind: .division, frame: .init(x: 0, y: 400, width: 1112, height: 20))]),
            ("occluded", .init(width: 390, height: 844), .init(top: 59, bottom: 34),
                [.init(kind: .occlusion, frame: .init(x: 0, y: 200, width: 20, height: 100))])
        ]
        var captures: [[String: Any]] = []
        for (pose, size, insets, regions) in poses {
            for (state, name, paused) in [("solo", nil as String?, false), ("host", "LEM", false),
                                         ("guest", "AB", false), ("paused-guest", "AB", true)] {
                let layout = MobileHUDLayout.make(container: size, safeArea: insets, hasRate: true,
                    skillCount: session.snapshot.skills.count, reservedRegions: regions, supportsRewind: true,
                    hasPlayer: name != nil)
                guard layout.canPlay else { throw Failure.invalidTargets }
                let frames = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: name != nil)
                guard (frames.player != nil) == (name != nil), frames.counters.height >= 20 else { throw Failure.invalidTargets }
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: session.snapshot,
                    selectedSkill: 0, paused: paused, speed: 1, endRunArmed: false)
                for (index, target) in targets.enumerated() {
                    guard target.inputFrame.width >= 44 - 0.001, target.inputFrame.height >= 44,
                          hudTargetFits(target, layout: layout), hudScrollTargetIsReachable(target, layout: layout)
                    else { throw Failure.invalidTargets }
                    let visible = hudVisibleInputFrame(target, layout: layout)
                    for other in targets.dropFirst(index + 1) {
                        let overlap = visible.intersection(hudVisibleInputFrame(other, layout: layout))
                        guard overlap.isNull || overlap.width <= 0.001 || overlap.height <= 0.001 else { throw Failure.invalidTargets }
                    }
                    if let player = frames.player {
                        guard !player.intersects(visible), !frames.counters.intersects(visible) else { throw Failure.invalidTargets }
                    }
                }
                if let player = frames.player {
                    guard cg(layout.interface.safeFrame).contains(player), !player.intersects(frames.counters),
                          !player.intersects(cg(layout.interface.playfieldFrame)),
                          regions.allSatisfy({ !player.intersects(cg($0.frame)) }) else { throw Failure.invalidTargets }
                }
                let context = try bitmapContext(size: .init(width: size.width, height: size.height))
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                let field = cg(layout.interface.playfieldFrame)
                context.saveGState(); context.clip(to: field)
                GameStoneArt.drawImage(image, in: field, context: context)
                context.restoreGState()
                MobileHUDRenderer(layout: layout, snapshot: session.snapshot, selectedSkill: 0,
                    paused: paused, speed: 1, endRunArmed: false,
                    panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image), typography: typography,
                    playerName: name).draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                let file = pose + "-" + state + ".png"
                try save(context: context, to: output.appendingPathComponent(file))
                captures.append(["file": file, "player": name ?? "solo", "paused": paused,
                    "layout": layout.panel != nil ? "panel" : layout.portrait != nil ? "two-rows" : "compact",
                    "targets": targets.count])
            }
        }
        try JSONSerialization.data(withJSONObject: captures, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("captures.json"))
        print("PASS: \(captures.count) Hot Seat HUD renders and input targets; owner, solo, pause, rotation, compact and reserved-region states.")
    }
}
