#if os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

@MainActor final class MobileTVPointerView: UIView {
    var point: CGPoint? { didSet { setNeedsDisplay() } }
    var eligible = false
    var occupied = false
    override func draw(_ rect: CGRect) {
        guard let point, let context = UIGraphicsGetCurrentContext() else { return }
        TVPlayfieldArt.drawAimPointer(at: point, eligible: eligible, occupied: occupied, context: context)
    }
}

extension MobileGameViewController {
    func ensureTVPointer() {
        guard overlay.isHidden, playState.canEdit else { tvPointerView.isHidden = true; return }
        guard !view.bounds.isEmpty, !playfieldView.bounds.isEmpty else { return }
        if tvPointerPoint == nil {
            tvPointerPoint = playfieldView.convert(CGPoint(x: playfieldView.bounds.midX, y: playfieldView.bounds.midY), to: view)
        }
        if let point = tvPointerPoint {
            let local = playfieldView.controllerInputPoint(playfieldView.convert(point, from: view))
            previewInput = .precision
            previewPoint = playfieldView.bounds.contains(local) ? .init(x: local.x, y: local.y) : nil
            if previewPoint == nil { highlightedTarget = nil; tvTargetLock.clear() }
        }
    }

    func moveTVPointer(dx: Double, dy: Double) {
        guard overlay.isHidden, playState.canEdit, dx.isFinite, dy.isFinite,
              dx != 0 || dy != 0 else { return }
        ensureTVPointer()
        guard let point = tvPointerPoint else { return }
        tvTargetLock.clear()
        tvPointerPoint = CGPoint(x: min(view.bounds.maxX - 2, max(2, point.x + dx)),
                                 y: min(view.bounds.maxY - 2, max(2, point.y + dy)))
        ensureTVPointer()
        highlightedTarget = previewPoint.flatMap(target)
        renderCurrentFrame(force: true)
        updateTVPointer()
    }

    func updateTVPointer() {
        tvPointerView.frame = view.bounds
        tvPointerView.isHidden = !overlay.isHidden || !playState.canEdit || isChoosingToolDirection
        tvPointerView.point = tvPointerPoint
        let control = tvPointerPoint.flatMap { hud.pointerAction(at: hud.convert($0, from: view)) }
        tvPointerView.eligible = control != nil || highlightedTarget?.state == .eligible
        tvPointerView.occupied = control != nil || highlightedTarget != nil
        view.bringSubviewToFront(tvPointerView)
    }

    @discardableResult func activateTVPointerControl() -> Bool {
        guard let point = tvPointerPoint, !hud.isHidden,
              let action = hud.pointerAction(at: hud.convert(point, from: view)) else { return false }
        handle(action)
        updateTVPointer()
        return true
    }
}
#endif
