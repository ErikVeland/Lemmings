#if os(iOS)
import Foundation
import Testing
import UIKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor private final class PosePinch: UIPinchGestureRecognizer {
    var fixtureState: UIGestureRecognizer.State = .began
    var point = CGPoint(x: 100, y: 100)
    override var state: UIGestureRecognizer.State { get { fixtureState } set { fixtureState = newValue } }
    override func location(in view: UIView?) -> CGPoint { point }
}

@MainActor private final class PoseScroll: UIPanGestureRecognizer {
    var fixtureState: UIGestureRecognizer.State = .began
    var point = CGPoint(x: 100, y: 100)
    var delta = CGPoint(x: 20, y: 0)
    override var state: UIGestureRecognizer.State { get { fixtureState } set { fixtureState = newValue } }
    override func location(in view: UIView?) -> CGPoint { point }
    override func translation(in view: UIView?) -> CGPoint { delta }
    override func setTranslation(_ translation: CGPoint, in view: UIView?) { delta = translation }
}

@MainActor struct MobilePoseTransitionTests {
    private func playfield() -> MobilePlayfieldView {
        let view = MobilePlayfieldView(viewport: .init(levelSize: .init(width: 1600, height: 320),
            viewSize: .init(width: 400, height: 300), origin: .init(x: 500, y: 0), zoom: 2),
            automaticallyFitsViewport: false)
        view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        return view
    }

    @Test func cancelledPinchCannotMoveTheCameraAfterUnfolding() {
        let view = playfield()
        let pinch = PosePinch(target: nil, action: nil)
        pinch.scale = 1.1
        view.perform(NSSelectorFromString("handlePinch:"), with: pinch)
        #expect(view.gameViewport.zoom > 2)
        view.cancelInteraction()
        view.gameViewport.resize(.init(width: 800, height: 300))
        let unfolded = view.gameViewport
        pinch.fixtureState = .changed
        pinch.scale = 2
        view.perform(NSSelectorFromString("handlePinch:"), with: pinch)
        #expect(view.gameViewport == unfolded)
        pinch.fixtureState = .ended
        view.perform(NSSelectorFromString("handlePinch:"), with: pinch)
        pinch.fixtureState = .began
        pinch.scale = 1.1
        view.perform(NSSelectorFromString("handlePinch:"), with: pinch)
        #expect(view.gameViewport.zoom > unfolded.zoom)
    }

    @Test func cancelledScrollRequiresAFreshGestureAndAvoidsReservedRegions() {
        let view = playfield()
        var effects: [MobileTouchEffect] = []
        view.onTouchEffects = { effects += $0 }
        let scroll = PoseScroll(target: nil, action: nil)
        view.perform(NSSelectorFromString("handleScroll:"), with: scroll)
        #expect(effects == [.pan(.init(x: 20, y: 0))])
        view.cancelInteraction()
        effects.removeAll()
        scroll.fixtureState = .changed
        scroll.delta = CGPoint(x: 40, y: 0)
        view.perform(NSSelectorFromString("handleScroll:"), with: scroll)
        #expect(effects.isEmpty)
        scroll.fixtureState = .began
        view.blockedInputFrames = [CGRect(x: 90, y: 0, width: 20, height: 300)]
        scroll.delta = CGPoint(x: 40, y: 0)
        view.perform(NSSelectorFromString("handleScroll:"), with: scroll)
        #expect(effects.isEmpty)
        scroll.point = CGPoint(x: 150, y: 100)
        scroll.fixtureState = .changed
        scroll.delta = CGPoint(x: 5, y: 0)
        view.perform(NSSelectorFromString("handleScroll:"), with: scroll)
        #expect(effects == [.pan(.init(x: 5, y: 0))])
    }
}
#endif
