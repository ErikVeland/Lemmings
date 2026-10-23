import Foundation

public enum MobileTouchEffect: Equatable, Sendable {
    case preview(MobilePoint)
    case movePreview(MobilePoint)
    case commit(MobilePoint)
    case pan(MobilePoint)
    case holdSelection(MobilePoint)
    case browseSelection(Int)
    case panHoldingSelection(MobilePoint)
    case commitSelection
    case cancelPreview
}

public struct MobileTouchRouter: Sendable {
    private struct ActiveTouch: Sendable {
        let id: Int
        let beganAt: Double
        let start: MobilePoint
        var current: MobilePoint
        var isPanning: Bool
        let allowsPanning: Bool
        let allowsHolding: Bool
        var isHolding = false
        var browseOffset = 0.0
        var edgeDirection = 0
        var nextEdgeBrowseAt = 0.0
    }

    private struct CameraTouch: Sendable {
        let id: Int
        var current: MobilePoint
    }

    public var movementThreshold: Double
    public var maximumTapDuration: Double
    public var holdDuration: Double = 0.35
    public var browseStep: Double = 24
    private var active: ActiveTouch?
    private var camera: CameraTouch?
    private var rejectingTouchesUntilReset = false
    public var isHoldingSelection: Bool { active?.isHolding == true }

    public init(movementThreshold: Double = 10, maximumTapDuration: Double = .infinity) {
        self.movementThreshold = max(1, movementThreshold)
        self.maximumTapDuration = max(0.1, maximumTapDuration)
    }

    public mutating func began(id: Int, at point: MobilePoint, time: Double, allowsPanning: Bool = true,
                               allowsHolding: Bool = false) -> [MobileTouchEffect] {
        guard !rejectingTouchesUntilReset else { return [] }
        if let active, active.isHolding, active.id != id, camera == nil, allowsPanning {
            camera = CameraTouch(id: id, current: point)
            return []
        }
        guard active == nil else { return cancelForMultiTouch() }
        active = ActiveTouch(id: id, beganAt: time, start: point, current: point,
                             isPanning: false, allowsPanning: allowsPanning, allowsHolding: allowsHolding)
        return [.preview(point)]
    }

    /// Called by the display clock, including while the finger is stationary.
    public mutating func advance(at time: Double, horizontalRange: ClosedRange<Double>? = nil) -> [MobileTouchEffect] {
        guard var touch = active, touch.allowsHolding, !touch.isPanning else { return [] }
        if !touch.isHolding {
            guard time - touch.beganAt >= holdDuration else { return [] }
            touch.isHolding = true
            active = touch
            return [.holdSelection(touch.current)]
        }
        guard let horizontalRange else { return [] }
        let edge = min(24, (horizontalRange.upperBound - horizontalRange.lowerBound) / 4)
        let direction = touch.current.x <= horizontalRange.lowerBound + edge ? -1
            : touch.current.x >= horizontalRange.upperBound - edge ? 1 : 0
        var effects: [MobileTouchEffect] = []
        if direction != touch.edgeDirection {
            touch.edgeDirection = direction
            touch.nextEdgeBrowseAt = time + 0.35
        } else if direction != 0, time >= touch.nextEdgeBrowseAt {
            // Continue through dense crowds without lifting the selection finger.
            touch.nextEdgeBrowseAt = time + 0.14
            effects = [.browseSelection(direction)]
        }
        active = touch
        return effects
    }

    public mutating func moved(id: Int, to point: MobilePoint, time: Double? = nil) -> [MobileTouchEffect] {
        if var camera, camera.id == id {
            let delta = MobilePoint(x: point.x - camera.current.x, y: point.y - camera.current.y)
            camera.current = point
            self.camera = camera
            return [.panHoldingSelection(delta)]
        }
        var effects = time.map { advance(at: $0) } ?? []
        guard var touch = active, touch.id == id else { return [] }
        if touch.isHolding {
            touch.browseOffset += point.x - touch.current.x
            let steps = Int(touch.browseOffset / max(1, browseStep))
            touch.browseOffset -= Double(steps) * max(1, browseStep)
            touch.current = point
            active = touch
            effects.append(.movePreview(point))
            if steps != 0 { effects.append(.browseSelection(steps)) }
            return effects
        }
        let dx = point.x - touch.start.x
        let dy = point.y - touch.start.y
        let distance = hypot(dx, dy)
        if touch.allowsPanning, !touch.isPanning, distance > movementThreshold {
            touch.isPanning = true
            effects.append(.cancelPreview)
        }
        if touch.isPanning {
            effects.append(.pan(MobilePoint(x: point.x - touch.current.x, y: point.y - touch.current.y)))
        } else {
            effects.append(.movePreview(point))
        }
        touch.current = point
        active = touch
        return effects
    }

    public mutating func ended(id: Int, at point: MobilePoint, time: Double) -> [MobileTouchEffect] {
        guard !rejectingTouchesUntilReset else { return [] }
        if camera?.id == id { camera = nil; return [] }
        guard let touch = active, touch.id == id else { return [] }
        active = nil
        if camera != nil {
            camera = nil
            rejectingTouchesUntilReset = true
        }
        if touch.isHolding { return [.commitSelection] }
        guard !touch.isPanning,
              (!touch.allowsPanning || hypot(point.x - touch.start.x, point.y - touch.start.y) <= movementThreshold),
              time - touch.beganAt <= maximumTapDuration else {
            return [.cancelPreview]
        }
        return [.commit(point)]
    }

    public mutating func cancel() -> [MobileTouchEffect] {
        guard active != nil else { return [] }
        active = nil
        camera = nil
        return [.cancelPreview]
    }

    /**
     * Cancels a pending tap and rejects input until the current touch sequence ends.
     */
    public mutating func cancelForMultiTouch() -> [MobileTouchEffect] {
        let hadActiveTouch = active != nil
        active = nil
        camera = nil
        rejectingTouchesUntilReset = true
        return hadActiveTouch ? [.cancelPreview] : []
    }

    /**
     * Allows input after the view confirms that all contacts have lifted.
     */
    public mutating func resetAfterAllTouchesEnded() {
        rejectingTouchesUntilReset = false
    }
}
