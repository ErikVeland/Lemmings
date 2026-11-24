import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import Testing

@MainActor struct CommunityTotalLayoutTests {
    @Test func arrivingCommunityTotalsPreserveTargets() throws {
        let output = ProcessInfo.processInfo.environment["LEMMINGS_ASYNC_RENDER_DIR"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 465, height: 700),
                     CGSize(width: 589, height: 794), CGSize(width: 834, height: 1194),
                     CGSize(width: 1920, height: 1080)] {
            var previous: [[GameFrontEnd.Target]]?
            for total in [nil, 12_345, 12_345_678_901, Int.max, nil] {
                let counter = SavedLemmingsCounter(local: 123, global: total)
                let rankings = MobileCareerArt.leaderboards(world: true, category: .stars,
                    rows: [.init("rankReplay.1", "1.  EKV")], busy: false, status: "",
                    sharing: true, gameCenter: true, worldwide: counter.homeCaption)
                let consent = MobileInformationArt.telemetryConsent(worldwide: SavedLemmingsCounter.worldwideText(total))
                let pages = [rankings, consent].map { MobileTurnArt.page($0, playerName: "UVA", role: .next) }
                let layouts = pages.map {
                    GameFrontEnd.layout($0, width: size.width, minimumHeight: size.height)
                }
                let targets = layouts.map(\.targets)
                if let previous { #expect(targets == previous) }
                previous = targets
                for (index, layout) in layouts.enumerated() {
                    if let output, size.width == 320, total == nil || total == 12_345 {
                        let context = try #require(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                        context.translateBy(x: 0, y: layout.size.height)
                        context.scaleBy(x: 1, y: -1)
                        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                        let art = try #require(GameMenuTypography(directory: repo.appendingPathComponent(".build/mac-artwork/export/lemmings")))
                        GameFrontEnd.draw(pages[index], layout: layout, typography: art, in: context)
                        let file = output.appendingPathComponent("\(index == 0 ? "community" : "consent")-\(total == nil ? "waiting" : "loaded").png")
                        let destination = try #require(CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil))
                        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
                        #expect(CGImageDestinationFinalize(destination))
                    }
                    for target in layout.targets {
                        #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                    }
                }
            }
        }
    }
}
