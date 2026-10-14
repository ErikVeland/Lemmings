import Foundation

public enum MobileTouchEffect: Equatable, Sendable {
    case preview(MobilePoint)
    case movePreview(MobilePoint)
    case commit(MobilePoint)
    case pan(MobilePoint)
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
    }

    public var movementThreshold: Double
    public var maximumTapDuration: Double
    private var active: ActiveTouch?
    private var rejectingTouchesUntilReset = false

    public init(movementThreshold: Double = 10, maximumTapDuration: Double = .infinity) {
        self.movementThreshold = max(1, movementThreshold)
        self.maximumTapDuration = max(0.1, maximumTapDuration)
    }

    public mutating func began(id: Int, at point: MobilePoint, time: Double, allowsPanning: Bool = true) -> [MobileTouchEffect] {
        guard !rejectingTouchesUntilReset else { return [] }
        guard active == nil else { return cancelForMultiTouch() }
        active = ActiveTouch(id: id, beganAt: time, start: point, current: point, isPanning: false, allowsPanning: allowsPanning)
        return [.preview(point)]
    }

    public mutating func moved(id: Int, to point: MobilePoint) -> [MobileTouchEffect] {
        guard var touch = active, touch.id == id else { return [] }
        let dx = point.x - touch.start.x
        let dy = point.y - touch.start.y
        let distance = hypot(dx, dy)
        var effects: [MobileTouchEffect] = []
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
        guard let touch = active, touch.id == id else { return [] }
        active = nil
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
        return [.cancelPreview]
    }

    /**
     * Cancels a pending tap and rejects input until the current touch sequence ends.
     */
    public mutating func cancelForMultiTouch() -> [MobileTouchEffect] {
        let hadActiveTouch = active != nil
        active = nil
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
