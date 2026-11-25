#if os(iOS) || os(tvOS)
import Foundation
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import Testing
import UIKit
@testable import LemmingsMobileUI

@MainActor struct MobileDestinationBackTests {
    private final class MenuLibrary: MobileGameLibrary {
        let displayName = "Menu fixture"
        let levels = [MobileLevelSummary(index: 0, rank: "Fun", number: 1, title: "Just dig!")]
        func loadLevel(at index: Int) throws -> MobileLevelContent { throw MobileSessionError.changedLevel }
    }

    @Test func libraryRoutesBuildNamedPagesWithDistinctActions() throws {
        let storage = try AppStorage.temporary(named: "LibraryRouteReview")
        defer { storage.removeTemporaryFiles() }
        let controller = MobileLibraryViewController()
        controller.arcadeStore = ArcadeStore(storage: storage, bundledProofs: nil)
        controller.loadViewIfNeeded()
        defer { controller.viewDidDisappear(false) }
        controller.loading = false
        controller.library = MenuLibrary()
        let owner = controller.profiles.activeID
        let created = controller.playlists.create(name: "Menu fixture")
        let playlist = try #require(created)
        let routes: [MobileLibraryViewController.Route] = [
            .home, .play, .support, .fanGroup([]), .levelCatalogue, .levels, .levelDetails,
            .settings, .language, .controllerMappings, .playInsights, .soundtrack, .data,
            .firstPlayer, .whatsNew, .effectsWelcome, .telemetryConsent, .insightsToken,
            .insightsClear, .familiarNames, .journey, .progression, .techniques, .rankings,
            .collections, .shortGames, .l2Practice, .playlists, .playlist(playlist), .addToPlaylist,
            .players, .cloudSaves, .shuffleAll, .hotSeat, .hotSeats, .progress, .profileStatistics,
            .progressPlayer(owner), .progressLevel("fixture", owner), .records, .achievements,
            .recordLevel("fixture"), .recordHint("fixture")
        ] + MobileFamily.allCases.map { .family($0) } + MobileSettingsGroup.allCases.map { .settingsGroup($0) }
        for route in routes {
            controller.route = route
            controller.rebuild()
            let page = controller.canvas.page
            let actions = page.rows + page.footer
            #expect(controller.route == route)
            #expect(!page.title.isEmpty)
            let hasAction = actions.contains { $0.enabled }
            #expect(hasAction)
            #expect(Set(actions.map(\.id)).count == actions.count)
            #expect(Set(page.listTools.map(\.id)).count == page.listTools.count)
        }
    }

    @Test func accessibilityFocusSurvivesAMenuReflowAndRefresh() throws {
        let narrow: CGFloat = 465
        #if os(tvOS)
        let wide: CGFloat = 1920
        let height: CGFloat = 560
        #else
        let wide: CGFloat = 834
        let height: CGFloat = 360
        #endif
        let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: 0, width: narrow, height: height))
        scroll.contentInsetAdjustmentBehavior = .never
        let canvas = MobileMenuCanvas()
        scroll.addSubview(canvas)
        canvas.page = .init(title: "Profile", rows: (0..<24).map { index in
            .init("row.\(index)", "Player \(index)", primary: index == 0)
        })
        var activations: [String] = []
        canvas.onAction = { activations.append($0) }

        func layout(width: CGFloat) {
            let size = canvas.size(width: width, minimumHeight: height)
            scroll.frame.size.width = width
            scroll.contentSize = size
            canvas.frame = CGRect(origin: .zero, size: size)
            canvas.layoutIfNeeded()
        }

        layout(width: narrow)
        let button = try #require(canvas.subviews.compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "menu.row.12"
        })
        #expect(canvas.focusedID == "row.0")
        button.accessibilityElementDidBecomeFocused()
        #expect(canvas.focusedID == "row.12")
        #expect(activations.isEmpty)

        let revealedOffset = button.frame.minY - scroll.contentOffset.y
        #expect(revealedOffset >= 0 && revealedOffset + button.frame.height <= height)
        scroll.setContentOffset(CGPoint(x: 0, y: button.frame.midY - height / 2), animated: false)
        let offset = button.frame.minY - scroll.contentOffset.y
        for width in [wide, narrow, wide] {
            let oldFrame = button.frame
            layout(width: width)
            #expect(button.frame != oldFrame)
            #expect(abs(button.frame.minY - scroll.contentOffset.y - offset) < 1)
            #expect(canvas.focusedID == "row.12")
        }

        canvas.page.subtitle = "Updated records"
        layout(width: wide)
        let target = CGPoint(x: button.frame.midX, y: button.frame.midY)
        #expect(canvas.hitTest(target, with: nil) === button)
        #expect(canvas.focusedID == "row.12")
        #expect(activations.isEmpty)

        canvas.page.rows[12].enabled = false
        layout(width: wide)
        button.accessibilityElementDidBecomeFocused()
        #expect(canvas.focusedID == "row.0")
        #expect(activations.isEmpty)
    }

    @Test func backRestoresTheActivatedHomeDestination() throws {
        let controller = MobileLibraryViewController()
        controller.loadViewIfNeeded()
        defer { controller.viewDidDisappear(false) }
        controller.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        controller.navigate(.home)

        let destinations: [(String, MobileLibraryViewController.Route)] = [
            ("play", .play), ("profile", .progress), ("worldwide", .rankings), ("settings", .settings)
        ]
        for (id, route) in destinations {
            controller.view.layoutIfNeeded()
            let button = try #require(controller.canvas.subviews.compactMap { $0 as? UIButton }.first {
                $0.accessibilityIdentifier == "menu." + id
            })
            #expect(button.isEnabled && button.accessibilityLabel?.isEmpty == false)
            button.sendActions(for: .gameActivation)
            #expect(controller.route == route)
            #expect(controller.canvas.page.backAction?.isBackNavigation == true)
            controller.goBack()
            #expect(controller.route == .home)
            #expect(controller.canvas.focusedID == id)
        }
    }

    @Test func backFromNewHotSeatReturnsToSavedSessionsThenHome() throws {
        let controller = MobileLibraryViewController()
        controller.loadViewIfNeeded()
        defer { controller.viewDidDisappear(false) }
        controller.profiles = MobileProfiles()
        var profiles = controller.profiles
        let added = profiles.add(name: "UVA")
        let guestID = try #require(added)
        controller.profiles = profiles
        controller.hotSeats = MobileHotSeatStore()
        let saved = try #require(MobileHotSeat(host: profiles.activeID, players: [guestID], id: "saved"))
        controller.hotSeats.importCloudSessions([saved])
        controller.navigate(.home)
        controller.canvas.focusAction("hotSeat")
        controller.canvas.activateFocused()
        #expect(controller.route == .hotSeats)
        controller.canvas.focusAction("seatFresh")
        controller.canvas.activateFocused()
        #expect(controller.route == .hotSeat)
        controller.goBack()
        #expect(controller.route == .hotSeats)
        #expect(controller.canvas.focusedID == "seatFresh")
        controller.goBack()
        #expect(controller.route == .home)
        #expect(controller.canvas.focusedID == "hotSeat")
        #expect(controller.hotSeats.current == nil && controller.hotSeats.savedSessions.map(\.id) == ["saved"])
    }
}
#endif
