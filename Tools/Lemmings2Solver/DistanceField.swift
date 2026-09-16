import Foundation
import NxlvKit

/// Distance to the nearest exit through open space, measured once per level on a coarse grid.
/// A straight-line distance ranks a lemming under a wall as close to an exit that it can reach
/// only by a long way round. This field follows the level's corridors instead.
struct DistanceField: Sendable {
    static let cell = 4
    let columns: Int
    let rows: Int
    /// Steps of `cell` pixels to the nearest exit. `Int.max` marks space with no open path.
    let steps: [Int]

    init(_ configuration: Lemmings2Runtime.Configuration) {
        let cell = Self.cell
        columns = (configuration.width + cell - 1) / cell
        rows = (configuration.height + cell - 1) / cell
        let columns = self.columns, rows = self.rows
        // A cell is open when any pixel in it is open and it lies outside every hazard.
        var open = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x0 = column * cell, y0 = row * cell
                let x1 = min(configuration.width, x0 + cell), y1 = min(configuration.height, y0 + cell)
                var any = false
                for y in y0..<y1 where !any {
                    for x in x0..<x1 where !configuration.solid[y * configuration.width + x] { any = true; break }
                }
                let centre = (x0 + cell / 2, y0 + cell / 2)
                open[row * columns + column] = any && !configuration.hazards.contains { centre.0 >= $0.x && centre.0 < $0.x + $0.width && centre.1 >= $0.y && centre.1 < $0.y + $0.height }
            }
        }
        var steps = [Int](repeating: .max, count: columns * rows)
        var queue: [Int] = []
        for exit in configuration.exits {
            let column = min(columns - 1, max(0, (exit.x + exit.width / 2) / cell))
            let row = min(rows - 1, max(0, (exit.y + exit.height / 2) / cell))
            let index = row * columns + column
            if steps[index] != 0 { steps[index] = 0; queue.append(index) }
        }
        var head = 0
        while head < queue.count {
            let index = queue[head]; head += 1
            let column = index % columns, row = index / columns
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let c = column + dx, r = row + dy
                guard c >= 0, c < columns, r >= 0, r < rows else { continue }
                let next = r * columns + c
                guard open[next], steps[next] == .max else { continue }
                steps[next] = steps[index] + 1
                queue.append(next)
            }
        }
        self.steps = steps
    }

    /// Pixels to the nearest exit through open space. A position with no open path counts as the
    /// longest distance in the field plus the straight-line fallback, so it ranks below every
    /// reachable position.
    func distance(x: Int, y: Int, fallback: Int) -> Int {
        let column = min(columns - 1, max(0, x / Self.cell)), row = min(rows - 1, max(0, y / Self.cell))
        let value = steps[row * columns + column]
        if value != .max { return value * Self.cell }
        // Lemmings stand on the cell boundary. Try the cell above before giving up.
        if row > 0, steps[(row - 1) * columns + column] != .max { return steps[(row - 1) * columns + column] * Self.cell }
        return Self.cell * (columns + rows) * 4 + fallback
    }
}

/// Distance fields by level fingerprint. The search builds each field once.
final class DistanceFields: @unchecked Sendable {
    static let shared = DistanceFields()
    private let lock = NSLock()
    private var fields: [String: DistanceField] = [:]

    func field(for configuration: Lemmings2Runtime.Configuration) -> DistanceField {
        let key = configuration.levelFingerprint ?? "\(configuration.width)x\(configuration.height)-\(configuration.pixels.count)-\(configuration.exits.map { "\($0.x),\($0.y)" })"
        lock.lock(); defer { lock.unlock() }
        if let field = fields[key] { return field }
        let field = DistanceField(configuration)
        fields[key] = field
        return field
    }
}
