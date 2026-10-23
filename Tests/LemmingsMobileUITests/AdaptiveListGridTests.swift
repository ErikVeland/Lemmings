import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt

struct AdaptiveListGridTests {
    private func actions(_ count: Int) -> [GameFrontEnd.Action] {
        (0..<count).map { .init("item.\($0)", "Collection \($0 + 1)", enabled: $0 != 4) }
    }

    @Test func longListsUseAvailableColumnsWithoutAnOptIn() {
        let page = GameFrontEnd.Page(title: "Records", rows: actions(25), footer: [.init("back", "Back")])
        for (width, columns): (CGFloat, Int) in [(320, 1), (390, 1), (760, 2), (834, 2), (1120, 3), (1920, 3)] {
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
            let entries = layout.targets.filter { $0.action.id.hasPrefix("item.") }
            let first = entries[0].frame.minY
            #expect(entries.filter { $0.frame.minY == first }.count == columns)
            #expect(entries.map { $0.action.id } == page.rows.map(\.id))
            for entry in entries {
                #expect(entry.frame.width >= 44 && entry.frame.height >= 44)
                #expect(layout.action(at: CGPoint(x: entry.frame.midX, y: entry.frame.midY)) == (entry.action.enabled ? entry.action.id : nil))
                for other in entries where entry.action.id != other.action.id { #expect(!entry.frame.intersects(other.frame)) }
            }
            #expect(entries.last?.frame.width == layout.board.width - 40)
        }
        var steps = page
        steps.singleColumnRows = true
        let linear = GameFrontEnd.layout(steps, width: 1120, minimumHeight: 700)
        #expect(Set(linear.targets.filter { $0.action.id.hasPrefix("item.") }.map { $0.frame.minX }).count == 1)
    }

    @Test func groupBoundariesAndLongLabelsDoNotWasteEveryRow() {
        var entries = actions(18)
        entries[0].title = String(repeating: "A longer collection title with full words ", count: 5)
        let grid = GameListGrid(actions: entries, width: 992,
            rowHeadings: ["item.0": "Classic", "item.5": "Lemmings 2", "item.11": "Lemmings 3"])
        #expect(grid.columns == 3)
        #expect(grid.headings.map(\.0) == ["Classic", "Lemmings 2", "Lemmings 3"])
        #expect(grid.targets[0].frame.height > grid.targets[8].frame.height)
        for boundary in [5, 11] {
            #expect(grid.targets[boundary].frame.minX == 0)
            #expect(grid.targets[boundary - 1].frame.maxY < grid.targets[boundary].frame.minY)
        }
        for target in grid.targets {
            #expect(GameTextLayout.height(target.action.title, width: target.frame.width - 48) + 12 <= target.frame.height)
        }
        let longest = grid.targets.map { $0.frame.height }.max() ?? 0
        #expect(grid.height < CGFloat(grid.rows.count) * longest)
    }

    @Test func tvPaginationUsesTheSameColumnsAndKeepsEveryAction() {
        var source = GameFrontEnd.Page(title: "Choose a collection", rows: actions(57), footer: [.init("back", "Back")])
        source.televisionGrid = true
        source.rowHeadings = ["item.0": "Classic", "item.17": "Lemmings 2", "item.39": "Lemmings 3"]
        for size in [CGSize(width: 960, height: 496), .init(width: 640, height: 360)] {
            var restored: [String] = []
            for index in 0..<100 {
                let page = TVMenuPresentation.settingsPage(source, index: index, width: size.width, height: size.height)
                let layout = TVMenuPresentation.settingsLayout(page, width: size.width, height: size.height)
                #expect(layout.size.height <= size.height)
                restored += page.rows.map(\.id)
                if !page.footer.contains(where: { $0.id == TVMenuPresentation.nextID && $0.enabled }) { break }
            }
            #expect(restored == source.rows.map(\.id))
        }
    }

    @Test func rendersResponsiveListsWithFixedNavigation() throws {
        let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try #require(GameMenuTypography(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = repository.appendingPathComponent(".build/list-reflow-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var page = GameFrontEnd.Page(title: "Collections", rows: actions(23))
        page.rows[6].title = "A long collection title that must wrap without losing its name"
        page.rowHeadings = ["item.0": "Classic", "item.8": "Lemmings 2", "item.15": "Lemmings 3"]
        for size in [CGSize(width: 390, height: 760), .init(width: 760, height: 390),
                     .init(width: 834, height: 1110), .init(width: 1120, height: 720), .init(width: 1920, height: 1080)] {
            let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
            let navigation = GameNavigationArt.actions(back: true)
            let shelf = GameNavigationArt.layout(width: size.width, actions: navigation)
            GameFrontEnd.draw(.init(title: "", footer: navigation), layout: shelf, typography: typography, in: context)
            context.translateBy(x: 0, y: shelf.size.height)
            let body = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height - shelf.size.height)
            GameFrontEnd.draw(page, layout: body, typography: typography, in: context)
            let image = try #require(context.makeImage())
            let path = output.appendingPathComponent("list-\(Int(size.width)).png")
            let destination = try #require(CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))
        }
    }
}
