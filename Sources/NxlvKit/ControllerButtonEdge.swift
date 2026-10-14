/// A shortcut requires neutral input after a menu, owner or device change.
public struct ControllerButtonEdge {
    private var armed = false
    private var previous = false
    public init() {}
    public mutating func reset() { armed = false; previous = false }
    public mutating func update(pressed: Bool, active: Bool) -> Bool {
        guard active else { reset(); return false }
        defer { previous = pressed }
        if !pressed { armed = true }
        return armed && pressed && !previous
    }
}
