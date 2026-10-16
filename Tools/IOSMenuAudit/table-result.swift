import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkTableResult(typography: GameMenuTypography, content: URL, output: URL) throws {
        let ports = content.deletingLastPathComponent()
        let storage = MobileStorage(directory: output.appendingPathComponent("isolated-storage"))
        let libraries: [any MobileGameLibrary] = [try ClassicMobileLibrary(directory: content),
            try Lemmings2MobileLibrary(directory: ports.appendingPathComponent("Lemm2"), storage: storage),
            try Lemmings3MobileLibrary(directory: ports.appendingPathComponent("LEM3CD"), storage: storage)]
        var captures = 0
        for library in libraries {
            let level = try library.loadLevel(at: 0)
            let image = MobileBitmapRenderer.image(try level.session.render(highlight: nil))
            for (name, size, book) in [("large", CGSize(width: 834, height: 1194), false),
                ("compact", .init(width: 465, height: 900), false),
                ("book", .init(width: 1194, height: 834), true),
                ("book-compact", .init(width: 650, height: 465), true),
                ("book-camera", .init(width: 1194, height: 834), true)] {
                let safe = MobileRect(x: 0, y: 24, width: size.width, height: size.height - 48)
                let hinge = MobileReservedRegion(kind: .division, frame: book
                    ? .init(x: size.width / 2 - 8, y: 0, width: 16, height: size.height)
                    : .init(x: 0, y: size.height / 2 - 8, width: size.width, height: 16))
                var regions = [hinge]
                if name == "book-camera" { regions.append(.init(kind: .occlusion,
                    frame: .init(x: size.width - 56, y: 24, width: 56, height: 60))) }
                let panes = MobileDisplayRegions.resultPanes(in: safe, avoiding: regions)
                guard panes.count == 2, panes.allSatisfy({ pane in regions.allSatisfy { !pane.intersects($0.frame) } }),
                      book ? panes[0].maxX <= panes[1].minX : panes[0].maxY <= panes[1].minY
                else { throw invalidTargets(line: #line) }
                for setting in ClassicInterfaceSize.allCases {
                    for (state, saved, won) in [("win", 10, true), ("partial", 6, true), ("loss", 0, false), ("hot-seat", 10, true)] {
                        let run = ArcadeRun(profileID: "PLA", level: .init(id: "test", title: level.summary.title,
                            game: level.session.engineIdentifier, rules: "fixture", total: 10, required: 5),
                            saved: saved, didWin: won, skills: ["digger": 1], seconds: 42)
                        let goals = TrolleyRescueGoals(run: run, maximum: .init())
                        var items = MobileResultAchievementsArt.goals(goals)
                        if won {
                            items += [.init("First clear", detail: "First clear of this level. Rescued \(saved); target 5."),
                                .init("+1 ZOOM", detail: "Career stars: 2 to 3. One Zoom per 3 stars without rewind or undo."),
                                .init("One skill type", detail: "Cleared the level using one skill type.")]
                        }
                        let achievements = MobileResultAchievementsArt.page(items)
                        var result = GameFrontEnd.Page(title: won ? "Level complete" : "Try again", subtitle: "Played: PLA  " + level.summary.caption,
                            details: [level.summary.title, "Saved \(saved)/10  Goal 5", "Time 0:42.00"],
                            footer: (won ? [.init("next", state == "hot-seat" ? "Next: PLAYER TWO" : "Next level", primary: true), .init("retry", "Retry")] : [.init("retry", "Retry", primary: true)])
                                + [.init("back", "Back"), .init("review", "Review"), .init("share", "Share movie"), .init("menu", "Menu")], preview: true)
                        result.result = true; result.detailHeadings = [0]
                        let context = try bitmapContext(size: size)
                        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
                        for (page, pane) in zip([result, achievements], panes) {
                            let preferred = MobileSettingsArt.interfaceScale(setting, width: pane.width)
                            let scale = page.result ? MobileResultAchievementsArt.resultScale(preferred, page: page, width: pane.width, height: pane.height) : preferred
                            let layout = GameFrontEnd.layout(page, width: pane.width / scale, minimumHeight: pane.height / scale, fillsResultPane: page.result)
                            guard layout.details.count == page.details.count,
                                  layout.details.allSatisfy({ CGRect(origin: .zero, size: layout.size).contains($0) })
                            else { throw invalidTargets(line: #line) }
                            if page.result, size.width >= 800 {
                                guard layout.size.height * scale <= pane.height + 0.5 else { throw invalidTargets(line: #line) }
                            }
                            for (index, target) in layout.targets.enumerated() {
                                guard !layout.targets.dropFirst(index + 1).contains(where: { $0.frame.intersects(target.frame) }),
                                      target.frame.maxX * scale <= pane.width + 0.5,
                                      layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id,
                                      target.frame.width * scale >= 44, target.frame.height * scale >= 44
                                else { throw invalidTargets(line: #line) }
                            }
                            context.saveGState(); context.clip(to: cg(pane)); context.translateBy(x: pane.x, y: pane.y); context.scaleBy(x: scale, y: scale)
                            GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image, in: context)
                            context.restoreGState()
                            if page.achievementItems != nil {
                                let all = try bitmapContext(size: .init(width: pane.width, height: ceil(layout.size.height * scale)))
                                all.scaleBy(x: scale, y: scale)
                                GameFrontEnd.draw(page, layout: layout, typography: typography, in: all)
                                try save(context: all, to: output.appendingPathComponent("\(level.session.engineIdentifier)-\(name)-\(setting)-\(state)-all-awards.png"))
                            }
                        }
                        try save(context: context, to: output.appendingPathComponent("\(level.session.engineIdentifier)-\(name)-\(setting)-\(state).png"))
                        captures += 2
                    }
                }
            }
        }
        print("PASS \(captures) book/tabletop result and full achievement captures across Classic, L2 and L3")
    }
}
