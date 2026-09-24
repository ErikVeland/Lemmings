import AppKit
import CoreGraphics

/// Arms inside the game, then keeps samples one point inside its visible edges.
struct PointerConfinement {
    private(set) var capturedBounds: CGRect?
    var isCaptured: Bool { capturedBounds != nil }

    mutating func release() { capturedBounds = nil }

    mutating func sample(_ point: CGPoint, in bounds: CGRect, active: Bool,
                         releaseRequested: Bool) -> CGPoint? {
        guard active, !releaseRequested, !bounds.isNull, !bounds.isInfinite,
              bounds.width > 2, bounds.height > 2 else { release(); return nil }
        // A moved or resized window must acquire the pointer again.
        if capturedBounds != bounds { release() }
        guard isCaptured || bounds.contains(point) else { return nil }
        capturedBounds = bounds
        return CGPoint(x: min(bounds.maxX - 1, max(bounds.minX + 1, point.x)),
                       y: min(bounds.maxY - 1, max(bounds.minY + 1, point.y)))
    }

    /// AppKit and Quartz share the primary display's top edge, with opposite Y axes.
    static func quartzPoint(_ point: CGPoint, primaryDisplayTop: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryDisplayTop - point.y)
    }
}

/// Uses absolute positions so normal clicks, dragging and system shortcuts still work.
@MainActor final class GamePointerCapture: NSObject {
    private var confinement = PointerConfinement()
    private let readPosition: () -> CGPoint
    private let warpPosition: (CGPoint) -> CGError
    var isCaptured: Bool { confinement.isCaptured && !NSEvent.modifierFlags.contains(.option) }

    init(readPosition: @escaping () -> CGPoint = { NSEvent.mouseLocation },
         warpPosition: @escaping (CGPoint) -> CGError = { point in
             // A held edge re-warps every frame. Without re-associating the
             // mouse to the cursor after each warp, macOS accumulates a
             // stale motion delta and the system cursor stops drawing
             // (input still lands correctly; only the visible arrow goes
             // missing) for as long as the edge is held, e.g. along the
             // bottom panel or during edge scrolling.
             let result = CGWarpMouseCursorPosition(point)
             CGAssociateMouseAndMouseCursorPosition(1)
             return result
         }) {
        self.readPosition = readPosition
        self.warpPosition = warpPosition
        super.init()
        for name in [NSWindow.didResignKeyNotification, NSApplication.didResignActiveNotification,
                     NSWindow.willCloseNotification, NSWindow.willStartLiveResizeNotification,
                     NSApplication.didChangeScreenParametersNotification, NSMenu.didBeginTrackingNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(reset), name: name, object: nil)
        }
    }

    @objc func reset() { confinement.release() }

    /// Returns the current point in the view even when a warp generates no mouse event.
    func update(in view: NSView, rect: CGRect? = nil, active: Bool) -> CGPoint? {
        guard active, NSApp.isActive, let window = view.window, window.isKeyWindow,
              window.isVisible, !window.isMiniaturized, !view.isHiddenOrHasHiddenAncestor,
              !view.inLiveResize, window.attachedSheet == nil,
              let screen = window.screen, let primary = NSScreen.screens.first else {
            reset(); return nil
        }
        let visible = (rect ?? view.bounds).intersection(view.visibleRect)
        let bounds = window.convertToScreen(view.convert(visible, to: nil)).intersection(screen.frame)
        let point = readPosition()
        guard let captured = confinement.sample(point, in: bounds, active: true,
                releaseRequested: NSEvent.modifierFlags.contains(.option)) else { return nil }
        if captured != point {
            let result = warpPosition(PointerConfinement.quartzPoint(captured, primaryDisplayTop: primary.frame.maxY))
            guard result == .success else { reset(); return nil }
        }
        return view.convert(window.convertPoint(fromScreen: captured), from: nil)
    }
}
