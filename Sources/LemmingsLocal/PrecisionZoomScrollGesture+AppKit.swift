import AppKit
import NxlvKit

extension PrecisionZoomScrollGesture {
    static func normalizedDeltas(horizontal: Double, vertical: Double,
                                 directionInvertedFromDevice: Bool) -> (horizontal: Double, vertical: Double) {
        let direction = directionInvertedFromDevice ? -1.0 : 1.0
        return (horizontal * direction, vertical * direction)
    }

    mutating func handle(_ event: NSEvent) -> PrecisionZoomScrollDecision {
        let phase: PrecisionZoomScrollPhase
        if event.phase.contains(.cancelled) { phase = .cancelled }
        else if event.phase.contains(.began) { phase = .began }
        else if event.phase.contains(.ended) { phase = .ended }
        else if event.phase.contains(.changed) { phase = .changed }
        else { phase = .none }
        let delta = Self.normalizedDeltas(horizontal: Double(event.scrollingDeltaX),
            vertical: Double(event.scrollingDeltaY),
            directionInvertedFromDevice: event.isDirectionInvertedFromDevice)
        return handle(horizontal: delta.horizontal, vertical: delta.vertical,
            precise: event.hasPreciseScrollingDeltas, phase: phase,
            momentum: !event.momentumPhase.isEmpty,
            modified: !event.modifierFlags.intersection([.shift, .command, .control, .option]).isEmpty,
            time: event.timestamp)
    }
}
