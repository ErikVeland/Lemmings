import Foundation

public enum MobileAssignmentState: String, Codable, Equatable, Sendable {
    case eligible
    case alreadyAssigned
    case unavailable
}

public struct MobileTargetCandidate: Codable, Equatable, Sendable {
    public let id: Int
    public let point: MobilePoint
    /// `-1` faces left and `1` faces right.
    public let direction: Int
    public let assignment: MobileAssignmentState
    public let isBuilding: Bool
    public let hasTool: Bool

    public init(
        id: Int,
        point: MobilePoint,
        direction: Int,
        assignment: MobileAssignmentState,
        isBuilding: Bool = false,
        hasTool: Bool = false
    ) {
        self.id = id
        self.point = point
        self.direction = direction < 0 ? -1 : 1
        self.assignment = assignment
        self.isBuilding = isBuilding
        self.hasTool = hasTool
    }
}

public enum MobileTargetPreference: Equatable, Sendable {
    case assignable
    case toolHolder
}

public struct MobileTargetSelection: Codable, Equatable, Sendable {
    public let id: Int
    public let point: MobilePoint
    public let state: MobileAssignmentState

    public init(id: Int, point: MobilePoint, state: MobileAssignmentState) {
        self.id = id
        self.point = point
        self.state = state
    }
}

public enum MobileTargetSelector {
    /// Picks a stable target in screen-space, so the touch allowance does not
    /// grow when the player zooms in or shrink when they zoom out.
    public static func select(
        candidates: [MobileTargetCandidate],
        touch: MobilePoint,
        viewport: MobileViewport,
        radius: Double = 26,
        preference: MobileTargetPreference = .assignable,
        favourApproaching: Bool = true
    ) -> MobileTargetSelection? {
        guard radius > 0, radius.isFinite else { return nil }
        let projected = candidates.compactMap { candidate -> (MobileTargetCandidate, Double)? in
            let viewPoint = viewport.viewPoint(fromLevel: candidate.point)
            let dx = viewPoint.x - touch.x
            let dy = viewPoint.y - touch.y
            let distance = dx * dx + dy * dy
            return distance <= radius * radius ? (candidate, distance) : nil
        }
        guard !projected.isEmpty else { return nil }

        func preferred(_ candidate: MobileTargetCandidate) -> Bool {
            switch preference {
            case .assignable:
                return candidate.assignment == .eligible
            case .toolHolder:
                return candidate.hasTool
            }
        }
        func precedes(
            _ lhs: (MobileTargetCandidate, Double),
            _ rhs: (MobileTargetCandidate, Double)
        ) -> Bool {
            let leftPreferred = preferred(lhs.0)
            let rightPreferred = preferred(rhs.0)
            if leftPreferred != rightPreferred { return leftPreferred }
            if lhs.0.assignment != rhs.0.assignment {
                if lhs.0.assignment == .eligible { return true }
                if rhs.0.assignment == .eligible { return false }
            }
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.id < rhs.0.id
        }

        let sorted = projected.sorted(by: precedes)
        guard var chosen = sorted.first?.0 else { return nil }
        if favourApproaching, chosen.assignment == .eligible {
            let touchLevel = viewport.levelPoint(fromView: touch)
            func isApproaching(_ candidate: MobileTargetCandidate) -> Bool {
                (touchLevel.x - candidate.point.x) * Double(candidate.direction) >= 0
            }
            func isBehind(_ candidate: MobileTargetCandidate, builder: MobileTargetCandidate) -> Bool {
                guard candidate.direction == builder.direction else { return false }
                return builder.direction > 0
                    ? candidate.point.x < builder.point.x
                    : candidate.point.x > builder.point.x
            }
            if chosen.isBuilding,
               let follower = sorted.map(\.0).first(where: {
                   $0.id != chosen.id && $0.assignment == .eligible
                       && isApproaching($0) && isBehind($0, builder: chosen)
               }) {
                chosen = follower
            } else if !isApproaching(chosen),
                      let approaching = sorted.map(\.0).first(where: {
                          $0.assignment == .eligible && $0.direction != chosen.direction
                              && isApproaching($0)
                      }) {
                chosen = approaching
            }
        }
        return MobileTargetSelection(id: chosen.id, point: chosen.point, state: chosen.assignment)
    }
}
