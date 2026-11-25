import CoreGraphics
import Foundation
import ImageIO
import Testing
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

struct MobileSettingsTabsArtTests {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let artwork = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
    @Test func tabsRetainTheAvailableGroupsAndOneSelection() {
        for inGame in [false, true] {
            for television in [false, true] {
                let actions = MobileSettingsTabsArt.actions(selected: .audio, inGame: inGame, television: television)
                let order: [MobileSettingsGroup] = [.gameplay, .controller, .accessibility, .display, .graphics, .audio, .privacy, .deskClock]
                let expected = order.filter { (!inGame && !television) || $0 != .deskClock }
                #expect(actions.filter { $0.id.hasPrefix("settingsTab.") }.map(\.title) == expected.map(\.title))
                #expect(actions.filter(\.selected).map(\.id) == ["settingsTab.audio"])
                #expect(actions.contains { $0.id == "data" } == !inGame)
                #expect(Set(actions.map(\.id)).count == actions.count)
            }
        }
    }

    @Test func settingsIndexGroupsStayTogetherAndBackStaysClose() throws {
        for width: CGFloat in [280, 390, 834, 1194] {
            for television in [false, true] {
                let page = MobileSettingsArt.groups(inGame: true, television: television)
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 900)
                #expect(layout.targets.map(\.action.id) == [
                    "settingsGroup.gameplay", "settingsGroup.controller", "settingsGroup.accessibility",
                    "settingsGroup.display", "settingsGroup.graphics", "settingsGroup.audio",
                    "settingsGroup.privacy", "home"
                ])
                let frames = layout.targets.map(\.frame)
                #expect(frames[3].minY - frames[2].maxY >= 16)
                #expect(frames[6].minY - frames[5].maxY >= 16)
                #expect(frames[7].minY - frames[6].maxY <= 24)
                #expect(frames[7].width <= 220)
                #expect(Set(frames.dropLast().map(\.width)).count == 1)
                #expect(layout.board.height < layout.size.height)
                if !television {
                    let backdrop = GameMenuBackdropArt.geometry(in: CGRect(origin: .zero, size: layout.size),
                        layout: layout, scale: 1, shape: .rounded).frame
                    #expect(backdrop.minY == layout.board.minY)
                    #expect(backdrop.contains(frames.last!))
                }
                for (index, target) in layout.targets.enumerated() {
                    #expect(target.frame.width >= 44 && target.frame.height >= 44)
                    #expect(layout.board.contains(target.frame))
                    #expect(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                    #expect(frames.dropFirst(index + 1).allSatisfy { !$0.intersects(target.frame) })
                }
            }
        }
    }

    @Test func horizontalTabsKeepFullCaptionsAndDisjointTargets() {
        #expect(MobileSettingsTabsArt.usesTabs(width: 844, height: 390))
        #expect(!MobileSettingsTabsArt.usesTabs(width: 390, height: 844))
        for width: CGFloat in [320, 589, 650, 844, 1194, 1920] {
            for television in [false, true] {
                let tabs = MobileSettingsTabsArt.actions(selected: .privacy, inGame: false, television: television)
                let layout = MobileSettingsTabsArt.layout(width: width, actions: tabs, television: television)
                for (index, target) in layout.targets.enumerated() {
                    #expect(target.frame.width >= GameTextLayout.width(of: target.action.title) + 24)
                    #expect(target.frame.height >= 44)
                    #expect(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                    #expect(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)) == target.action.id)
                    #expect(layout.targets.dropFirst(index + 1).allSatisfy { !$0.frame.intersects(target.frame) })
                }
            }
        }
    }

    @Test(.enabled(if: FileManager.default.fileExists(atPath: artwork.appendingPathComponent("manifest.json").path),
        "The Macintosh artwork export is required for Settings renders."))
    func rendersHorizontalSettingsWithFixedTabsAndBottomNavigation() throws {
        let typography = try #require(GameMenuTypography(directory: Self.artwork))
        let output = Self.root.appendingPathComponent(".build/settings-tabs/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let sizes: [(CGSize, Bool)] = [(.init(width: 650, height: 425), false),
            (.init(width: 834, height: 565), false), (.init(width: 1194, height: 794), false),
            (.init(width: 960, height: 540), true)]
        for (size, television) in sizes {
            for group in MobileSettingsGroup.allCases {
                if television && group == .deskClock { continue }
                var page = MobileSettingsArt.page(group, settings: .init(), displayAvailable: true, foldable: true)
                let tabs = MobileSettingsTabsArt.actions(selected: group, inGame: false, television: television)
                let tabLayout = MobileSettingsTabsArt.layout(width: size.width, actions: tabs, television: television)
                let navigation = GameNavigationArt.layout(width: size.width, actions: GameNavigationArt.actions(back: true))
                let body = CGRect(x: 0, y: tabLayout.size.height, width: size.width,
                    height: size.height - tabLayout.size.height - navigation.size.height)
                #expect(body.height >= 44)
                page.footer.removeAll { $0.isBackNavigation }
                if television {
                    page.televisionGrid = true
                    page = TVMenuPresentation.settingsPage(page, index: 0, width: size.width, height: body.height)
                }
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: body.height)
                if television { #expect(layout.size.height == body.height) }
                let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                    bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
                context.saveGState(); context.clip(to: CGRect(x: 0, y: 0, width: size.width, height: tabLayout.size.height))
                if let selected = tabLayout.targets.first(where: { $0.action.selected }) {
                    context.translateBy(x: -max(0, min(selected.frame.minX - 6, tabLayout.size.width - size.width)), y: 0)
                }
                GameFrontEnd.draw(.init(title: "", footer: tabs), layout: tabLayout, typography: typography, in: context)
                context.restoreGState()
                context.saveGState(); context.clip(to: body); context.translateBy(x: 0, y: body.minY)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                context.restoreGState()
                context.saveGState(); context.translateBy(x: 0, y: size.height - navigation.size.height)
                GameFrontEnd.draw(.init(title: "", footer: GameNavigationArt.actions(back: true)), layout: navigation, typography: typography, in: context)
                context.restoreGState()
                let file = output.appendingPathComponent("\(Int(size.width))-\(group.rawValue).png")
                let writer = try #require(CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(writer, try #require(context.makeImage()), nil)
                #expect(CGImageDestinationFinalize(writer))
            }
        }
    }
}
