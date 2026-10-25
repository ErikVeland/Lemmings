import Foundation

/**
 * Places return and forward navigation in the bottom corners, or stacks them on narrow screens.
 */
public struct GameFooterGrid {
    public struct Slot {
        public let action: GameFrontEnd.Action
        public let row: Int
        public let column: Int
        public let span: Int
    }
    public let columns: Int
    public let rows: Int
    public let slots: [Slot]

    /// Every occupied row fills its width, including rows with fewer actions.
    public func frame(for slot: Slot, x: CGFloat, y: CGFloat, width: CGFloat,
                      height: CGFloat, gap: CGFloat, rowGap: CGFloat) -> CGRect {
        let row = slots.filter { $0.row == slot.row }.sorted { $0.column < $1.column }
        let column = row.firstIndex { $0.action.id == slot.action.id } ?? 0
        let cell = (width - CGFloat(max(0, row.count - 1)) * gap) / CGFloat(max(1, row.count))
        let left = x + CGFloat(column) * (cell + gap)
        return CGRect(x: left, y: y + CGFloat(slot.row) * (height + rowGap),
                      width: cell, height: height)
    }

    public init(actions: [GameFrontEnd.Action], columns requested: Int,
                spanSingleAction: Bool = false, alignTrailing: Bool = true) {
        let back = actions.firstIndex(where: \.isBackNavigation)
        let forward = actions.lastIndex { $0.primary && !$0.isBackNavigation }
        let capacity = min(max(1, actions.count), max(1, requested))
        let rows = Int(ceil(Double(actions.count) / Double(capacity)))
        let columns = rows == 0 ? 1 : (actions.count + rows - 1) / rows
        self.columns = columns; self.rows = rows
        if columns == 1 {
            let ordered = actions.enumerated().filter { $0.offset != back && $0.offset != forward }.map(\.element)
                + (back.map { [actions[$0]] } ?? [])
                + (forward.map { [actions[$0]] } ?? [])
            slots = ordered.enumerated().map { Slot(action: $0.element, row: $0.offset, column: 0, span: 1) }
            return
        }
        // Balance the rows before reserving the return/forward corners. Four
        // actions in three columns form two pairs, rather than a stranded action.
        let ordered = actions.enumerated().filter { $0.offset != back && $0.offset != forward }.map(\.element)
        var remaining = ordered
        var placed: [Slot] = []
        for row in 0..<rows {
            let count = actions.count / rows + (row >= rows - actions.count % rows ? 1 : 0)
            let last = row == rows - 1
            let reserved = last ? (back == nil ? 0 : 1) + (forward == nil ? 0 : 1) : 0
            var group = Array(remaining.prefix(max(0, count - reserved)))
            remaining.removeFirst(group.count)
            if last, let back { group.insert(actions[back], at: 0) }
            if last, let forward { group.append(actions[forward]) }
            for (index, action) in group.enumerated() {
                let column = last && forward != nil && index == group.count - 1 ? columns - 1 : index
                placed.append(Slot(action: action, row: row, column: column,
                    span: spanSingleAction && group.count == 1 ? columns : 1))
            }
        }
        slots = placed
    }
}
