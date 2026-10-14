import Foundation

/// Return navigation owns the bottom-left slot. Forward navigation owns the bottom-right slot.
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

    public init(actions: [GameFrontEnd.Action], columns requested: Int,
                spanSingleAction: Bool = false, alignTrailing: Bool = true) {
        let back = actions.firstIndex(where: \.isBackNavigation)
        let forward = actions.lastIndex { $0.primary && !$0.isBackNavigation }
        let paired = back != nil && forward != nil && actions.count > 1
        let columns = min(max(1, actions.count), max(paired ? 2 : 1, requested))
        let rows = Int(ceil(Double(actions.count) / Double(columns)))
        self.columns = columns; self.rows = rows
        guard let back else {
            let remainder = actions.count % columns
            slots = actions.enumerated().map { index, action in
                let alone = spanSingleAction && index == actions.count - 1 && index % columns == 0
                let offset = alignTrailing && !alone && remainder > 0 && index / columns == rows - 1 ? columns - remainder : 0
                return Slot(action: action, row: index / columns, column: index % columns + offset, span: alone ? columns : 1)
            }
            return
        }
        let backSlot = (rows - 1) * columns
        let forwardSlot = forward.map { _ in rows * columns - 1 }
        var placed = [Slot(action: actions[back], row: rows - 1, column: 0, span: 1)]
        if let forward { placed.append(Slot(action: actions[forward], row: rows - 1, column: columns - 1, span: 1)) }
        var slot = 0
        for (index, action) in actions.enumerated() where index != back && index != forward {
            while slot == backSlot || slot == forwardSlot { slot += 1 }
            placed.append(Slot(action: action, row: slot / columns, column: slot % columns, span: 1))
            slot += 1
        }
        slots = placed.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
    }
}
