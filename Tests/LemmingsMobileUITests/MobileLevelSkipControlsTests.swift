#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import NxlvKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

private final class SkipFixtureSession: MobileGameSession {
    let engineIdentifier: String
    let engineFingerprint = "skip-fixture"
    let levelIdentifier = "skip-fixture"
    let levelIndex = 0
    let levelFingerprint = "skip-fixture"
    let levelSize = MobileSize(width: 320, height: 160)
    let ticksPerSecond = 17.0
    var complete = false
    var won = false
    var snapshot: MobileGameSnapshot {
        .init(tick: 1, released: 5, total: 10, saved: won ? 5 : 0, required: 5, remainingSeconds: 100,
            releaseRate: nil, isComplete: complete, didWin: won, isEndingRun: false, skills: [])
    }
    init(_ engine: String) { engineIdentifier = engine }
    func tick() {}
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    func assign(control: Int, to target: Int) -> Bool { false }
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func checkpointPayload() throws -> Data { Data() }
    func restoreCheckpointPayload(_ data: Data) throws {}
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try .init(width: 320, height: 160, rgba: Data(repeating: 0, count: 320 * 160 * 4))
    }
}

@MainActor @Suite(.serialized) struct MobileLevelSkipControlsTests {
    private func withGame(engine: String, turn: MobileGameTurn? = nil,
                          _ body: @MainActor (MobileGameViewController, SkipFixtureSession) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let session = SkipFixtureSession(engine)
        let game = MobileGameViewController(summary: .init(index: 0, rank: "Fun", number: 1, title: "Fixture"),
            session: session, checkpointStore: .init(url: root.appendingPathComponent("current.json")),
            restoredCheckpoint: nil, turn: turn, settingsProfileID: "skip-fixture")
        game.loadViewIfNeeded()
        game.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        game.view.layoutIfNeeded()
        defer { game.viewDidDisappear(false); try? FileManager.default.removeItem(at: root) }
        try await body(game, session)
    }
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func pauseAndFailedResultsShowLiveBalancesAcrossAllEngines() async throws {
        for engine in ["classic-dos", "lemmings2", "lemmings3"] {
            try await withGame(engine: engine) { game, session in
                var balance = 0, charges = 0
                var exit: MobileGameExitAction?
                game.onSkipBalance = { balance }
                game.onSkipLevel = { balance -= 1; charges += 1; return true }
                game.onExit = { exit = $0 }
                game.resumePlay(); game.pausePlay(showControls: true)
                let zero = try #require((game.overlayCanvas.page.rows + game.overlayCanvas.page.footer).first { $0.title == "Skip level (0)" })
                #expect(!zero.enabled)
                game.performLevelSkip()
                #expect(charges == 0 && exit == nil && game.paused)
                balance = 1
                game.pausePlay(showControls: true)
                #expect((game.overlayCanvas.page.rows + game.overlayCanvas.page.footer).contains { $0.title == "Skip level (1)" && $0.enabled })
                session.complete = true
                game.pausePlay(showControls: true)
                #expect(game.overlayCanvas.page.result)
                #expect((game.overlayCanvas.page.rows + game.overlayCanvas.page.footer).contains { $0.title == "Skip level (1)" && $0.enabled })
                game.performLevelSkip(); game.performLevelSkip()
                try await wait { exit != nil }
                #expect(exit == .next && charges == 1 && balance == 0)
                #expect(game.session.snapshot.tick == 1)
            }
        }
    }

