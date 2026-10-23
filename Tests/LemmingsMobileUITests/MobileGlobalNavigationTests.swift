#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
@testable import LemmingsMobileUI

@MainActor struct MobileGlobalNavigationTests {
    @Test func globalDestinationsStayReachableOutsideLongPages() throws {
        for width: CGFloat in [320, 390, 844, 1024, 1920] {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 700))
            let navigation = MobileNavigationView()
            navigation.secondaryTitle = L10n.text("Pause menu")
            navigation.frame = CGRect(x: 0, y: 0, width: width, height: navigation.shelfHeight)
            let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: navigation.shelfHeight,
                width: width, height: 700 - navigation.shelfHeight))
            let canvas = MobileMenuCanvas()
            canvas.globalNavigation = navigation
            canvas.page = .init(title: "Gameplay", rows: (0..<6001).map { .init("pack.\($0)", "Pack \($0)") },
                footer: [.init("back", "Back")])
            navigation.frame.size.height = navigation.height(for: width)
            scroll.frame = CGRect(x: 0, y: navigation.frame.maxY, width: width, height: 700 - navigation.frame.maxY)
            scroll.addSubview(canvas)
            host.addSubview(scroll)
            host.addSubview(navigation)
            canvas.frame = CGRect(origin: .zero, size: canvas.size(width: width, minimumHeight: scroll.bounds.height))
            scroll.contentSize = canvas.bounds.size
            navigation.layoutIfNeeded()
            let targets = navigation.subviews.compactMap { $0 as? UIControl }
            #expect(targets.count == 3)
            var home = 0, pause = 0
            navigation.onHome = { home += 1 }
            navigation.onSecondary = { pause += 1 }
            let frames = targets.map(\.frame)
            let end = max(0, scroll.contentSize.height - scroll.bounds.height)
            for offset in [CGFloat(0), end / 2, end] {
                scroll.contentOffset.y = offset
                host.layoutIfNeeded()
                #expect(targets.map(\.frame) == frames)
                for target in targets {
                    #expect(target.frame.height >= 44 && target.frame.width >= 44)
                    let point = target.convert(CGPoint(x: target.bounds.midX, y: target.bounds.midY), to: host)
                    #expect(host.hitTest(point, with: nil) === target)
                }
            }
            var backs = 0
            navigation.onBack = { backs += 1 }
            canvas.focusAction("navigation.back")
            canvas.activateFocused()
            #expect(backs == 1)
            canvas.focusAction("navigation.home")
            canvas.activateFocused()
            canvas.moveFocus(1)
            canvas.activateFocused()
            #expect(home == 1 && pause == 1)
            navigation.isUserInteractionEnabled = false
            navigation.activate("navigation.home")
            #expect(home == 1)
        }
    }

    @Test func searchAndListActionsHaveSeparateFixedTargetsAndControllerFocus() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let tools = MobileListToolsView()
        tools.actions = [.init("search", "Search"), .init("shuffleAll", "Shuffle all"), .init("fanUpdate", "Check for new packs")]
        tools.frame = CGRect(x: 0, y: 56, width: 390, height: 0)
        tools.frame.size.height = tools.shelfHeight
        host.addSubview(tools)
        tools.layoutIfNeeded()
        let search = tools.subviews.first { $0.accessibilityIdentifier == "listTools.search" }
        #expect(search?.accessibilityTraits.contains(.searchField) == true)
        #expect(search?.accessibilityTraits.contains(.button) == false)
        var selected: String?
        tools.onAction = { selected = $0 }
        let canvas = MobileMenuCanvas()
        canvas.listTools = tools
        canvas.page = .init(title: "Fan Lemmings", rows: [.init("pack.1", "A collection")])
        canvas.focusAction("search")
        canvas.activateFocused()
        #expect(selected == "search")
        #expect(canvas.page.rows.allSatisfy { $0.id.hasPrefix("pack.") })
    }

    @Test func mainMenuSavesTheReadyAttemptWithoutStartingOrPassingTheTurn() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let runtime = try Lemmings3Runtime(configuration: .init(width: 128, height: 64,
            attributes: [UInt16](repeating: 0, count: 8192), entrance: .init(x: 20, y: 20),
            exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 20, releaseDelay: 0))
        let session = Lemmings3MobileSession(runtime: runtime, engineFingerprint: "fixture", levelIdentifier: "fixture",
            levelIndex: 0, levelFingerprint: "fixture", renderer: { _, _ in
                try MobilePixelFrame(width: 128, height: 64, rgba: Data(repeating: 0, count: 32768))
            })
        let store = MobileCheckpointStore(url: root.appendingPathComponent("current.json"))
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Tribe", number: 1, title: "Fixture"),
            session: session, checkpointStore: store, restoredCheckpoint: nil, settingsProfileID: "global-navigation-test")
        defer { game.viewDidDisappear(false) }
        game.loadViewIfNeeded()
        var exit: MobileGameExitAction?
        var handovers = 0
        game.onExit = { exit = $0 }
        game.onHandover = { _ in handovers += 1; return true }
        game.leaveToMainMenu()
        for _ in 0..<200 where exit == nil { try await Task.sleep(for: .milliseconds(5)) }
        #expect(exit == .menu)
        #expect(game.playState.phase == .ready && session.snapshot.tick == 0 && handovers == 0)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("current.json").path))
    }
}
#endif
