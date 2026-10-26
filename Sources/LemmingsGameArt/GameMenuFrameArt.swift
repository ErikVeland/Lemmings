import CoreGraphics

/// Shared framing for the briefing, results, record and level pages.
public enum GameMenuFrameArt {
    private static let stone = CGColor(srgbRed: 0.4346, green: 0.4664, blue: 0.5054, alpha: 1)
    private static let moss = CGColor(srgbRed: 0.3244, green: 0.6678, blue: 0.1572, alpha: 1)

    /// The same stone edging and moss cap used by the level briefing.
    public static func draw(in context: CGContext, board: CGRect, scale: CGFloat = 1, shape: GameControlShape = .square) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        if shape == .rounded {
            context.setStrokeColor(stone)
            context.setLineWidth(2 * scale)
            shape.stroke(board, inset: scale, in: context)
            context.saveGState()
            context.clip(to: CGRect(x: board.minX, y: board.minY, width: board.width, height: 5 * scale))
            context.setStrokeColor(moss)
            shape.stroke(board, inset: scale, in: context)
            context.restoreGState()
            return
        }
        func fill(_ rect: CGRect, _ color: CGColor) {
            context.setFillColor(color)
            context.fill(rect)
        }
        for x in stride(from: board.minX, to: board.maxX, by: 28 * scale) {
            fill(CGRect(x: x, y: board.minY, width: min(26 * scale, board.maxX - x), height: 7 * scale), stone)
            fill(CGRect(x: x, y: board.maxY - 7 * scale, width: min(26 * scale, board.maxX - x), height: 7 * scale), stone)
        }
        fill(CGRect(x: board.minX, y: board.minY - 3 * scale, width: board.width, height: 4 * scale), moss)
        for x in stride(from: board.minX, to: board.maxX - 8 * scale, by: 19 * scale) {
            fill(CGRect(x: x, y: board.minY, width: 6 * scale, height: 5 * scale), moss)
        }
    }
}
