#if os(iOS)
import Testing
import UIKit
import LemmingsGameArt
import LemmingsMobileCore
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
