import CoreGraphics
import Foundation
import ImageIO
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import Testing

struct CatalogueReviewTests {
    private let packs = [
        [MobileLevelSummary(index: 0, rank: "Fun", number: 1, title: "Over", packName: "River"),
         .init(index: 1, rank: "Fun", number: 2, title: "Under", packName: "River"),
         .init(index: 2, rank: "Mayhem", number: 3, title: "Beyond", packName: "River")],
        [.init(index: 3, rank: "Fun", number: 1, title: "Over", packName: "Forest"),
         .init(index: 4, rank: "Fun", number: 2, title: "Finale", packName: "Forest")]
    ]

    @Test func orderSearchProgressEmptyResetAndTargets() throws {
        func page(_ query: String, _ filter: CatalogueProgressFilter) -> GameFrontEnd.Page {
            CatalogueLevelArt.page(title: "NeoLemmix", packs: packs, cleared: [0, 3], unavailable: [4],
                query: query, filter: filter, editing: false, pageIndex: 0, status: "")
        }
        let all = page("", .all), cleared = page("over", .cleared), empty = page("over", .incomplete)
        #expect(all.rows.map(\.id) == [1, 2, 0, 4, 3].map { "catalogue.level.\($0)" })
        #expect(all.rows.first { $0.id == "catalogue.level.4" }?.enabled == false)
        #expect(cleared.rows.map(\.id) == ["catalogue.level.0", "catalogue.level.3"])
        #expect(empty.rows.isEmpty && empty.details == [L10n.text("No matching levels")])
        #expect(empty.listTools.contains { $0.id == "catalogueReset" && $0.enabled })
        #expect(empty.backAction?.id == "catalogueBack")
        #expect(page("  MAYHEM  ", .all).rows.map(\.id) == ["catalogue.level.2"])
        #expect(page("forest", .incomplete).rows.map(\.id) == ["catalogue.level.4"])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/catalogue-review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (device, width, height, scale) in [("phone", 375.0, 667.0, 1.0), ("ipad", 834, 1100, 1),
                                               ("duo", 465, 700, 1), ("tv", 1920, 1080, 2)] {
            for (state, original) in [("all", all), ("cleared", cleared), ("empty", empty)] {
                let shelf = GameListToolsArt.layout(width: width, actions: original.listTools, scale: scale)
                var page = original
                page.listTools = []
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: height - shelf.size.height)
                for target in shelf.targets + layout.targets {
                    #expect(target.frame.width >= 44 && target.frame.height >= 44)
                }
                for target in layout.targets where target.action.enabled {
                    #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                }
                let totalHeight = ceil(shelf.size.height + layout.size.height)
                let context = try #require(CGContext(data: nil, width: Int(width), height: Int(totalHeight), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: totalHeight)
                context.scaleBy(x: 1, y: -1)
                GameListToolsArt.draw(shelf, typography: typography, scale: scale, in: context)
                context.translateBy(x: 0, y: shelf.size.height)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                let url = output.appendingPathComponent(device + "-" + state + ".png")
                let writer = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(writer, try #require(context.makeImage()), nil)
                #expect(CGImageDestinationFinalize(writer))
            }
        }
    }

    @Test func reopenedProfilesCountRecordedAttemptsAndDistinctClears() throws {
        var records = ArcadeRecords()
        let player = records.activeProfileID
        let guest = try #require(records.addProfile(initials: "TWO", portrait: 1)?.id)
        let first = ArcadeLevel(id: "one", title: "One", game: "Classic", rules: "A", total: 5, required: 2)
        let conditions = TrolleyConditions(gameID: "neolemmix", packID: "forest", levelID: "fun/1",
            levelFingerprint: "original", rulesetVersion: "A", physicsMode: "A", population: 5, rescueRequirement: 2,
            startingSkills: [:], timeLimitSeconds: nil)
        let second = ArcadeLevel(id: "two", title: "One", game: "NeoLemmix", rules: "A", total: 5, required: 2, conditions: conditions)
        for (owner, level, win, assisted) in [(player, first, true, false), (player, first, true, false),
                                               (player, second, false, false), (player, second, true, true),
                                               (guest, second, true, false)] {
            let run = ArcadeRun(profileID: owner, level: level, saved: win ? 3 : 0, didWin: win,
                                skills: [:], seconds: 5, assisted: assisted)
            #expect(records.record(run) != nil)
        }
        let reopened = try JSONDecoder().decode(ArcadeRecords.self, from: JSONEncoder().encode(records))
        #expect(reopened.clearedNeoLemmixLevels(profileID: player) == [.init(engine: .neolemmix, packID: "forest", levelID: "fun/1")])
        #expect(reopened.clearedNeoLemmixLevels(profileID: "unknown").isEmpty)
        let stats = MobileCareerArt.profileStatisticsPage(records: reopened, profileID: player, name: "ONE")
        #expect(stats.backAction?.id == "records" && stats.subtitle == "ONE")
        let label = stats.details
        let hub = MobileCareerArt.progressPage(records: reopened, profileID: player, profileName: "ONE", subtitle: "")
        #expect(hub.rows.contains { $0.id == "profileStatistics" && $0.enabled })
        #expect(label.contains(L10n.text("Recorded attempts: \(4)")))
        #expect(label.contains(L10n.text("Levels cleared: \(2)")))
        #expect(MobileCareerArt.profileStatistics(records: reopened, profileID: guest).contains(L10n.text("Recorded attempts: \(1)")))
    }
}
