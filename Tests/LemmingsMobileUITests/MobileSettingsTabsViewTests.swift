#if os(iOS) || os(tvOS)
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileSettingsTabsViewTests {
    @Test func tabsAndBottomNavigationStayFixedWhileSettingsScroll() throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        let tabs = MobileSettingsTabsView()
        tabs.tabs = MobileSettingsTabsArt.actions(selected: .audio, inGame: true)
        tabs.isHidden = false
        tabs.frame = CGRect(x: 0, y: 0, width: 844, height: tabs.height(for: 844))
        let navigation = MobileNavigationView()
        navigation.showsBack = true
        navigation.frame = CGRect(x: 0, y: 390 - navigation.height(for: 844), width: 844, height: navigation.height(for: 844))
        let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: tabs.frame.maxY, width: 844,
            height: navigation.frame.minY - tabs.frame.maxY))
        let canvas = MobileMenuCanvas()
        canvas.globalNavigation = navigation
        canvas.settingsTabs = tabs
        canvas.usesBottomSettingsNavigation = true
        canvas.page = MobileSettingsArt.page(.audio, settings: .init(), inGame: true)
        scroll.addSubview(canvas)
        host.addSubview(scroll); host.addSubview(tabs); host.addSubview(navigation)
        canvas.frame = CGRect(origin: .zero, size: canvas.size(width: scroll.bounds.width, minimumHeight: scroll.bounds.height))
        scroll.contentSize = canvas.bounds.size
        host.layoutIfNeeded()
        let frames = (tabs.frame, navigation.frame)
        for offset in [CGFloat.zero, max(0, scroll.contentSize.height - scroll.bounds.height)] {
            scroll.contentOffset.y = offset
            host.layoutIfNeeded()
            #expect(tabs.frame == frames.0 && navigation.frame == frames.1)
            #expect(!tabs.frame.intersects(scroll.frame) && !navigation.frame.intersects(scroll.frame))
            #expect(canvas.subviews.allSatisfy { $0.accessibilityIdentifier != "menu.settings" })
        }
        var chosen: String?
        tabs.onAction = { chosen = $0 }
        canvas.focusAction("settingsTab.privacy")
        canvas.activateFocused()
        #expect(chosen == "settingsTab.privacy")
        host.layoutIfNeeded()
        let tabScroll = try #require(tabs.subviews.first as? UIScrollView)
        let privacy = try #require(tabScroll.subviews.first { $0.accessibilityIdentifier == "settingsTab.privacy" })
        let frame = privacy.convert(privacy.bounds, to: host)
        #expect(tabs.frame.contains(frame))
        #expect(host.hitTest(.init(x: frame.midX, y: frame.midY), with: nil) === privacy)
        tabs.isUserInteractionEnabled = false
        tabs.activate("settingsTab.audio")
        #expect(chosen == "settingsTab.privacy")
    }
}
#endif
