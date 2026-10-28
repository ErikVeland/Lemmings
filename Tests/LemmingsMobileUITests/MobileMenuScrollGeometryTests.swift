#if os(iOS)
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
@testable import LemmingsMobileUI

@MainActor private final class PoseTrackingButton: UIButton {
    var cancellations = 0
    override func cancelTracking(with event: UIEvent?) {
        cancellations += 1
        super.cancelTracking(with: event)
    }
}

@MainActor struct MobileMenuScrollGeometryTests {
    @Test func columnReflowKeepsTheVisibleItemAndItsInputTarget() throws {
        let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let canvas = MobileMenuCanvas()
        canvas.page = .init(title: "Collections", rows: (0..<80).map { .init("item.\($0)", "Collection \($0)") })
        scroll.addSubview(canvas)
        func layout(width: CGFloat) {
            scroll.setViewportFrame(CGRect(x: 0, y: 0, width: width, height: 600))
            canvas.frame = CGRect(origin: .zero, size: canvas.size(width: width, minimumHeight: 600))
            scroll.contentSize = canvas.bounds.size
            canvas.setNeedsLayout()
            canvas.layoutIfNeeded()
        }
        layout(width: 390)
        let selected = try #require(canvas.subviews.first { $0.accessibilityIdentifier == "menu.item.24" })
        scroll.contentOffset.y = selected.frame.minY
        canvas.focusAction("item.24")
        for width: CGFloat in [834, 1120, 390] {
            layout(width: width)
            #expect(canvas.focusedID == "item.24")
            #expect(abs(scroll.contentOffset.y - selected.frame.minY) < 1)
            let point = selected.convert(CGPoint(x: selected.bounds.midX, y: selected.bounds.midY), to: canvas)
            #expect(canvas.hitTest(point, with: nil) === selected)
        }
    }

