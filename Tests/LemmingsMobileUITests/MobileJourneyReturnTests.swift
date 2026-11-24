#if os(iOS) || os(tvOS)
import Foundation
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
@testable import LemmingsMobileUI

@MainActor struct MobileJourneyReturnTests {
    @Test func nestedLibraryRoutesRestoreFocusAndScrollWithoutAddingHistoryOnRefresh() throws {
        let library = MobileLibraryViewController()
        library.loadViewIfNeeded()
        library.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        library.navigate(.settingsGroup(.gameplay))
        library.view.layoutIfNeeded()
        let scroll = try #require(library.canvas.superview as? UIScrollView)
        scroll.contentOffset.y = min(200, max(0, scroll.contentSize.height - scroll.bounds.height))
        let offset = scroll.contentOffset
        let action = try #require(library.canvas.page.rows.last?.id)
        library.canvas.focusedID = action
        library.navigate(.language)
        library.navigate(.settingsGroup(.gameplay))
        #expect(scroll.contentOffset == offset)
        #expect(library.canvas.focusedID == action)
        library.navigate(.settingsGroup(.gameplay))
        #expect(scroll.contentOffset == offset)
        #expect(library.canvas.focusedID == action)
        library.navigate(.home)
        library.navigate(.settingsGroup(.gameplay))
        #expect(scroll.contentOffset == .zero)
        library.viewDidDisappear(false)
    }

    @Test func leavingAColdPackLoadKeepsTheDestinationAndAllowsRetry() async throws {
        let controller = MobileLibraryViewController()
        controller.loadViewIfNeeded()
        defer { controller.viewDidDisappear(false) }
        controller.navigate(.settings)
        controller.library = nil
        controller.navigate(.home)
        var completions = 0
        controller.openLibrary({ nil }) { _ in completions += 1 }
        controller.navigate(.support)
        #expect(!controller.loading && controller.route == .support)
        controller.openLibrary({ throw URLError(.notConnectedToInternet) }) { _ in completions += 1 }
        func waitForLoad() async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 5
            while controller.loading {
                try #require(ProcessInfo.processInfo.systemUptime < deadline)
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        try await waitForLoad()
        #expect(completions == 0 && !controller.notice.isEmpty && controller.route == .support)
        controller.openLibrary({ nil }) { _ in completions += 1 }
        try await waitForLoad()
        #expect(completions == 1 && controller.notice.isEmpty && controller.route == .support)
    }

    @Test func awardBackRestoresTheListInsteadOfTheTopOfTheDetail() throws {
        let library = MobileLibraryViewController()
        library.loadViewIfNeeded()
        library.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        library.navigate(.achievements)
        library.view.layoutIfNeeded()
        let scroll = try #require(library.canvas.superview as? UIScrollView)
        scroll.contentOffset.y = min(200, max(0, scroll.contentSize.height - scroll.bounds.height))
        let offset = scroll.contentOffset
        let action = try #require(library.canvas.page.rows.first?.id)
        library.canvas.focusedID = action
        library.handle(action)
        #expect(library.canvas.page.reading)
        library.canvas.goBack()
        #expect(library.route == .achievements)
        #expect(library.canvas.focusedID == action)
        #expect(scroll.contentOffset == offset)
        library.viewDidDisappear(false)
    }
}
#endif
