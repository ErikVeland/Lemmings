import AppKit
import NxlvKit

extension PrecisionZoomScrollGesture {
    mutating func handle(_ event: NSEvent) -> PrecisionZoomScrollDecision {
        let phase: PrecisionZoomScrollPhase
        if event.phase.contains(.cancelled) { phase = .cancelled }
        else if event.phase.contains(.began) { phase = .began }
        else if event.phase.contains(.ended) { phase = .ended }
        else if event.phase.contains(.changed) { phase = .changed }
        else { phase = .none }
        return handle(horizontal: Double(event.scrollingDeltaX), vertical: Double(event.scrollingDeltaY),
            precise: event.hasPreciseScrollingDeltas, phase: phase,
            momentum: !event.momentumPhase.isEmpty,
            modified: !event.modifierFlags.intersection([.shift, .command, .control, .option]).isEmpty,
            time: event.timestamp)
    }
}
