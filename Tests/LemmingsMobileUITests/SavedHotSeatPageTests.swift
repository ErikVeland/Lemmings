import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

struct SavedHotSeatPageTests {
    @Test func previousSyncedRostersHaveDistinctVisibleResumeTargets() throws {
        var profiles = MobileProfiles()
        let addedHost = profiles.add(name: "EKV")
        let addedGuest = profiles.add(name: "UVA")
        let host = try #require(addedHost)
        let guest = try #require(addedGuest)
        profiles.select(MobileProfiles.defaultID)
        var store = MobileHotSeatStore()
        store.importCloudSessions([
            try #require(MobileHotSeat(host: host, players: [guest], id: "previous", savedAt: Date(timeIntervalSince1970: 1_700_000_000))),
            try #require(MobileHotSeat(host: host, players: [guest], id: "recent", savedAt: Date(timeIntervalSince1970: 1_710_000_000)))
        ])
        let page = MobileCareerArt.savedHotSeats(profiles, sessions: store.savedSessions, subtitle: "", backID: "players")
        #expect(page.rows.map(\.id) == ["seatResume.recent", "seatResume.previous"])
        #expect(page.rows.allSatisfy { $0.title.hasPrefix("EKV + UVA\n") && $0.enabled })
        #expect(page.rows[0].title != page.rows[1].title)
        #expect(page.footer.first?.id == "players" && page.footer.first?.isBackNavigation == true)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/saved-hot-seats/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, width, height) in [("phone", 320.0, 568.0), ("duo-outer", 465, 700),
                                       ("duo-pane", 589, 794), ("ipad", 834, 1194), ("tv", 1920, 1080)] {
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: height)
            #expect(Set(layout.targets.map { $0.action.id }) == Set((page.rows + page.footer).map(\.id)))
            for target in layout.targets {
                #expect(target.frame.width >= 44 && target.frame.height >= 44)
                #expect(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
            }
            let context = try #require(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
            let destination = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL,
                "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }
}
