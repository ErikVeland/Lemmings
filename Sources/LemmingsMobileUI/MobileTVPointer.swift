#if os(tvOS)
import LemmingsGameArt
import LemmingsMobileCore
import UIKit

@MainActor final class MobileTVPointerView: UIView {
    var point: CGPoint? { didSet { setNeedsDisplay() } }
    var eligible = false
    var occupied = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        // This full-screen overlay must preserve the playfield and HUD beneath it.
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func draw(_ rect: CGRect) {
        guard let point, let context = UIGraphicsGetCurrentContext() else { return }
        TVPlayfieldArt.drawAimPointer(at: point, eligible: eligible, occupied: occupied, context: context)
    }
}

extension MobileGameViewController {
    func advanceTVPointerScrolling(seconds: Double) {
        guard overlay.isHidden, playState.canEdit, lifecycle.isForeground, !lifecycle.isInterrupted,
              !isChoosingToolDirection, let point = tvPointerPoint else { return }
        guard hud.pointerAction(at: hud.convert(point, from: view)) == nil else { return }
        let local = playfieldView.convert(point, from: view)
        guard !playfieldView.blockedInputFrames.contains(where: { $0.contains(local) }) else { return }
        // Keep scrolling through the TV safe-area border, above and beside the playfield.
        // The area below the playfield belongs to the HUD.
        guard local.y <= playfieldView.bounds.maxY else { return }
        let edgePoint = MobilePoint(
            x: min(playfieldView.bounds.maxX, max(playfieldView.bounds.minX, local.x)),
            y: max(playfieldView.bounds.minY, local.y))
        var viewport = playfieldView.gameViewport
        guard viewport.scrollAtEdge(edgePoint, seconds: seconds) else { return }
        playfieldView.stopAutomaticFitting()
        tvTargetLock.clear(); highlightedTarget = nil
        playfieldView.gameViewport = viewport
        ensureTVPointer()
        renderCurrentFrame(force: true, presentationOnly: true)
    }

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
        let displayed = highlightedTarget
        tvPointerPoint = CGPoint(x: min(view.bounds.maxX - 2, max(2, point.x + dx)),
                                 y: min(view.bounds.maxY - 2, max(2, point.y + dy)))
        ensureTVPointer()
        if let previewPoint, gameSettings.classic.lemmingSelectionStyle == .modern, !fanMode {
            highlightedTarget = tvTargetLock.aim(at: previewPoint, movement: .init(x: dx, y: dy),
                displayed: displayed, candidates: session.targetCandidates(for: selectedControl),
                viewport: playfieldView.gameViewport, granular: true)
        } else { tvTargetLock.clear(); highlightedTarget = previewPoint == nil ? nil : displayed }
        renderCurrentFrame(force: true, presentationOnly: true)
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
