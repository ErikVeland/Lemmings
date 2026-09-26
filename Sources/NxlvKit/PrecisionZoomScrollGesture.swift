import Foundation

/**
 * Separates a deliberate vertical Zoom gesture from camera panning.
 */
public enum PrecisionZoomScrollAction: Equatable, Sendable {
    case zoomIn
    case zoomOut
}

public enum PrecisionZoomScrollDecision: Equatable, Sendable {
    case pan
    case consumed
    case zoom(PrecisionZoomScrollAction)
}

public enum PrecisionZoomScrollPhase: Sendable {
    case none
    case began
    case changed
    case ended
    case cancelled
}

public struct PrecisionZoomScrollGesture {
    private var accumulatedY = 0.0
    private var acted = false
    private var lastTime: TimeInterval?

    public init() {}

    /**
     * Emits at most one Zoom action per precise touch gesture. Wheel ticks stay independent.
     */
    public mutating func handle(horizontal: Double, vertical: Double, precise: Bool,
                                phase: PrecisionZoomScrollPhase = .none, momentum: Bool = false,
                                modified: Bool = false, time: TimeInterval) -> PrecisionZoomScrollDecision {
        if phase == .began || (phase == .none && lastTime.map({ time < $0 || time - $0 > 0.45 }) == true) {
            reset()
        }
        lastTime = time
        if phase == .cancelled {
            reset()
            return .consumed
        }
        let ending = phase == .ended
        defer { if ending { reset() } }
        if modified {
            reset()
            return .pan
        }
        if !precise {
            reset()
            guard abs(vertical) > abs(horizontal) else { return .pan }
            return .zoom(vertical > 0 ? .zoomIn : .zoomOut)
        }
        if acted { return .consumed }
        if momentum { return abs(vertical) > abs(horizontal) ? .consumed : .pan }
        guard abs(vertical) > abs(horizontal) else { return .pan }
        accumulatedY += vertical
        guard abs(accumulatedY) >= 8 else { return .consumed }
        acted = true
        return .zoom(accumulatedY > 0 ? .zoomIn : .zoomOut)
    }

    private mutating func reset() {
        accumulatedY = 0
        acted = false
        lastTime = nil
    }
}
