import CoreGraphics

/// The Mac-style cover browser uses the same frames for drawing and UIKit input.
public struct LevelBrowserGeometry {
    public let board: CGRect
    public let title: CGRect
    public let subtitle: CGRect
    public let stage: CGRect
    /// Back, previous rank, next rank and Play, in that order, when `actionCount` is 4.
    public let actions: [CGRect]

    public init(safe: CGRect, actionCount: Int = 4) {
        board = safe.insetBy(dx: 8, dy: 12)
        let left = board.minX + 16, width = board.width - 32
        title = CGRect(x: left, y: board.minY + 14, width: width, height: 40)
        subtitle = CGRect(x: left, y: title.maxY + 2, width: width, height: 22)
        let height: CGFloat = 44
        let count = max(1, actionCount)
        let gaps = CGFloat(count - 1) * 12
        let buttonWidth = min(160, (width - gaps) / CGFloat(count))
        let total = buttonWidth * CGFloat(count) + gaps
        let x = board.midX - total / 2, y = board.maxY - height - 14
        actions = (0..<count).map { CGRect(x: x + CGFloat($0) * (buttonWidth + 12), y: y, width: buttonWidth, height: height) }
        let top = subtitle.maxY + 4
        stage = CGRect(x: board.minX, y: top, width: board.width, height: max(0, y - 6 - top))
    }
}
