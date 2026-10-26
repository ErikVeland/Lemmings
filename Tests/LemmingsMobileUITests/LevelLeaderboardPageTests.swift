import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt

struct LevelLeaderboardPageTests {
    /// iPhone, iPad, Duo and Apple TV share this result page: the metric switch stays tappable and the leaders stay visible.
    @Test func resultPageShowsLevelLeaderboardAtEveryWidth() throws {
        let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = repository.appendingPathComponent(".build/level-leaderboard-pages")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [320, 390, 834, 1194, 1920] {
            var page = GameFrontEnd.Page(title: "Level complete", details: ["Just dig!", "Saved 8/10   Goal 5", "Time 0:20.00",
                "Leaders: AB, CD  0:41.00", "#1  AB  0:41.00", "#1  CD  0:41.00", "#3  EF  0:52.50"],
                footer: [.init("0", "Next level", primary: true), .init("1", "Retry"), .init("2", "Back")], preview: true)
            page.rows = [.init("levelBoardMetric", "Level leaderboard: Fastest 100%")]
            page.result = true; page.detailHeadings = [0]
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            let metric = try #require(layout.targets.first { $0.action.id == "levelBoardMetric" })
            #expect(metric.frame.height >= 44 && layout.board.contains(metric.frame))
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
}
