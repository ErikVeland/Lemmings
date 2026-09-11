/// Tracks successful assignments and explicit camera targets for one attempt.
public struct AssignmentFocus {
    private var assignments: [(id: Int, skill: Int, tick: Int)] = []
    public private(set) var cursor: Int?
    public init() {}
    public var lastSkill: Int? { assignments.last?.skill }
    public var lastID: Int? { assignments.last?.id }
    public mutating func record(id: Int, skill: Int, tick: Int) {
        assignments.append((id, skill, tick))
    }
    public mutating func rewind(to tick: Int) {
        assignments.removeAll { $0.tick > tick }
        cursor = nil
    }
    public mutating func next(activeIDs: [Int], direction: Int) -> Int? {
        let assigned = Set(assignments.map(\.id))
        let candidates = activeIDs.sorted().filter { !assigned.contains($0) }
        guard !candidates.isEmpty else { return nil }
        let target: Int
        if let cursor {
            target = direction < 0
                ? candidates.last(where: { $0 < cursor }) ?? candidates.last!
                : candidates.first(where: { $0 > cursor }) ?? candidates.first!
        } else { target = direction < 0 ? candidates.last! : candidates.first! }
        cursor = target
        return target
    }
}
