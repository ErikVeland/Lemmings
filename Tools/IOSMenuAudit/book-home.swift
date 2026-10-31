import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkBookHome(typography: GameMenuTypography, content: URL, output: URL) throws {
        let logos = GameHomeLogoArt(resources: content.deletingLastPathComponent().deletingLastPathComponent(), brand: .allNewWorld)
        guard logos.image(.lemmings2) != nil, logos.image(.lemmings3) != nil else { throw invalidTargets(line: #line) }
        let typography = GameMenuTypography(interface: typography.interface, homeLogos: logos)
        let poses: [(String, MobileSize, [MobileReservedRegion])] = [
            ("book", .init(width: 1194, height: 834), [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            ("short-open", .init(width: 1194, height: 690), [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 690))]),
            ("compact", .init(width: 650, height: 465), [.init(kind: .division, frame: .init(x: 318, y: 0, width: 14, height: 465))]),
            ("tall", .init(width: 834, height: 1194), [.init(kind: .division, frame: .init(x: 409, y: 0, width: 16, height: 1194))]),
            ("camera", .init(width: 1194, height: 834), [
                .init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
                .init(kind: .occlusion, frame: .init(x: 1120, y: 20, width: 74, height: 60))])
        ]
        var captures = 0
        for (pose, size, regions) in CommandLine.arguments.last == "--book-home-flat" ? [] : poses {
            let safe = MobileRect(x: 0, y: 20, width: size.width, height: size.height - 40)
            let physical = MobileDisplayRegions.bookPanes(in: safe, avoiding: regions)
            guard physical.count == 2 else { throw invalidTargets(line: #line) }
            for interface in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(interface, width: safe.width)
                let panes = physical.map { CGRect(x: $0.minX / scale, y: ($0.minY - safe.minY) / scale,
                    width: $0.width / scale, height: $0.height / scale) }
                let viewport = CGSize(width: safe.width / scale, height: safe.height / scale)
                for state in ["solo", "resume", "hot-seat", "unavailable", "long"] {
                    let families: [GameFrontEnd.Action] = [
                        .init("family.classic", "Classic Lemmings 0/120"),
                        .init("family.ohNo", "Oh No! More Lemmings 0/100"),
                        .init("family.holiday", "Holiday Lemmings 0/8"),
                        .init("family.ohYes", "Oh Yes! More Lemmings 0/60"),
                        .init("family.fan", "Fan Lemmings 0/6020"), .init("neolemmix", "NeoLemmix Preview"),
                        .init("l2", "Lemmings 2", enabled: state != "unavailable", gameLogo: .lemmings2),
                        .init("l3", Lemmings3Brand.allNewWorld.displayName, gameLogo: .lemmings3)]
                    var resume: [GameFrontEnd.Action] = state == "solo" ? []
                        : [.init("resume", state == "long" ? "Resume the journey with ALICE and BOB" : "Resume Journey")]
                    if state == "long" { resume.append(.init("resumeLevel", "Resume level - PLA")) }
                    var page = MobileHomeArt.page(resume: resume, journey: .init("journey", "Journey map 1/227 solved"),
                        families: families, initials: state == "hot-seat" ? "ALICE v BOB" : "PLA",
                        nextPlayerIndex: state == "hot-seat" ? 0 : nil,
                        subtitle: state == "hot-seat" ? "" : "Next: PLA", collectionsAvailable: state != "unavailable",
                        deskClock: true)
                    if state == "unavailable" {
                        page.rows[page.rows.count - 3].selected = true
                        if let index = page.footer.firstIndex(where: { $0.id == "whatsNew" }) { page.footer[index].busy = true }
                    }
                    let layout = GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height,
                        boxedHome: true, bookHomePanes: panes)
                    if interface == .standard, ["book", "short-open", "tall"].contains(pose), state != "long" {
                        guard layout.size.height <= viewport.height else { throw invalidTargets(line: #line) }
                    }
                    guard let secondary = layout.secondaryBoard, layout.libraryHeading != nil,
                          layout.board.maxX <= panes[0].maxX, secondary.minX >= panes[1].minX,
                          Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)),
                          layout.targets.filter({ $0.action.primary }).count == 1 else { throw invalidTargets(line: #line) }
                    for pane in panes {
                        guard layout.targets.contains(where: { page.rows.contains($0.action) && $0.frame.minX >= pane.minX && $0.frame.maxX <= pane.maxX })
                        else { throw invalidTargets(line: #line) }
                    }
                    for (index, target) in layout.targets.enumerated() {
                        let frame = target.frame
                        let physicalFrame = frame.applying(.init(scaleX: scale, y: scale)).offsetBy(dx: 0, dy: safe.minY)
                        let scroll = min(max(0, layout.size.height - viewport.height), max(0, frame.maxY - viewport.height + 12))
                        let visible = frame.offsetBy(dx: 0, dy: -scroll)
                        guard frame.width * scale >= 44, frame.height * scale >= 44,
                              CGRect(origin: .zero, size: layout.size).contains(frame),
                              CGRect(origin: .zero, size: viewport).contains(visible),
                              regions.allSatisfy({ !physicalFrame.intersects(cg($0.frame)) }),
                              layout.action(at: .init(x: frame.midX, y: frame.midY)) == (target.action.enabled ? target.action.id : nil),
                              layout.targets.dropFirst(index + 1).allSatisfy({ !frame.intersects($0.frame) })
                        else { throw invalidTargets(line: #line) }
                    }
                    for region in regions where region.kind == .division {
                        guard layout.action(at: .init(x: region.frame.midX / scale, y: 200)) == nil else { throw invalidTargets(line: #line) }
                    }
                    let footer = layout.targets.first { $0.action.id == "donate" }!.frame
                    for (position, scroll) in [("top", CGFloat.zero), ("footer", max(0, min(layout.size.height - viewport.height, footer.maxY - viewport.height + 12)))] {
                        let context = try bitmapContext(size: .init(width: size.width, height: size.height))
                        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                        context.saveGState(); context.translateBy(x: 0, y: safe.minY)
                        context.clip(to: CGRect(x: 0, y: 0, width: safe.width, height: safe.height))
                        context.scaleBy(x: scale, y: scale); context.translateBy(x: 0, y: -scroll)
                        GameFrontEnd.draw(page, layout: layout, typography: typography,
                            highlighted: position == "top" ? "resume" : "donate", shape: .rounded, in: context)
                        context.restoreGState()
                        for region in regions {
                            context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame))
                        }
                        try save(context: context, to: output.appendingPathComponent("\(pose)-\(interface.rawValue)-\(state)-\(position).png"))
                        captures += 1
                    }
                }
            }
        }
        let families: [GameFrontEnd.Action] = [
            .init("family.classic", "Classic Lemmings 0/120"), .init("family.ohNo", "Oh No! More Lemmings 0/100"),
            .init("family.holiday", "Holiday Lemmings 0/72"), .init("family.ohYes", "Oh Yes! More Lemmings 0/60"),
            .init("family.fan", "Fan Lemmings 0/6020"), .init("neolemmix", "NeoLemmix Preview"),
            .init("l2", "Lemmings 2", gameLogo: .lemmings2), .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        let page = MobileHomeArt.page(journey: .init("journey", "Resume Journey"), families: families,
                                      initials: "PLA", collectionsAvailable: true, deskClock: true)
        let screen = MobileRect(x: 0, y: 0, width: 950, height: 667)
        let region = screen
        let layout = GameFrontEnd.layout(page, width: region.width, minimumHeight: region.height, boxedHome: true)
        let backdrop = GameMenuBackdropArt.geometry(in: CGRect(origin: .zero, size: layout.size),
            layout: layout, scale: 1, shape: .rounded)
        guard layout.size.height <= region.height,
              backdrop.frame.maxY <= region.height,
              abs(layout.board.midY + region.y - screen.height / 2) <= 1,
              Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)),
              layout.targets.allSatisfy({ $0.frame.width >= 44 && $0.frame.height >= 44 &&
                  CGRect(origin: .zero, size: layout.size).contains($0.frame) &&
                  layout.action(at: CGPoint(x: $0.frame.midX, y: $0.frame.midY)) == ($0.action.enabled ? $0.action.id : nil) })
        else { throw invalidTargets(line: #line) }
        let context = try bitmapContext(size: CGSize(width: screen.width, height: screen.height))
        context.translateBy(x: region.x, y: region.y)
        GameFrontEnd.draw(page, layout: layout, typography: typography, shape: .rounded, in: context)
        try save(context: context, to: output.appendingPathComponent("inner-flat-home.png"))
        for (index, obstacle) in [CGRect(x: 860, y: 0, width: 90, height: 80),
                         CGRect(x: 0, y: 0, width: 90, height: 80),
                         CGRect(x: 860, y: 587, width: 90, height: 80),
                         CGRect(x: 0, y: 587, width: 90, height: 80)].enumerated() {
            let adjusted = GameFrontEnd.avoidingObstructions(layout, obstacles: [obstacle])
            for target in adjusted.targets where obstacle.intersects(target.frame) {
                print("Obstructed Home action: \(target.action.id) \(target.frame) obstacle \(obstacle)")
            }
            guard adjusted.targets.allSatisfy({ !obstacle.intersects($0.frame) }),
                  adjusted.targets.allSatisfy({ adjusted.action(at: CGPoint(x: $0.frame.midX, y: $0.frame.midY)) == ($0.action.enabled ? $0.action.id : nil) })
            else { throw invalidTargets(line: #line) }
            let context = try bitmapContext(size: CGSize(width: screen.width, height: screen.height))
            GameFrontEnd.draw(page, layout: adjusted, typography: typography, shape: .rounded, in: context)
            context.setFillColor(CGColor(gray: 0.3, alpha: 1)); context.fill(obstacle)
            try save(context: context, to: output.appendingPathComponent("inner-flat-obstruction-\(index).png"))
        }
        for bottom in [false, true] {
            for leading in [false, true] {
                let obstacle = MobileRect(x: leading ? 0 : 860, y: bottom ? 587 : 0, width: 90, height: 80)
                let row = MobileRect(x: 0, y: bottom ? 611 : 0, width: 950, height: 56)
                let clear = MobileDisplayRegions.clearHorizontalFrame(row,
                    avoiding: [.init(kind: .occlusion, frame: obstacle)])
                let navigation = GameNavigationArt.layout(width: clear.width,
                    actions: GameNavigationArt.actions(back: true, secondary: "Settings"))
                guard navigation.targets.allSatisfy({ target in
                    let frame = target.frame.offsetBy(dx: clear.x, dy: clear.y)
                    return frame.width >= 44 && frame.height >= 44 &&
                        !frame.intersects(CGRect(x: obstacle.x, y: obstacle.y, width: obstacle.width, height: obstacle.height))
                }) else { throw invalidTargets(line: #line) }
            }
        }
        for size in [CGSize(width: 950, height: 667), CGSize(width: 495, height: 720), CGSize(width: 720, height: 495)] {
            for leading in [false, true] {
                for bottom in [false, true] {
                    let obstacle = MobileReservedRegion(kind: .occlusion,
                        frame: .init(x: leading ? 0 : size.width - 90, y: bottom ? size.height - 80 : 0, width: 90, height: 80))
                    let browser = LevelBrowserGeometry(safe: CGRect(origin: .zero, size: size), actionCount: 6,
                        actionTitles: ["Back", "Previous rank", "Next rank", "Favourite", "Playlist", "Play"],
                        rankActions: 1..<3, occlusions: [obstacle])
                    let blocked = CGRect(x: obstacle.frame.x, y: obstacle.frame.y, width: obstacle.frame.width, height: obstacle.frame.height)
                    let labels = ["Back", "Previous rank", "Next rank", "Favourite", "Playlist", "Play"]
                    guard browser.actions.count == 6, browser.actions.enumerated().allSatisfy({ index, frame in
                        frame.width >= 44 && frame.height >= 44 && !frame.intersects(blocked) &&
                            GameTextLayout.height(labels[index], width: frame.width - 24) <= frame.height
                    }), !browser.title.intersects(blocked), !browser.subtitle.intersects(blocked),
                    browser.actions.enumerated().allSatisfy({ index, frame in
                        browser.actions.dropFirst(index + 1).allSatisfy { !frame.intersects($0) }
                    }) else { throw invalidTargets(line: #line) }
                    let solution = MobileSolutionSelectorArt.presentation(in: CGRect(origin: .zero, size: size),
                        showsGhost: true, style: .touch, avoiding: [obstacle])
                    guard !solution.controls.intersects(blocked), solution.content.width == size.width,
                          MobileSolutionSelectorArt.layout(width: solution.controls.width, showsGhost: true, style: .touch)
                            .targets.allSatisfy({ $0.width >= 44 && $0.height >= 44 })
                    else { throw invalidTargets(line: #line) }
                }
            }
        }
        print("PASS: \(captures) book Home captures and centred inner Home; action sets, clearance, touch targets, hit testing and scroll reachability. Windowless and muted.")
    }
}
