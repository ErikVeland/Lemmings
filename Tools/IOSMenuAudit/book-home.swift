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
            ("compact", .init(width: 650, height: 465), [.init(kind: .division, frame: .init(x: 318, y: 0, width: 14, height: 465))]),
            ("tall", .init(width: 834, height: 1194), [.init(kind: .division, frame: .init(x: 409, y: 0, width: 16, height: 1194))]),
            ("camera", .init(width: 1194, height: 834), [
                .init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
                .init(kind: .occlusion, frame: .init(x: 1120, y: 20, width: 74, height: 60))])
        ]
        var captures = 0
        for (pose, size, regions) in poses {
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
                        subtitle: state == "hot-seat" ? "Next: ALICE" : "Next: PLA", collectionsAvailable: state != "unavailable",
                        deskClock: true)
                    if state == "unavailable" {
                        page.rows[page.rows.count - 3].selected = true
                        if let index = page.footer.firstIndex(where: { $0.id == "whatsNew" }) { page.footer[index].busy = true }
                    }
                    let layout = GameFrontEnd.layout(page, width: viewport.width, minimumHeight: viewport.height,
                        boxedHome: true, bookHomePanes: panes)
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
                            highlighted: position == "top" ? "resume" : "donate", in: context)
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
        print("PASS: \(captures) book Home captures; two lists, complete action sets, hinge/camera clearance, touch targets, disabled/selected/busy states, hit testing and scroll reachability. Windowless and muted.")
    }
}
