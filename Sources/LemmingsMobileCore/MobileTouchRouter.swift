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
    }

    public var movementThreshold: Double
    public var maximumTapDuration: Double
    private var active: ActiveTouch?

    public init(movementThreshold: Double = 10, maximumTapDuration: Double = 0.45) {
        self.movementThreshold = max(1, movementThreshold)
        self.maximumTapDuration = max(0.1, maximumTapDuration)
    }

    public mutating func began(id: Int, at point: MobilePoint, time: Double) -> [MobileTouchEffect] {
        var effects: [MobileTouchEffect] = []
        if active != nil { effects.append(.cancelPreview) }
        active = ActiveTouch(id: id, beganAt: time, start: point, current: point, isPanning: false)
        effects.append(.preview(point))
        return effects
    }

    public mutating func moved(id: Int, to point: MobilePoint) -> [MobileTouchEffect] {
        guard var touch = active, touch.id == id else { return [] }
        let dx = point.x - touch.start.x
        let dy = point.y - touch.start.y
        let distance = hypot(dx, dy)
        var effects: [MobileTouchEffect] = []
        if !touch.isPanning, distance > movementThreshold {
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
        guard let touch = active, touch.id == id else { return [] }
        active = nil
        guard !touch.isPanning, time - touch.beganAt <= maximumTapDuration else {
            return [.cancelPreview]
        }
        return [.commit(point)]
    }

    public mutating func cancel() -> [MobileTouchEffect] {
        guard active != nil else { return [] }
        active = nil
        return [.cancelPreview]
    }
}
