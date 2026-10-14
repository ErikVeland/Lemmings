/**
 * Tracks controller availability and pauses active play after a disconnect.
 */
public struct MobileControllerConnection: Sendable {
    private var wasConnected = false

    public init() {}

    /**
     * Returns true once when the active controller disconnects during play.
     */
    public mutating func update(isConnected: Bool, isMenu: Bool) -> Bool {
        defer { wasConnected = isConnected }
        return wasConnected && !isConnected && !isMenu
    }

    /**
     * Forgets controller state when input polling stops for a lifecycle change.
     */
    public mutating func reset() {
        wasConnected = false
    }
}
