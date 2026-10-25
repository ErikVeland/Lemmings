import Foundation

/// A fixed browsing order keeps moving crowds and camera pans from replacing the chosen actor.
public struct MobileTouchSelection: Sendable {
    public let ids: [Int]
    private var index: Int

    public init?(candidates: [MobileTargetCandidate], touch: MobilePoint, viewport: MobileViewport,
                 selectedID: Int, radius: Double = 30) {
        guard viewport.contentFrame.contains(touch) else { return nil }
        ids = candidates.filter {
            let point = viewport.viewPoint(fromLevel: $0.point)
            return hypot(point.x - touch.x, point.y - touch.y) <= radius
        }.sorted {
            if $0.point.x != $1.point.x { return $0.point.x < $1.point.x }
            if $0.point.y != $1.point.y { return $0.point.y < $1.point.y }
            return $0.id < $1.id
        }.map(\.id)
        guard let index = ids.firstIndex(of: selectedID) else { return nil }
        self.index = index
    }

    public func selection(in candidates: [MobileTargetCandidate]) -> MobileTargetSelection? {
        guard let candidate = candidates.first(where: { $0.id == ids[index] }) else { return nil }
        return .init(id: candidate.id, point: candidate.point, state: candidate.assignment)
    }

    public mutating func browse(by steps: Int, candidates: [MobileTargetCandidate]) {
        guard steps != 0 else { return }
        let live = Set(candidates.map(\.id))
        let direction = steps > 0 ? 1 : -1
        for _ in 0..<min(steps.magnitude, UInt(ids.count)) {
            var next = index + direction
            while ids.indices.contains(next), !live.contains(ids[next]) { next += direction }
            guard ids.indices.contains(next) else { break }
            index = next
        }
    }
}