    @Test func pauseFooterRemainsInTheSafeAreaWhileTheFullScreenScrolls() throws {
        let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.unobscuredInsets = UIEdgeInsets(top: 120, left: 0, bottom: 34, right: 0)
        let canvas = MobileMenuCanvas()
        let summary = MobilePauseSummary(level: .init(index: 0, rank: "Fun", number: 1, title: "Just dig!"),
            snapshot: .init(tick: 42, released: 10, total: 20, saved: 2, required: 10, remainingSeconds: 120,
                releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: []),
            activeCount: 8, ticksPerSecond: 17, speed: 1, assignedSkills: 1, supportsRewind: true,
            usedRewind: false, isReplay: false, soundtrack: "Original", track: "Track", audio: "Music off")
        canvas.page = MobilePauseArt.organizingActions(MobilePauseArt.page(summary, actions: [
            .init("resume", "Resume", primary: true),
            .init("library", "Back to library", backNavigation: true),
            .init("hint", "Hint"), .init("retry", "Restart level")
        ]))
        scroll.addSubview(canvas)
        let size = canvas.size(width: 390, minimumHeight: 690)
        canvas.frame = CGRect(x: 0, y: 120, width: size.width, height: size.height)
        scroll.contentSize = CGSize(width: 390, height: 120 + size.height + 34)
        let end = max(0, scroll.contentSize.height - scroll.bounds.height)
        for offset in [CGFloat(0), end / 2, end] {
            scroll.contentOffset.y = offset
            canvas.setNeedsLayout()
            canvas.layoutIfNeeded()
            let button = try #require(canvas.subviews.first { $0.accessibilityIdentifier == "menu.resume" })
            let visible = button.convert(button.bounds, to: scroll).offsetBy(dx: 0, dy: -offset)
            #expect(visible.minY >= 120 && visible.maxY <= 810)
            let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: canvas)
            #expect(canvas.hitTest(point, with: nil) === button)
        }
    }

    @Test func staticHeadingKeepsNavigationTargetsBelowTheTitle() throws {
        let navigation = MobileNavigationView()
        navigation.showsBack = true
        let width: CGFloat = 390
        let originalHeight = navigation.height(for: width)
        navigation.headingTitle = "Settings"
        let height = navigation.height(for: width)
        #expect(height == originalHeight + 48)
        navigation.frame = CGRect(x: 0, y: 0, width: width, height: height)
        navigation.layoutIfNeeded()
        let heading = try #require(navigation.subviews.compactMap { $0 as? MobilePixelLabel }.first)
        #expect(heading.text == "Settings" && heading.frame.maxY == 48)
        let buttons = navigation.subviews.compactMap { $0 as? MobilePixelButton }
        #expect(!buttons.isEmpty)
        for button in buttons {
            #expect(button.frame.minY >= heading.frame.maxY)
            let point = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: navigation)
            #expect(navigation.hitTest(point, with: nil) === button)
        }
        navigation.headingTitle = nil
        #expect(navigation.height(for: width) == originalHeight)
    }

    @Test func movingTheViewportCancelsOldMenuTrackingOnlyWhenGeometryChanges() {
        let scroll = MobileMenuScrollView(frame: CGRect(x: 0, y: 0, width: 495, height: 720))
        let canvas = UIView(frame: scroll.bounds)
        let button = PoseTrackingButton(frame: CGRect(x: 20, y: 20, width: 120, height: 48))
        scroll.addSubview(canvas)
        canvas.addSubview(button)
        button.isHighlighted = true
        scroll.setViewportFrame(scroll.frame)
        #expect(button.cancellations == 0 && button.isHighlighted)
        scroll.setViewportFrame(CGRect(x: 0, y: 80, width: 720, height: 415))
        #expect(button.cancellations == 1 && !button.isHighlighted)
        #expect(scroll.panGestureRecognizer.isEnabled)
    }

    @Test func menuTargetsKeepTheirWidthsThroughScrollAndBounceInEveryCameraCorner() throws {
        for size in [CGSize(width: 495, height: 720), .init(width: 720, height: 495)] {
            let bounds = MobileRect(x: 0, y: 0, width: size.width, height: size.height)
            for leading in [false, true] {
                for top in [false, true] {
                    let camera = MobileReservedRegion(kind: .occlusion,
                        frame: .init(x: leading ? 0 : size.width - 92, y: top ? 0 : size.height - 80,
                                     width: 92, height: 80))
                    let viewport = MobileDisplayRegions.scrollingMenuFrame(in: bounds, avoiding: [camera])
                    let host = UIView(frame: CGRect(origin: .zero, size: size))
                    let scroll = MobileMenuScrollView(frame: CGRect(x: viewport.x, y: viewport.y,
                        width: viewport.width, height: viewport.height))
                    scroll.contentInsetAdjustmentBehavior = .never
                    let canvas = MobileMenuCanvas()
                    canvas.page = .init(title: "Menu", rows: (0..<18).map { .init("row.\($0)", "Action \($0)") },
                        footer: [.init("back", "Back"), .init("ready", "Ready", primary: true)])
                    host.addSubview(scroll)
                    scroll.addSubview(canvas)
                    let content = canvas.size(width: viewport.width, minimumHeight: viewport.height)
                    canvas.frame = CGRect(origin: .zero, size: content)
                    scroll.contentSize = content
                    canvas.layoutIfNeeded()
                    let buttons = canvas.subviews.compactMap { $0 as? UIButton }
                    #expect(buttons.count == 20)
                    let original = buttons.map(\.frame)
                    let end = max(0, content.height - viewport.height)
                    for offset in [-28, 0, end / 2, end, end + 28] {
                        scroll.contentOffset.y = offset
                        canvas.setNeedsLayout()
                        canvas.layoutIfNeeded()
                        #expect(buttons.map(\.frame) == original)
                        for button in buttons {
                            let midpoint = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
                            #expect(canvas.hitTest(button.convert(midpoint, to: canvas), with: nil) === button)
                            #expect(button.accessibilityLabel?.isEmpty == false)
                            let visible = button.convert(button.bounds, to: host).intersection(scroll.frame)
                            let obstacle = CGRect(x: camera.frame.x, y: camera.frame.y,
                                width: camera.frame.width, height: camera.frame.height)
                            let overlap = visible.intersection(obstacle)
                            #expect(overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001)
                        }
                    }
                }
            }
        }
    }
}
#endif
