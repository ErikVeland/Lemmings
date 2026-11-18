/// Tracks successful assignments and explicit camera targets for one attempt.
public struct AssignmentFocus {
    private var assignments: [(id: Int, skill: Int, tick: Int)] = []
    public private(set) var cursor: Int?
    private var facingLeft: Bool?
    public init() {}
    public var lastSkill: Int? { assignments.last?.skill }
    public var lastID: Int? { assignments.last?.id }
    public mutating func record(id: Int, skill: Int, tick: Int) {
        assignments.append((id, skill, tick))
    }
    public mutating func rewind(to tick: Int) {
        assignments.removeAll { $0.tick > tick }
        cursor = nil
        facingLeft = nil
    }
    public mutating func next(
        activeIDs: [Int], selectableIDs: Set<Int>? = nil,
        facingLeftIDs: Set<Int> = [], direction: Int
    ) -> Int? {
        let assigned = Set(assignments.map(\.id))
        let candidates = activeIDs.sorted().filter {
            !assigned.contains($0) && (selectableIDs?.contains($0) ?? true)
        }
        guard !candidates.isEmpty else { return nil }
        var orderedCandidates = candidates
        if let preferredFacing = facingLeft.map({ !$0 }) {
            let matching = candidates.filter { facingLeftIDs.contains($0) == preferredFacing }
            if !matching.isEmpty { orderedCandidates = matching }
        }
        let target: Int
        if let cursor {
            target = direction < 0
                ? orderedCandidates.last(where: { $0 < cursor }) ?? orderedCandidates.last!
                : orderedCandidates.first(where: { $0 > cursor }) ?? orderedCandidates.first!
        } else { target = direction < 0 ? orderedCandidates.last! : orderedCandidates.first! }
        cursor = target
        facingLeft = facingLeftIDs.contains(target)
        return target
    }
}
