import NxlvKit

/// Tap for one frame. Hold to shuttle. Release parks the timeline at the edit point.
public struct TVTimelineTransport: Sendable {
    public enum Event: Equatable, Sendable { case resetSpeed, park, step(Int), scrub(Int, Bool) }
    private var primed = false
    private var direction: Int?
    private var started = 0.0
    private var scrubbing = false
    private var previous: Set<ControllerBindings.Button> = []
    public init() {}

    public mutating func reset() -> [Event] {
        let events: [Event] = scrubbing ? [.scrub(direction ?? -1, false)] : []
        self = .init()
        return events
    }

    public mutating func update(pressed: Set<ControllerBindings.Button>, at time: Double, speed: Double = 1) -> [Event] {
        guard !pressed.contains(.options) else { return reset() }
        guard primed else {
            if !pressed.contains(.leftTrigger) && !pressed.contains(.rightTrigger) { primed = true }
            previous = pressed
            return []
        }
        var events: [Event] = []
        let requested: Int? = pressed.contains(.rightTrigger) && !previous.contains(.rightTrigger) ? 1
            : pressed.contains(.leftTrigger) && !previous.contains(.leftTrigger) ? -1 : direction
        if requested != direction, requested != nil, speed > 1 {
            let stopped = reset()
            previous = pressed
            return stopped + [.resetSpeed]
        }
        if requested != direction {
            if scrubbing { events.append(.scrub(direction ?? -1, false)) }
            direction = requested; started = time; scrubbing = false
            if requested != nil { events.append(.park) }
        }
        if let direction {
            let button: ControllerBindings.Button = direction < 0 ? .leftTrigger : .rightTrigger
            if !pressed.contains(button) {
                events.append(scrubbing ? .scrub(direction, false) : .step(direction))
                self.direction = nil; scrubbing = false
            } else if !scrubbing && time - started >= 0.22 {
                scrubbing = true; events.append(.scrub(direction, true))
            }
        }
        previous = pressed
        return events
    }
}