    @Test func pauseSkipsPassTheAttemptOwnersTurnOnceUnderBothRules() async throws {
        for policy in [MobileHotSeat.TurnPolicy.everyLevel, .atFirstFail] {
            let seat = try #require(MobileHotSeat(host: "owner", players: ["guest"], policy: policy))
            let turn = MobileGameTurn(scope: seat.scope, owner: "owner", ownerName: "ANN", ownerPortrait: 0,
                choices: { won in seat.choices(didWin: won).map { ("Choice", $0) } })
            try await withGame(engine: "lemmings3", turn: turn) { game, _ in
                var balance = 1, charges = 0, handovers: [String] = []
                var exit: MobileGameExitAction?
                game.onSkipBalance = { balance }
                game.onSkipLevel = { balance -= 1; charges += 1; return true }
                game.onHandover = { handovers.append($0); return true }
                game.onExit = { exit = $0 }
                game.resumePlay(); game.pausePlay(showControls: true)
                #expect((game.overlayCanvas.page.rows + game.overlayCanvas.page.footer).contains { $0.title == "Skip as ANN (1)" })
                game.performLevelSkip(); game.performLevelSkip()
                try await wait { exit != nil }
                #expect(exit == .next && charges == 1 && balance == 0 && handovers == ["guest"])
                #expect(game.paused && game.session.snapshot.tick == 1)
            }
        }
    }

    @Test func failedHandoverRefundsBeforeRetryAndKeepsGameplayPaused() async throws {
        let seat = try #require(MobileHotSeat(host: "owner", players: ["guest"]))
        let turn = MobileGameTurn(scope: seat.scope, owner: "owner", ownerName: "ANN", ownerPortrait: 0,
            choices: { won in seat.choices(didWin: won).map { ("Choice", $0) } })
        try await withGame(engine: "lemmings3", turn: turn) { game, _ in
            var balance = 1, refunds = 0, charges = 0
            var exit: MobileGameExitAction?
            game.onSkipBalance = { balance }
            game.onSkipLevel = { balance -= 1; charges += 1; return true }
            game.onRefundSkip = { balance += 1; refunds += 1; return true }
            game.onHandover = { _ in false }
            game.onExit = { exit = $0 }
            game.resumePlay(); game.pausePlay(showControls: true)
            game.performLevelSkip()
            try await wait { refunds == 1 }
            #expect(balance == 1 && charges == 1 && exit == nil && game.paused)
            #expect(game.canSpendLevelSkip)
        }
    }

