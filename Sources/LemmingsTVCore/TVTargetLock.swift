import LemmingsMobileCore

/// Controller cycling selects an actor, rather than a location another actor can cross.
public struct TVTargetLock: Sendable {
    public private(set) var id: Int?
    public init() {}
    public mutating func select(_ id: Int) { self.id = id }
    public mutating func clear() { id = nil }
    public func resolve(candidates: [MobileTargetCandidate], visible: MobileRect) -> MobileTargetSelection? {
        guard let id, let candidate = candidates.first(where: { $0.id == id }),
              visible.contains(candidate.point) else { return nil }
        return .init(id: id, point: candidate.point, state: candidate.assignment)
    }
}
