import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import NxlvKit

struct GlobalNavigationArtTests {
    @Test func fanEntriesNeverContainListToolsAndNavigationFitsEveryViewport() throws {
        let packs = (0..<6001).map { FanLevelOrganisation.Pack(id: "pack\($0)", title: "Collection \($0)") }
        let root = FanLevelOrganisation.library(packs)
        let filtered = FanLevelLibraryArt.page(root: root, path: [], query: "Collection", editing: true)
        #expect(filtered.listTools.contains { $0.id == "searchClear" })
        #expect(!filtered.rows.contains { $0.id == "search" || $0.id == "searchClear" })
        let repository = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = repository.appendingPathComponent(".build/global-navigation-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let typography = GameMenuTypography(directory: repository.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        for empty in [false, true] {
            let tree = empty ? FanLevelOrganisation.library(packs, query: "No matching collection") : root
            let page = FanLevelLibraryArt.page(root: tree, path: [])
            #expect(page.rows.count <= 10)
            #expect(page.rows.allSatisfy { $0.id.hasPrefix("pack.") || $0.id.hasPrefix("fanGroup.") })
            #expect(page.footer.allSatisfy { $0.isBackNavigation })
            #expect(page.listTools.map(\.id) == ["search", "shuffleAll", "fanUpdate"])
            for width: CGFloat in [280, 320, 390, 760, 834, 1920] {
                let actions = GameNavigationArt.actions(back: true)
                let navigation = GameNavigationArt.layout(width: width, actions: actions, television: width == 1920)
                let scale: CGFloat = width == 1920 ? 2 : 1
                let tools = GameListToolsArt.layout(width: width, actions: page.listTools, scale: scale)
                for layout in [navigation, tools] {
                    let bounds = CGRect(origin: .zero, size: layout.size)
                    for target in layout.targets {
                        #expect(bounds.contains(target.frame))
                        #expect(target.frame.width >= 44 && target.frame.height >= 44)
                        #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil))
                        for other in layout.targets where target.action.id != other.action.id {
                            #expect(!target.frame.intersects(other.frame))
                        }
                    }
                }
                guard let typography else { continue }
                let height: CGFloat = width == 1920 ? 1080 : 700
                let context = try #require(CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: height)
                context.scaleBy(x: 1, y: -1)
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                // The production navigation uses the same stone buttons and bitmap lettering.
                GameFrontEnd.draw(.init(title: "", footer: actions), layout: navigation, typography: typography, in: context)
                context.translateBy(x: 0, y: navigation.size.height)
                GameListToolsArt.draw(tools, typography: typography, scale: scale, in: context)
                context.translateBy(x: 0, y: tools.size.height)
                let bodyHeight = height - navigation.size.height - tools.size.height
                var bodyPage = page
                bodyPage.footer = []
                let body = GameFrontEnd.layout(bodyPage, width: width, minimumHeight: bodyHeight)
                GameFrontEnd.draw(bodyPage, layout: body, typography: typography, in: context)
                let image = try #require(context.makeImage())
                let url = output.appendingPathComponent("fan-\(Int(width))-\(empty ? "empty" : "populated").png")
                let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
        }
    }
}
