import LemmingsMobileCore

/// Controller cycling selects an actor, rather than a location another actor can cross.
public struct TVTargetLock: Sendable {
    public private(set) var id: Int?
    private var crowdTravel = 0.0
    public init() {}
    public mutating func select(_ id: Int) { self.id = id; crowdTravel = 0 }
    public mutating func clear() { id = nil; crowdTravel = 0 }

    /// Fine aiming visits overlapping actors by ID, without changing skill rules.
    /// Travel works in either direction so a small wiggle can reach a whole stack.
    public mutating func aim(at point: MobilePoint, movement: MobilePoint,
                             displayed: MobileTargetSelection?, candidates: [MobileTargetCandidate],
                             viewport: MobileViewport, granular: Bool) -> MobileTargetSelection? {
        let distance = (movement.x * movement.x + movement.y * movement.y).squareRoot()
        guard granular, point.x.isFinite, point.y.isFinite, distance.isFinite,
              distance <= 6, viewport.contentFrame.contains(point) else { clear(); return nil }
        let level = viewport.levelPoint(fromView: point)
        let crowd = candidates.filter { candidate in
            let box = candidate.pointerBounds ?? .init(x: -6, y: -9, width: 12, height: 19)
            return box.contains(.init(x: level.x - candidate.point.x, y: level.y - candidate.point.y))
        }.sorted { $0.id < $1.id }
        guard crowd.count > 1 else { clear(); return nil }
        let previous = id ?? displayed?.id
        let current = crowd.firstIndex { $0.id == previous }
        let initial = current ?? crowd.indices.min {
            let a = crowd[$0], b = crowd[$1]
            if (a.assignment == .eligible) != (b.assignment == .eligible) { return a.assignment == .eligible }
            let da = (a.point.x - level.x) * (a.point.x - level.x) + (a.point.y - level.y) * (a.point.y - level.y)
            let db = (b.point.x - level.x) * (b.point.x - level.x) + (b.point.y - level.y) * (b.point.y - level.y)
            return da == db ? a.id < b.id : da < db
        }!
        if current == nil { crowdTravel = 0 }
        // Ignore sub-pixel noise. The controller's dead zone remains authoritative.
        if distance >= 0.05 { crowdTravel += distance }
        var selected = initial
        if crowdTravel >= 2 {
            selected = (initial + 1) % crowd.count
            crowdTravel.formTruncatingRemainder(dividingBy: 2)
        }
        let candidate = crowd[selected]
        id = candidate.id
        return .init(id: candidate.id, point: candidate.point, state: candidate.assignment)
    }
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
