import CoreGraphics
import NxlvKit

/// Lists fill readable columns in reading order without crossing a section heading.
public struct GameListGrid {
    public struct Row {
        public let indices: Range<Int>
    }
    public let columns: Int
    public let targets: [GameFrontEnd.Target]
    public let headings: [(String, CGRect)]
    public let rows: [Row]
    public let height: CGFloat

    public init(actions: [GameFrontEnd.Action], width: CGFloat, columnsEnabled: Bool = true,
                maximumColumns: Int = 3, minimumColumnWidth: CGFloat = 260,
                gap: CGFloat = 12, rowGap: CGFloat = 8, minimumHeight: CGFloat = 52,
                captionInset: CGFloat = 48, rowHeadings: [String: String] = [:],
                font: ClassicMacUserInterface.Font? = nil) {
        let longestWord = actions.map { action in
            (action.visibleTitle.split(whereSeparator: \.isWhitespace).map {
                GameTextLayout.width(of: String($0), font: font)
            }.max() ?? 0) + captionInset + (action.toggleValue == nil ? 0 : 28)
        }.max() ?? 0
        let minimum = max(minimumColumnWidth, longestWord)
        let fitting = max(1, Int((max(0, width) + gap) / (minimum + gap)))
        let columns = columnsEnabled ? max(1, min(maximumColumns, actions.count, fitting)) : 1
        self.columns = columns
        var targets: [GameFrontEnd.Target] = [], headings: [(String, CGRect)] = [], rows: [Row] = []
        var y: CGFloat = 0
        var start = 0
        while start < actions.count {
            if let title = rowHeadings[actions[start].id] {
                y += 12
                let height = GameTextLayout.height(title, width: width, font: font)
                headings.append((title, CGRect(x: 0, y: y, width: width, height: height)))
                y += height + 8
            }
            var end = min(start + columns, actions.count)
            if let nextHeading = (start + 1..<end).first(where: { rowHeadings[actions[$0].id] != nil }) { end = nextHeading }
            let count = end - start
            let cell = (width - CGFloat(count - 1) * gap) / CGFloat(count)
            let height = max(minimumHeight, actions[start..<end].map {
                GameTextLayout.height($0.visibleTitle, width: max(1, cell - captionInset - ($0.toggleValue == nil ? 0 : 28)), font: font) + 12
            }.max() ?? minimumHeight)
            for index in start..<end {
                targets.append(.init(action: actions[index], frame: CGRect(x: CGFloat(index - start) * (cell + gap),
                    y: y, width: cell, height: height)))
            }
            rows.append(Row(indices: start..<end))
            y += height + rowGap
            start = end
        }
        self.targets = targets
        self.headings = headings
        self.rows = rows
        self.height = max(0, y - rowGap)
    }
}
