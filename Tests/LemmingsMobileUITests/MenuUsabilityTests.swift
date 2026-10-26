import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

struct MenuUsabilityTests {
    private func pause(replay: Bool) -> GameFrontEnd.Page {
        func tool(_ id: String, _ title: String, _ group: GameFrontEnd.Action.Group = .level) -> GameFrontEnd.Action {
            var action = GameFrontEnd.Action(id, title)
            action.group = group
            return action
        }
        let summary = MobilePauseSummary(level: .init(index: 0, rank: "Fun", number: 1, title: "Just dig!"),
            snapshot: .init(tick: 42, released: 10, total: 20, saved: 2, required: 10, remainingSeconds: 120,
                releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: []),
            activeCount: 8, ticksPerSecond: 17, speed: 1, assignedSkills: 1, supportsRewind: true,
            usedRewind: false, isReplay: replay, soundtrack: "Original", track: "A long soundtrack name", audio: "Music off")
        return MobilePauseArt.organizingActions(MobilePauseArt.page(summary, actions: [
            .init("resume", replay ? "Play" : "Resume", primary: true),
            .init("library", replay ? "Back" : "Back to library", backNavigation: true),
        ] + (replay ? [tool("previous", "Previous move", .playback), tool("next", "Next move", .playback)] : [
            tool("hint", "Hint"), tool("retry", "Restart level"), tool("skip", "Skip as ANN (12)"),
            tool("bonus", "Bonus skill ×2"), tool("inspect", "Inspect lemmings", .inspection),
            tool("ghosts", "Hot Seat ghosts", .inspection),
        ]) + [tool("help", "Controls help", .preferences), tool("settings", "Settings", .preferences)]))
    }

    @Test func pauseAndReplaySeparateNavigationToolsAndPrimaryAction() {
        for replay in [false, true] {
            let page = pause(replay: replay)
            #expect(page.footer.map(\.id) == ["resume", "library"])
            #expect(page.rows.allSatisfy { !$0.primary && !$0.isBackNavigation })
            #expect(page.rowHeadings["help"] == "Help and settings")
            #expect(page.rowHeadings[replay ? "previous" : "hint"] != nil)
            #expect(Set((page.rows + page.footer).map(\.id)).count == page.rows.count + page.footer.count)
        }
    }

    @Test func wideShortListsAndChoicesUseColumnsAndFooterRowsAreBalanced() {
        for count in 2...3 {
            let page = GameFrontEnd.Page(title: "Choose", rows: (0..<count).map { .init("row.\($0)", "Choice \($0)") })
            let layout = GameFrontEnd.layout(page, width: 1120, minimumHeight: 720)
            #expect(Set(layout.targets.map { $0.frame.minY }).count == 1)
        }
        for count in 2...20 {
            for columns in 2...4 {
                var actions = (0..<count).map { GameFrontEnd.Action("tool.\($0)", "Action") }
                actions[0] = .init("back", "Back")
                actions[count - 1] = .init("continue", "Continue", primary: true)
                let grid = GameFooterGrid(actions: actions, columns: columns)
                let counts = Dictionary(grouping: grid.slots, by: \.row).values.map(\.count)
                #expect(counts.max()! - counts.min()! <= 1)
                #expect(grid.slots.first { $0.action.id == "back" }?.row == grid.rows - 1)
                #expect(grid.slots.last?.action.id == "continue")
            }
        }
        #expect(MobileSettingsArt.skillSelectionPauseChoice().footerColumns == 2)
    }

