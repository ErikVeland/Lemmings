import CoreGraphics
import LemmingsMobileCore

/// The Mac-style cover browser uses the same frames for drawing and UIKit input.
public struct LevelBrowserGeometry {
    public let board: CGRect
    public let title: CGRect
    public let subtitle: CGRect
    public let stage: CGRect
    /// Back, previous rank, next rank and Play, in that order, when `actionCount` is 4.
    public let actions: [CGRect]

    public init(safe: CGRect, actionCount: Int = 4, titleText: String = "", subtitleText: String = "",
                actionTitles: [String] = [], includesBack: Bool = true, rankActions: Range<Int>? = nil,
                occlusions: [MobileReservedRegion] = []) {
        board = safe.insetBy(dx: 8, dy: 12)
        let left = board.minX + 16, width = board.width - 32
        let heading = MobileDisplayRegions.clearHorizontalFrame(
            .init(x: left, y: board.minY + 14, width: width, height: 40), avoiding: occlusions)
        title = CGRect(x: heading.x, y: heading.y, width: heading.width,
            height: max(40, GameTextLayout.height(titleText, width: max(1, heading.width), face: .large)))
        let caption = MobileDisplayRegions.clearHorizontalFrame(
            .init(x: left, y: title.maxY + 2, width: width, height: 22), avoiding: occlusions)
        subtitle = CGRect(x: caption.x, y: caption.y, width: caption.width,
            height: max(22, GameTextLayout.height(subtitleText, width: max(1, caption.width))))
        let height: CGFloat = 44
        let count = max(1, actionCount)
        let minimumButtonWidth = max(120, (actionTitles.map { GameTextLayout.width(of: $0) }.max() ?? 0) + 24)
        let columns = min(count, max(1, Int((width + 12) / (minimumButtonWidth + 12))))
        let entries = (0..<count).map { GameFrontEnd.Action(String($0), "",
            primary: $0 == count - 1, backNavigation: includesBack && count > 1 && $0 == 0) }
        let groups: [[GameFrontEnd.Action]]
        if let rankActions, columns < count, rankActions.allSatisfy({ entries.indices.contains($0) }) {
            groups = [rankActions.map { entries[$0] }, entries.enumerated().filter { !rankActions.contains($0.offset) }.map(\.element)]
        } else { groups = [entries] }
        let grids = groups.map { GameFooterGrid(actions: $0, columns: columns, spanSingleAction: true) }
        let rows = grids.reduce(0) { $0 + $1.rows }
        let y = board.maxY - CGFloat(rows) * (height + 12) + 12 - 14
        var frames: [String: CGRect] = [:]
        var row = 0
        for grid in grids {
            for slot in grid.slots {
                let rowY = y + CGFloat(row + slot.row) * (height + 12)
                let clear = MobileDisplayRegions.clearHorizontalFrame(
                    .init(x: left, y: rowY, width: width, height: height), avoiding: occlusions)
                frames[slot.action.id] = grid.frame(for: slot, x: clear.x, y: y + CGFloat(row) * (height + 12), width: clear.width,
                    height: height, gap: 12, rowGap: 12)
            }
            row += grid.rows
        }
        actions = entries.map { frames[$0.id]! }
        let top = subtitle.maxY + 4
        stage = CGRect(x: board.minX, y: top, width: board.width, height: max(0, y - 6 - top))
    }
}