    @Test func mainMenuTargetStaysAtTheTopRightWhileMenusReflowAndScroll() async throws {
        try await withGame(engine: "lemmings3") { game, _ in
            for size in [CGSize(width: 320, height: 568), .init(width: 844, height: 390), .init(width: 834, height: 1194)] {
                game.view.frame.size = size
                game.showCustomOverlay(title: "Settings", details: Array(repeating: "A setting", count: 80), actions: [("Back", {})])
                game.view.layoutIfNeeded(); game.layoutOverlay(); game.globalNavigation.layoutIfNeeded()
                let home = try #require(game.globalNavigation.subviews.first { $0.accessibilityIdentifier == "navigation.home" })
                #expect(abs(home.frame.maxX - (game.globalNavigation.bounds.width - 6)) < 0.01 && home.frame.minY == 6)
                game.overlay.contentOffset.y = max(0, game.overlay.contentSize.height - game.overlay.bounds.height)
                #expect(game.globalNavigation.hitTest(CGPoint(x: home.frame.midX, y: home.frame.midY), with: nil) === home)
                #expect(!game.globalNavigation.isHidden && game.view.bounds.contains(game.globalNavigation.frame))
            }
        }
    }
    @Test func groupedPauseKeepsOneReturnAndRevealsEveryToolAboveThePinnedAction() async throws {
        for engine in ["classic-dos", "lemmings2", "lemmings3"] {
            try await withGame(engine: engine) { game, _ in
                game.onSkipBalance = { 1 }; game.onSkipLevel = { true }
                game.resumePlay()
                for size in [CGSize(width: 320, height: 465), .init(width: 390, height: 844),
                             .init(width: 720, height: 415), .init(width: 589, height: 834),
                             .init(width: 1194, height: 405), .init(width: 1194, height: 834)] {
                    game.view.frame.size = size
                    game.pausePlay(showControls: true)
                    game.layoutOverlay(); game.overlayCanvas.layoutIfNeeded()
                    let page = game.overlayCanvas.page
                    #expect(page.footer.count == 2 && page.rows.contains { $0.title.hasPrefix("Skip") })
                    #expect(page.rows.contains { $0.group == .preferences })
                    #expect(page.rows.allSatisfy { !$0.primary && !$0.isBackNavigation })
                    let buttons = game.overlayCanvas.subviews.compactMap { $0 as? UIButton }
                    #expect(!buttons.contains { $0.accessibilityIdentifier == "menu.1" })
                    let resume = try #require(buttons.first { $0.accessibilityIdentifier == "menu.0" })
                    let original = resume.convert(resume.bounds, to: game.view)
                    for action in page.rows where action.enabled {
                        game.overlayCanvas.focusAction(action.id)
                        game.overlayCanvas.layoutIfNeeded()
                        let button = try #require(buttons.first { $0.accessibilityIdentifier == "menu." + action.id })
                        let frame = button.convert(button.bounds, to: game.view)
                        let primary = resume.convert(resume.bounds, to: game.view)
                        #expect(frame.maxY <= primary.minY - 8)
                        #expect(abs(primary.minY - original.minY) < 0.1)
                        #expect(game.overlayCanvas.hitTest(CGPoint(x: button.frame.midX, y: button.frame.midY), with: nil) === button)
                    }
                    let music = try #require((game.overlayCanvas.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
                        .first { $0.accessibilityLabel?.hasPrefix("Soundtrack:") == true })
                    music.accessibilityElementDidBecomeFocused()
                    game.overlayCanvas.layoutIfNeeded()
                    let musicFrame = game.overlayCanvas.convert(music.accessibilityFrameInContainerSpace, to: game.view)
                    #expect(musicFrame.maxY <= resume.convert(resume.bounds, to: game.view).minY - 8)
                    if engine == "classic-dos" {
                        game.overlay.setContentOffset(.zero, animated: false)
                        game.overlayCanvas.setNeedsLayout(); game.overlayCanvas.layoutIfNeeded()
                        game.overlay.layer.removeAllAnimations(); game.overlay.alpha = 1
                        let output = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
                            .deletingLastPathComponent().appendingPathComponent(".build/menu-usability-native")
                        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                        let image = UIGraphicsImageRenderer(bounds: game.view.bounds).image { game.view.layer.render(in: $0.cgContext) }
                        try #require(image.pngData()).write(to: output.appendingPathComponent("pause-\(Int(size.width))-\(Int(size.height)).png"))
                    }
                    game.overlay.setContentOffset(CGPoint(x: 0, y: max(0, game.overlay.contentSize.height - game.overlay.bounds.height)), animated: false)
                    game.overlayCanvas.setNeedsLayout(); game.overlayCanvas.layoutIfNeeded()
                    let final = resume.convert(resume.bounds, to: game.view)
                    #expect(abs(final.minY - original.minY) < 0.1)
                    #expect(game.overlayCanvas.hitTest(CGPoint(x: resume.frame.midX, y: resume.frame.midY), with: nil) === resume)
                }
            }
        }
    }

    @Test func levelBrowserRowsFillTheViewportAndRetainEveryInputTarget() throws {
        let host = UIViewController()
        host.loadViewIfNeeded()
        let browser = MobileLevelBrowserView()
        host.view.addSubview(browser)
        browser.artworkLoadingEnabled = false
        browser.configure(levels: [.init(index: 0, rank: "Fun", number: 1, title: "Just dig!"),
            .init(index: 1, rank: "Tricky", number: 1, title: "This should be a doddle!")], selected: 0)
        for size in [CGSize(width: 320, height: 568), .init(width: 390, height: 844),
                     .init(width: 844, height: 390), .init(width: 1194, height: 834)] {
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            browser.frame = host.view.bounds
            browser.setNeedsLayout(); browser.layoutIfNeeded()
            let buttons = browser.subviews.compactMap { $0 as? MobilePixelButton }.filter { !$0.isHidden }
            #expect(buttons.count == (size.height >= 430 ? 6 : 4))
            for row in Dictionary(grouping: buttons, by: { $0.frame.minY }).values {
                #expect(row.map { $0.frame.minX }.min() == 24)
                #expect(abs(row.map { $0.frame.maxX }.max()! - (size.width - 24)) < 0.01)
            }
            for button in buttons {
                #expect(button.frame.width >= 44 && button.frame.height == 44)
                if button.icon == nil { #expect(GameTextLayout.width(of: button.title) <= button.frame.width - 24) }
                #expect(browser.hitTest(CGPoint(x: button.frame.midX, y: button.frame.midY), with: nil) === button)
            }
            let back = try #require(buttons.first { $0.title == "BACK" })
            let play = try #require(buttons.first { $0.title == "PLAY" })
            #expect(back.frame.minY == play.frame.minY && back.frame.minX < play.frame.minX)
        }
    }

    @Test func browserUsesTheHeaderReturnAndKeepsRankActionsTogether() {
        let host = UIViewController(); host.loadViewIfNeeded()
        let browser = MobileLevelBrowserView(); browser.artworkLoadingEnabled = false
        host.view.addSubview(browser)
        browser.showsBack = false
        browser.configure(levels: [.init(index: 0, rank: "Fun", number: 1, title: "Just dig!"),
            .init(index: 1, rank: "Tricky", number: 1, title: "A new level")], selected: 0)
        for size in [CGSize(width: 320, height: 568), .init(width: 390, height: 844), .init(width: 1194, height: 834)] {
            host.view.frame.size = size; browser.frame = host.view.bounds
            browser.setNeedsLayout(); browser.layoutIfNeeded()
            let buttons = browser.subviews.compactMap { $0 as? MobilePixelButton }.filter { !$0.isHidden }
            #expect(buttons.count == 5 && !buttons.contains { $0.title == "BACK" })
            let rank = buttons.filter { $0.title.contains("RANK") }
            #expect(rank.count == 2 && rank[0].frame.minY == rank[1].frame.minY)
            for button in buttons {
                #expect(browser.hitTest(CGPoint(x: button.frame.midX, y: button.frame.midY), with: nil) === button)
            }
        }
    }

    @Test func resultMainMenuUsesOnlyTheHeaderAndPreservesTheHouseRule() async throws {
        for policy in [MobileHotSeat.TurnPolicy.everyLevel, .atFirstFail] {
            for won in [false, true] {
                let seat = try #require(MobileHotSeat(host: "owner", players: ["guest"], policy: policy))
                let turn = MobileGameTurn(scope: seat.scope, owner: "owner", ownerName: "ANN", ownerPortrait: 0,
                    choices: { won in seat.choices(didWin: won).map { ("Choice", $0) } })
                try await withGame(engine: "lemmings3", turn: turn) { game, session in
                    var exit: MobileGameExitAction?, handovers: [String] = []
                    game.onExit = { exit = $0 }
                    game.onHandover = { handovers.append($0); return true }
                    session.complete = true; session.won = won
                    game.pausePlay(showControls: true)
                    #expect(game.overlayCanvas.page.result)
                    #expect(!game.overlayCanvas.page.footer.contains { $0.title.uppercased() == "MENU" })
                    game.globalNavigation.activate("navigation.home")
                    try await wait { exit != nil }
                    #expect(exit == .menu)
                    #expect(handovers == [won && policy == .atFirstFail ? "owner" : "guest"])
                    #expect(game.paused && game.session.snapshot.tick == 1)
                }
            }
        }
    }

    @Test func foldedMenusKeepMainMenuOnTheOuterTopRightClearOfTheHinge() {
        for vertical in [false, true] {
            let bounds = MobileRect(x: 0, y: 0, width: vertical ? 1194 : 834, height: vertical ? 834 : 1194)
            let division = MobileReservedRegion(kind: .division, frame: vertical
                ? .init(x: 589, y: 0, width: 16, height: 834)
                : .init(x: 0, y: 589, width: 834, height: 16))
            let viewport = MobileSystemRegions.menuFrame(in: bounds, avoiding: [division])
            #expect(viewport.minY == 0 && viewport.maxX == bounds.maxX)
            #expect(!viewport.intersects(division.frame))
            let layout = GameNavigationArt.layout(width: viewport.width, actions: GameNavigationArt.actions(back: true))
            let home = layout.targets.first { $0.action.id == "navigation.home" }!
            #expect(viewport.minX + home.frame.maxX == bounds.maxX - 6)
        }
    }

}
#endif