    @Test func duoAndPlatformMatrixKeepsNavigationPrimaryActionAndTargetsUsable() throws {
        let root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/menu-usability")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var poses: [(String, MobileRect, [MobileReservedRegion])] = [
            ("phone-small", .init(x: 0, y: 0, width: 320, height: 568), []),
            ("phone", .init(x: 0, y: 0, width: 390, height: 844), []),
            ("phone-wide", .init(x: 0, y: 0, width: 844, height: 390), []),
            ("ipad", .init(x: 0, y: 0, width: 834, height: 1194), []),
            ("mac-compact", .init(x: 0, y: 0, width: 640, height: 480), []),
            ("mac-wide", .init(x: 0, y: 0, width: 1600, height: 900), []),
            ("tv", .init(x: 0, y: 0, width: 1920, height: 1080), []),
        ]
        for (name, width, height) in [("book", 1194.0, 834.0), ("book-compact", 650, 465),
                                     ("table", 834, 1194), ("table-wide", 1194, 834), ("table-compact", 465, 650)] {
            let book = name.hasPrefix("book")
            poses.append((name, .init(x: 0, y: 0, width: width, height: height), [.init(kind: .division,
                frame: book ? .init(x: width / 2 - 8, y: 0, width: 16, height: height)
                    : .init(x: 0, y: height / 2 - 8, width: width, height: 16))]))
        }
        for (name, width, height) in [("outer-wide", 720.0, 495.0), ("outer-tall", 495, 720)] {
            for corner in 0..<4 {
                poses.append(("\(name)-\(corner)", .init(x: 0, y: 0, width: width, height: height), [.init(kind: .occlusion,
                    frame: .init(x: corner % 2 == 0 ? 0 : width - 92, y: corner < 2 ? 0 : height - 80, width: 92, height: 80))]))
            }
        }
        for (name, bounds, regions) in poses {
            let safe = MobileDisplayRegions.bookPanes(in: bounds, avoiding: regions).last
                ?? MobileDisplayRegions.tablePanes(in: bounds, avoiding: regions).first
                ?? MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: regions)
            #expect(regions.allSatisfy { !safe.intersects($0.frame) })
            let tv = name == "tv"
            for size in [ClassicInterfaceSize.standard, .large, .extraLarge] {
                for replay in [false, true] {
                    let navigation = GameNavigationArt.layout(width: safe.width, actions: GameNavigationArt.actions(back: true,
                        backTitle: replay ? "Back" : "Back to library"), television: tv)
                    let home = try #require(navigation.targets.first { $0.action.id == "navigation.home" })
                    let back = try #require(navigation.targets.first { $0.action.id == "navigation.back" })
                    #expect(home.frame.maxX == safe.width - 6 && home.frame.minY == 6)
                    #expect(back.frame.minX == 6 && back.frame.minY == 6)
                    let available = safe.height - navigation.size.height
                    let scale = MobilePauseArt.interfaceScale(size, width: safe.width, height: available, television: tv)
                    var page = pause(replay: replay)
                    page.footer.removeAll { $0.isBackNavigation }
                    let body = MobilePauseArt.layout(page, width: safe.width / scale, minimumHeight: available / scale, television: tv)
                    let footerIDs = Set(page.footer.map(\.id))
                    #expect(Set(body.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)))
                    for target in body.targets {
                        #expect(target.frame.width * scale >= 44 && target.frame.height * scale >= 44)
                        #expect(target.frame.minX >= 0 && target.frame.maxX <= safe.width / scale)
                        #expect(GameTextLayout.height(target.action.title, width: target.frame.width - (target.action.primary ? 48 : 24)) + (target.action.primary ? 8 : 12) <= target.frame.height)
                    }
                    for offset in [CGFloat.zero, max(0, (body.size.height - available / scale) / 2), max(0, body.size.height - available / scale)] {
                        let viewport = CGRect(x: 0, y: offset, width: safe.width / scale, height: available / scale)
                        let pinned = MobilePauseArt.pinningFooter(body, viewport: viewport, actionIDs: footerIDs)
                        let primary = try #require(pinned.targets.first { $0.action.id == "resume" })
                        #expect(viewport.contains(primary.frame))
                        #expect(pinned.targets.filter { !footerIDs.contains($0.action.id) }.map(\.frame)
                            == body.targets.filter { !footerIDs.contains($0.action.id) }.map(\.frame))
                    }
                    // Capture the visible initial viewport, including the fixed action shelf.
                    let context = try #require(CGContext(data: nil, width: Int(safe.width), height: Int(safe.height), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.translateBy(x: 0, y: safe.height); context.scaleBy(x: 1, y: -1)
                    GameFrontEnd.draw(.init(title: ""), layout: navigation, typography: typography, in: context)
                    context.translateBy(x: 0, y: navigation.size.height); context.scaleBy(x: scale, y: scale)
                    let pinned = MobilePauseArt.pinningFooter(body, viewport: .init(x: 0, y: 0, width: safe.width / scale, height: available / scale), actionIDs: footerIDs)
                    GameFrontEnd.draw(page, layout: pinned, typography: typography, in: context)
                    let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("\(name)-\(size.rawValue)-\(replay ? "replay" : "pause").png") as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
            }
        }
    }
}
