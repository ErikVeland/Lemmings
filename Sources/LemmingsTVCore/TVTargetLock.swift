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
    /// Keep the displayed actor while it remains inside the same precision pick box.
    public static func retain(_ selection: MobileTargetSelection?, at point: MobilePoint,
                              candidates: [MobileTargetCandidate], viewport: MobileViewport) -> MobileTargetSelection? {
        guard let selection, viewport.contentFrame.contains(point),
              let candidate = candidates.first(where: { $0.id == selection.id }),
              candidate.assignment == .eligible else { return nil }
        let level = viewport.levelPoint(fromView: point)
        let box = candidate.pointerBounds ?? .init(x: -6, y: -9, width: 12, height: 19)
        guard box.contains(.init(x: level.x - candidate.point.x, y: level.y - candidate.point.y)) else { return nil }
        return .init(id: candidate.id, point: candidate.point, state: candidate.assignment)
    }

}
