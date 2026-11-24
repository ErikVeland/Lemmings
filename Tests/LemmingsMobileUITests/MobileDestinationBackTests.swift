#if os(iOS) || os(tvOS)
import Foundation
import LemmingsMobileCore
import NxlvKit
import Testing
import UIKit
@testable import LemmingsMobileUI

@MainActor struct MobileDestinationBackTests {
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
