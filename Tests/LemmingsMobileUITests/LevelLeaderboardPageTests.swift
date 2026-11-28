import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt

struct LevelLeaderboardPageTests {
    @Test func resultDetailsShowTheSelectedMetricAtEveryWidth() throws {
        let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = repository.appendingPathComponent(".build/level-leaderboard-pages")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [320, 390, 834, 1194, 1920] {
            let footer = [GameFrontEnd.Action("0", "Back"), .init("1", "Records")]
            let empty = MobileCareerArt.resultDetails(footer: footer, board: nil)
            #expect(empty.rows.isEmpty && empty.details.isEmpty)
            let lines = ["Leaders: AB, CD  0:41.00", "#1  AB  0:41.00", "#1  CD  0:41.00", "#3  EF  0:52.50"]
            let page = MobileCareerArt.resultDetails(footer: footer, board: ("Fastest 100%", lines))
            #expect(page.details == lines && page.footer.map(\.id) == ["0", "1"])
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            let metric = try #require(layout.targets.first { $0.action.id == "levelBoardMetric" })
            #expect(metric.frame.height >= 44 && layout.board.contains(metric.frame))
            #expect(layout.action(at: CGPoint(x: metric.frame.midX, y: metric.frame.midY)) == "levelBoardMetric")
            #expect(layout.details.count == page.details.count)
            let context = try #require(CGContext(data: nil, width: Int(width), height: Int(ceil(layout.size.height)), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
            let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent("result-\(Int(width)).png") as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }
    @Test func rosterToolsWrapAndRemainIndividuallySelectable() throws {
        let tools = (1...8).map { GameFrontEnd.Action("player\($0)", "Player \($0)", selected: $0 == 4) }
        for width: CGFloat in [280, 390, 834, 1920] {
            let layout = GameListToolsArt.layout(width: width, actions: tools)
            #expect(layout.targets.map(\.action.id) == tools.map(\.id))
            #expect(layout.targets.filter(\.action.selected).map(\.action.id) == ["player4"])
            for target in layout.targets {
                #expect(target.frame.width >= 44 && target.frame.height >= 44)
                #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
            }
        }
    }

}
