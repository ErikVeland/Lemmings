import Foundation

/**
 * Separates a deliberate vertical Zoom gesture from camera panning.
 */
public enum PrecisionZoomScrollAction: Equatable, Sendable {
    case zoomIn
    case zoomOut
    case magnify(Double)
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
    public init() {}

    /**
     * Tracks continuous vertical input. Horizontal and modified input retain panning.
     */
    public mutating func handle(horizontal: Double, vertical: Double, precise: Bool,
                                phase: PrecisionZoomScrollPhase = .none, momentum: Bool = false,
                                modified: Bool = false, time: TimeInterval) -> PrecisionZoomScrollDecision {
        if modified { return .pan }
        if phase == .cancelled || phase == .ended { return .consumed }
        guard horizontal.isFinite, vertical.isFinite else { return .consumed }
        if momentum { return abs(vertical) > abs(horizontal) ? .consumed : .pan }
        if horizontal == 0, vertical == 0 { return .consumed }
        guard abs(vertical) > abs(horizontal) else { return .pan }
        let amount = precise ? vertical * 0.01 : vertical * 0.12
        return .zoom(.magnify(exp(min(0.4, max(-0.4, amount)))))
    }
}
