import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore

extension MenuAudit {
    @MainActor static func checkReplayControls(library: ClassicMobileLibrary, typography: GameMenuTypography, output: URL) throws {
        let loaded = try library.loadLevel(at: 0)
        let session = loaded.session
        guard let image = MobileBitmapRenderer.image(try session.render(highlight: nil)) else { throw Failure.missingArtwork }
        let level = MobileLevelSummary(index: 33, rank: "Fun", number: 34,
            title: "The Crankshaft and a very long level name that must end with an ellipsis")
        let uses: [MobileReplaySkillUse] = [.init(tick: 104, name: "Builder"), .init(tick: 121, name: "Climber"), .init(tick: 146, name: "Floater")]
        var count = 0
        for engine in ["classic-dos", "lemmings2", "lemmings3"] {
            for size in [MobileSize(width: 320, height: 568), .init(width: 390, height: 844),
                         .init(width: 844, height: 390), .init(width: 1194, height: 834), .init(width: 834, height: 1194)] {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20),
                    hasRate: engine == "classic-dos", skillCount: 8, supportsRewind: true, engineIdentifier: engine)
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: session.snapshot, selectedSkill: 0,
                    paused: true, speed: 1, endRunArmed: false)
                guard let moves = ReplayMoveArt.frame(layout: layout) else { throw invalidTargets(line: #line) }
                let map = ReplayMoveArt.mapFrame(in: moves)
                let buttons = ReplayMoveArt.frames(in: moves)
                guard map.width >= 44, map.height >= 44,
                      buttons.allSatisfy({ button in button.width >= 44 && button.height >= 44 && !button.intersects(map)
                        && targets.allSatisfy({ !button.intersects($0.inputFrame) }) }),
                      targets.allSatisfy({ !map.intersects($0.inputFrame) }) else { throw invalidTargets(line: #line) }
                let field = cg(layout.interface.playfieldFrame)
                let obstacles = targets.map(\.inputFrame) + buttons + [map]
                guard let skills = MobileReplaySkillArt.frame(in: field, below: field.minY, avoiding: obstacles),
                      skills.minY == field.minY + 8, skills.maxX == field.maxX - 8,
                      obstacles.allSatisfy({ !skills.intersects($0) }) else { throw invalidTargets(line: #line) }
                let status = MobileHUDRenderer.statusFrames(layout: layout, hasPlayer: false)
                let title = MobileHUDRenderer.replayStatusFrames(in: status.counters).title
                let caption = MobileReplayTitleArt.caption(level: level, width: title.width, typography: typography)
                guard caption.hasSuffix("..."), typography.width(of: caption, face: .small, scale: 1) <= title.width - 16
                else { throw invalidTargets(line: #line) }
                for (name, previous, next, paused) in [("start", false, true, true), ("playing", true, true, false),
                                                      ("move", true, true, true), ("end", true, false, true)] {
                    let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
                    let viewport = MobileViewport(levelSize: session.levelSize,
                        viewSize: .init(width: field.width, height: field.height), origin: session.initialCameraOrigin, zoom: 2, pixelAspect: 1.2)
                    context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                    MobileBitmapRenderer.draw(image, viewport: viewport, in: context)
                    context.restoreGState()
                    MobileHUDRenderer(layout: layout, snapshot: session.snapshot, selectedSkill: 0, paused: paused,
                        speed: 1, endRunArmed: false, panelImage: session.panelFrame.flatMap(MobileBitmapRenderer.image),
                        typography: typography, readOnly: true, replayLevel: level).draw(in: context,
                            bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    if name != "start" {
                        MobileReplaySkillArt.draw(uses: uses, tick: 146, in: skills, typography: typography, context: context)
                    }
                    GameMinimapArt.draw(in: context, bounds: map, image: image, visible: cg(viewport.visibleLevelRect),
                        levelSize: CGSize(width: session.levelSize.width, height: session.levelSize.height), overlay: true)
                    ReplayMoveArt.draw(previous: previous, next: next, in: moves, typography: typography, context: context)
                    try save(context: context, to: output.appendingPathComponent("\(engine)-\(Int(size.width))x\(Int(size.height))-\(name).png"))
                    count += 1
                }
            }
        }
        print("PASS: \(count) replay HUD renders, single-line titles, top-right skills, map and 44-point move targets across three engine layouts. Classic scene fixture; physical UIKit gestures remain manual.")
    }
}
