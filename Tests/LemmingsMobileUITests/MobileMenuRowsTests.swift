import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import LemmingsMobileCore

struct MobileMenuRowsTests {
    private func filledRows(_ targets: [GameFrontEnd.Target], left: CGFloat, right: CGFloat) {
        for row in Dictionary(grouping: targets, by: { $0.frame.minY }).values {
            let ordered = row.sorted { $0.frame.minX < $1.frame.minX }
            #expect(abs(ordered.first!.frame.minX - left) < 0.01)
            #expect(abs(ordered.last!.frame.maxX - right) < 0.01)
            for (a, b) in zip(ordered, ordered.dropFirst()) {
                #expect(b.frame.minX - a.frame.maxX > 0)
                #expect(b.frame.minX - a.frame.maxX <= 12.01)
                #expect(abs(a.frame.width - b.frame.width) < 0.01)
            }
        }
    }

    @Test func mainMenuStaysAtTopRightWithBackSecondaryAndLongCaptions() {
        for width: CGFloat in [280, 320, 390, 568, 834, 1194, 1920] {
            for back in [false, true] {
                for secondary in [nil, "Settings", "Pause menu"] as [String?] {
                    for backTitle in ["Back", "Cancel solution reveal"] {
                        let layout = GameNavigationArt.layout(width: width,
                            actions: GameNavigationArt.actions(back: back, backTitle: backTitle, secondary: secondary))
                        let home = layout.targets.first { $0.action.id == "navigation.home" }!
                        #expect(home.frame.minY == 6 && abs(home.frame.maxX - (width - 6)) < 0.01)
                        filledRows(layout.targets, left: 6, right: width - 6)
                        for target in layout.targets {
                            #expect(target.frame.width >= 44 && target.frame.height >= 44)
                            #expect(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                        }
                    }
                }
            }
        }
    }

    @Test func genericResultPauseAndHomeRowsNeverReserveEmptySlots() {
        for width: CGFloat in [280, 320, 390, 568, 834, 1194] {
            for count in 1...13 {
                var actions = (0..<count).map { GameFrontEnd.Action("tool.\($0)", "Tool \($0)", enabled: $0 != 2) }
                if count > 1 { actions[0] = .init("back", "Back") }
                actions[count - 1] = .init("continue", "Continue", primary: true)
                for columns in 1...4 {
                    let page = GameFrontEnd.Page(title: "Settings", footer: actions, footerColumns: columns)
                    let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
                    filledRows(layout.targets, left: layout.board.minX + 20, right: layout.board.maxX - 20)
                }
                var result = GameFrontEnd.Page(title: "Level ended", footer: actions, preview: true)
                result.result = true
                let layout = GameFrontEnd.layout(result, width: width, minimumHeight: 700)
                filledRows(layout.targets, left: layout.board.minX + 20, right: layout.board.maxX - 20)
                let pause = GameFrontEnd.layout(pausePage(actions), width: width, minimumHeight: 700)
                filledRows(pause.targets, left: pause.board.minX + 16, right: pause.board.maxX - 16)
                let home = GameFrontEnd.Page(title: "Home", home: true, rows: actions, footer: actions)
                let homeLayout = GameFrontEnd.layout(home, width: width, minimumHeight: 400)
                filledRows(homeLayout.targets, left: homeLayout.board.minX + 12, right: homeLayout.board.maxX - 12)
            }
        }
    }

    @Test func carouselActionsFillEveryRowAndStayLargeEnoughToTap() {
        for width: CGFloat in [280, 320, 390, 568, 834, 1194] {
            for count in [4, 6] {
                let layout = LevelBrowserGeometry(safe: .init(x: 0, y: 0, width: width, height: 568), actionCount: count)
                for row in Dictionary(grouping: layout.actions, by: \.minY).values {
                    #expect(row.map(\.minX).min() == layout.board.minX + 16)
                    #expect(abs(row.map(\.maxX).max()! - (layout.board.maxX - 16)) < 0.01)
                    #expect(row.allSatisfy { $0.width >= 44 && $0.height == 44 })
                }
                #expect(layout.actions[0].minX == layout.board.minX + 16)
                #expect(layout.actions.last!.maxX == layout.board.maxX - 16)
                if layout.actions[0].width == layout.board.width - 32 {
                    #expect(layout.actions[0].minY < layout.actions.last!.minY)
                } else { #expect(layout.actions[0].minY == layout.actions.last!.minY) }
            }
        }
    }

    private func pausePage(_ actions: [GameFrontEnd.Action]) -> GameFrontEnd.Page {
        MobilePauseArt.page(.init(level: .init(index: 0, rank: "Fun", number: 1, title: "Just dig!"),
            snapshot: .init(tick: 42, released: 10, total: 20, saved: 2, required: 10, remainingSeconds: 120,
                releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: []),
            activeCount: 8, ticksPerSecond: 17, speed: 1, assignedSkills: 1, supportsRewind: true,
            usedRewind: false, isReplay: false, soundtrack: "Original", track: nil, audio: "Music off"), actions: actions)
    }

    @Test func renderCommonScreensWithFilledRowsAndPinnedMainMenu() throws {
        let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = repository.appendingPathComponent(".build/ios-menu-rows")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [320, 390, 834, 1194] {
            for count in [0, 1] {
                let actions: [GameFrontEnd.Action] = [.init("library", "Library"), .init("hint", "Hint"),
                    .init("restart", "Restart level"), .init("controls", "Controls help"), .init("settings", "Settings"),
                    .init("skip", "Skip level (\(count))", enabled: count > 0), .init("resume", "Resume", primary: true)]
                var result = GameFrontEnd.Page(title: "Level ended", details: ["2 saved / 10 required"],
                    footer: [.init("back", "Back"), actions[5], .init("retry", "Retry", primary: true)], preview: true)
                result.result = true
                for (name, page) in [("pause", pausePage(actions)), ("result", result),
                    ("settings", MobileSettingsArt.groups()),
                    ("collections", GameFrontEnd.Page(title: "Collections", rows: Array(actions.prefix(5)), footer: [.init("back", "Back")]))] {
                    let navigation = GameNavigationArt.layout(width: width, actions: GameNavigationArt.actions(back: true))
                    let body = GameFrontEnd.layout(page, width: width, minimumHeight: 700 - navigation.size.height)
                    let height = body.size.height + navigation.size.height
                    let context = try #require(CGContext(data: nil, width: Int(width), height: Int(ceil(height)), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.translateBy(x: 0, y: height); context.scaleBy(x: 1, y: -1)
                    GameFrontEnd.draw(.init(title: ""), layout: navigation, typography: typography, in: context)
                    context.translateBy(x: 0, y: navigation.size.height)
                    GameFrontEnd.draw(page, layout: body, typography: typography, in: context)
                    let image = try #require(context.makeImage())
                    let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("\(name)-\(Int(width))-\(count).png") as CFURL, "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
            }
        }
    }
}
