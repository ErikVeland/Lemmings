/// A held select press cannot activate the next page or accept a Ready handover.
public struct TVActivationGate: Sendable {
    private var armed = false
    public init() {}
    public mutating func reset() { armed = false }
    public mutating func observeNeutral() { armed = true }
    public mutating func consume() -> Bool {
        guard armed else { return false }
        armed = false
        return true
    }
}
