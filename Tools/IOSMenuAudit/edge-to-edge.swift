import CoreGraphics
import Foundation
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

extension MenuAudit {
    @MainActor static func checkEdgeToEdge(typography: GameMenuTypography, content: URL, output: URL) throws {
        let logos = GameHomeLogoArt(resources: content.deletingLastPathComponent().deletingLastPathComponent())
        guard logos.image(.lemmings2) != nil, logos.image(.lemmings3) != nil else { throw Failure.missingArtwork }
        let typography = GameMenuTypography(interface: typography.interface, homeLogos: logos)
        let level = try ClassicMobileLibrary(directory: content).loadLevel(at: 0)
        let preview = MobileBitmapRenderer.image(try level.session.render(highlight: nil))
        let pause = MobilePauseSummary(level: level.summary, snapshot: level.session.snapshot,
            activeCount: 0, ticksPerSecond: 17, speed: 1, assignedSkills: 0,
            supportsRewind: true, usedRewind: false, isReplay: false,
            soundtrack: "Original", track: "A tune for the journey", audio: "Music off / SFX off")
        var result = GameFrontEnd.Page(title: "Level complete", subtitle: "Played: ALICE",
            details: [level.summary.title, "Saved 10/10  Goal 5", "Time 0:42.00"],
            footer: [.init("back", "Back"), .init("next", "Next: BOB", primary: true)], preview: true)
        result.result = true
        var pages: [(String, GameFrontEnd.Page)] = [
            ("home", MobileHomeArt.page(resume: [.init("resume", "Resume journey")],
                journey: .init("journey", "Journey map"), families: [
                    .init("classic", "Classic Lemmings 0/120"), .init("ohno", "Oh No! More Lemmings 0/100"),
                    .init("holiday", "Holiday Lemmings 0/72"), .init("ohyes", "Oh Yes! More Lemmings 0/60"),
                    .init("fan", "Fan Lemmings 0/15000"), .init("neo", "NeoLemmix preview"),
                    .init("l2", "Lemmings 2", gameLogo: .lemmings2),
                    .init("l3", "Lemmings 3", gameLogo: .lemmings3)], initials: "ALI v BOB")),
            ("settings", MobileSettingsArt.groups()),
            ("pause", MobilePauseArt.page(pause, actions: [.init("back", "Library"), .init("resume", "Resume", primary: true)])),
            ("ready", .init(title: level.summary.title, subtitle: "ALICE v BOB  Next: BOB",
                footer: [.init("back", "Back"), .init("ready", "Ready", primary: true)])),
            ("result", result),
            ("recovery", GameRecoveryArt.page(title: "Run was not saved")),
            ("levels", .init(title: "Levels", rows: (1...10).map { .init("level.\($0)", "Level \($0)") }, footer: [.init("back", "Back")])),
            ("reading", MobileInformationArt.effectsWelcome()),
            ("confirmation", .init(title: "Are you sure?", footer: [.init("back", "Back"),
                .init("restore", "Restore previous counts", enabled: false), .init("clear", "Clear counts", primary: true)]))
        ]
        pages += MobileSettingsGroup.allCases.map {
            ($0.rawValue, MobileSettingsArt.page($0, settings: .init(), displayAvailable: true, foldable: true, ghostsVisible: false))
        }
        if CommandLine.arguments.last == "--scroll-obstructions" {
            for (name, page) in pages where !page.home {
              for (width, height) in [(CGFloat(950), CGFloat(667)), (495, 720), (720, 495)] {
               for scale: CGFloat in [1, 1.25, 1.5] {
                let base = GameFrontEnd.layout(page, width: width / scale, minimumHeight: height / scale)
                let maximum = max(0, base.size.height - height / scale)
                for offset in stride(from: CGFloat(0), through: maximum, by: 20) {
                    for x: CGFloat in [0, width - 90] {
                        for y: CGFloat in [0, height - 80] {
                            let obstacle = CGRect(x: x / scale, y: y / scale + offset, width: 90 / scale, height: 80 / scale)
                            let pinned = page.pause != nil ? MobilePauseArt.pinningFooter(base,
                                viewport: CGRect(x: 0, y: offset, width: width / scale, height: height / scale),
                                actionIDs: Set(page.footer.map(\.id))) : base
                            let layout = GameFrontEnd.avoidingObstructions(pinned, obstacles: [obstacle])
                            guard layout.targets.count == base.targets.count,
                                  layout.rowHeadings.allSatisfy({ !obstacle.intersects($0.1) }),
                                  layout.targets.enumerated().allSatisfy({ index, target in
                                !obstacle.intersects(target.frame) && target.frame.width * scale >= 44 &&
                                    target.frame.height * scale >= 44 &&
                                    layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil) &&
                                    layout.targets.dropFirst(index + 1).allSatisfy { !target.frame.intersects($0.frame) }
                            }) else {
                                let blocked = layout.targets.filter { obstacle.intersects($0.frame) }.map { "\($0.action.id) \($0.action.title): \($0.frame), height=\(GameTextLayout.height($0.action.title, width: 330))" }.joined(separator: ", ")
                                let headings = layout.rowHeadings.filter { obstacle.intersects($0.1) }.map { "\($0.0): \($0.1)" }
                                FileHandle.standardError.write(Data("Obstructed \(name), size \(base.size), scale \(scale), offset \(offset), obstacle \(obstacle): \(blocked) headings \(headings)\n".utf8))
                                throw invalidTargets(line: #line)
                            }
                            if name == "gameplay", width == 495, scale == 1, offset == 260, x == 0, y == 0 {
                                let context = try bitmapContext(size: CGSize(width: width, height: height))
                                context.translateBy(x: 0, y: -offset)
                                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview, in: context)
                                context.translateBy(x: 0, y: offset)
                                context.setFillColor(CGColor(gray: 0.3, alpha: 1))
                                context.fill(CGRect(x: x, y: y, width: 90, height: 80))
                                try save(context: context, to: output.appendingPathComponent("scroll-gameplay-corner.png"))
                            }
                        }
                    }
                }
               }
              }
            }
            print("PASS scrolling obstruction geometry")
            return
        }
        typealias Pose = (name: String, bounds: MobileRect, regions: [MobileReservedRegion])
        var poses: [Pose] = []
        for (name, size) in [("front-portrait", CGSize(width: 495, height: 720)),
                             ("tent-landscape", .init(width: 720, height: 495)),
                             ("inner-flat", .init(width: 1194, height: 834)),
                             ("inner-flat-rotated", .init(width: 834, height: 1194)),
                             ("split-window", .init(width: 360, height: 720))] {
            let bounds = MobileRect(x: 0, y: 0, width: size.width, height: size.height)
            poses.append((name + "-clear", bounds, []))
            for leading in [false, true] {
                for top in [false, true] {
                    poses.append((name + "-\(leading ? "left" : "right")-\(top ? "top" : "bottom")", bounds,
                        [.init(kind: .occlusion, frame: .init(x: leading ? 0 : size.width - 92,
                            y: top ? 0 : size.height - 80, width: 92, height: 80))]))
                }
            }
        }
        poses += [
            ("book", .init(x: 0, y: 20, width: 1194, height: 794),
                [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))]),
            ("tabletop", .init(x: 0, y: 20, width: 834, height: 1154),
                [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16))]),
            ("book-camera", .init(x: 0, y: 20, width: 1194, height: 794),
                [.init(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834)),
                 .init(kind: .occlusion, frame: .init(x: 1120, y: 740, width: 74, height: 94))]),
            ("tabletop-camera", .init(x: 0, y: 20, width: 834, height: 1154),
                [.init(kind: .division, frame: .init(x: 0, y: 589, width: 834, height: 16)),
                 .init(kind: .occlusion, frame: .init(x: 0, y: 20, width: 74, height: 94))]),
            ("actual-right-bar", .init(x: 0, y: 0, width: 495, height: 720),
                [.init(kind: .occlusion, frame: .init(x: 403, y: 0, width: 92, height: 720))]),
            ("actual-left-bar", .init(x: 0, y: 0, width: 495, height: 720),
                [.init(kind: .occlusion, frame: .init(x: 0, y: 0, width: 92, height: 720))])
        ]
        var captures = 0, scrollChecks = 0
        for pose in poses {
            for (name, page) in pages {
                let book = page.home ? MobileDisplayRegions.bookPanes(in: pose.bounds, avoiding: pose.regions) : []
                let viewport = book.isEmpty ? MobileDisplayRegions.scrollingMenuFrame(in: pose.bounds, avoiding: pose.regions) : pose.bounds
                let panes = book.map { CGRect(x: $0.x - viewport.x, y: $0.y - viewport.y, width: $0.width, height: $0.height) }
                if book.isEmpty {
                    guard pose.regions.allSatisfy({ !viewport.intersects($0.frame) }) else { throw invalidTargets(line: #line) }
                }
                for setting in ClassicInterfaceSize.allCases {
                    let scale = page.pause != nil
                        ? MobilePauseArt.interfaceScale(setting, width: viewport.width, height: viewport.height)
                        : MobileSettingsArt.interfaceScale(setting, width: viewport.width)
                    let base = GameFrontEnd.layout(page, width: viewport.width / scale, minimumHeight: viewport.height / scale,
                        boxedHome: min(pose.bounds.width, pose.bounds.height) >= 700,
                        bookHomePanes: panes.map { $0.applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)) })
                    guard Set(base.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)),
                          page.home || footerNavigationIsValid(page, layout: base)
                    else { throw invalidTargets(line: #line) }
                    let maxOffset = max(0, base.size.height * scale - viewport.height)
                    let offsets = Set([CGFloat(-28), 0, maxOffset / 2, maxOffset, maxOffset + 28])
                    for offset in offsets.sorted() {
                        let layout = page.pause != nil ? MobilePauseArt.pinningFooter(base,
                            viewport: CGRect(x: 0, y: offset / scale, width: viewport.width / scale, height: viewport.height / scale)) : base
                        guard layout.targets.count == base.targets.count else { throw invalidTargets(line: #line) }
                        for (index, target) in layout.targets.enumerated() {
                            let original = base.targets[index]
                            // Pause pins its footer vertically. All horizontal geometry remains fixed.
                            guard target.frame.minX == original.frame.minX, target.frame.size == original.frame.size,
                                  target.frame.width * scale >= 44, target.frame.height * scale >= 44,
                                  layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil),
                                  !layout.targets.dropFirst(index + 1).contains(where: { $0.frame.intersects(target.frame) })
                            else {
                                FileHandle.standardError.write(Data("FAIL \(pose.name) \(name) \(setting) offset=\(offset) target=\(target.action.id) frame=\(target.frame)\n".utf8))
                                throw invalidTargets(line: #line)
                            }
                            let screen = target.frame.applying(CGAffineTransform(scaleX: scale, y: scale))
                                .offsetBy(dx: viewport.x, dy: viewport.y - offset).intersection(cg(viewport))
                            guard screen.isNull || pose.regions.allSatisfy({
                                let overlap = screen.intersection(cg($0.frame))
                                return overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001
                            }) else {
                                FileHandle.standardError.write(Data("Occluded: \(pose.name) \(name) \(setting) offset=\(offset) target=\(target.action.id) screen=\(screen) viewport=\(viewport)\n".utf8))
                                throw invalidTargets(line: #line)
                            }
                        }
                        scrollChecks += 1
                        if offset < 0 || offset > maxOffset { continue }
                        let size = CGSize(width: pose.bounds.maxX, height: pose.bounds.maxY)
                        let context = try bitmapContext(size: size)
                        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
                        context.saveGState(); context.clip(to: cg(viewport))
                        context.translateBy(x: viewport.x, y: viewport.y - offset); context.scaleBy(x: scale, y: scale)
                        GameFrontEnd.draw(page, layout: layout, typography: typography, preview: preview, in: context)
                        context.restoreGState()
                        for region in pose.regions {
                            context.setFillColor(CGColor(gray: 0.15, alpha: 1)); context.fill(cg(region.frame))
                        }
                        try save(context: context, to: output.appendingPathComponent("\(pose.name)-\(name)-\(setting.rawValue)-\(offset).png"))
                        captures += 1
                    }
                }
            }
        }
        print("PASS \(captures) menu captures, \(scrollChecks) scroll/bounce layouts, \(poses.count) pose/region fixtures and all interface sizes: fixed button widths, hit testing, disabled actions, target separation and cutout clearance. Windowless and muted.")
    }
}
