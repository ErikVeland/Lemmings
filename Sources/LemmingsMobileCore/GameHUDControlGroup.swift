import CoreGraphics
import Foundation

/// Drawing, pointer input and accessibility use the same joined rectangles.
public enum GameHUDControlGroup {
    public static let border: CGFloat = 1
    public static let spacing: CGFloat = 12

    public static func desktopHeight(forWidth width: CGFloat) -> CGFloat {
        max(44, min(64, floor(width / 64) * 4))
    }

    public static func groups(_ frames: [CGRect], maximumGap: CGFloat = 4) -> [[Int]] {
        var remaining = Set(frames.indices)
        var result: [[Int]] = []
        while let first = remaining.min() {
            remaining.remove(first)
            var group = [first]
            var next = 0
            while next < group.count {
                let frame = frames[group[next]]
                let neighbours = remaining.sorted().filter { index in
                    let other = frames[index]
                    let horizontal = abs(frame.minY - other.minY) < 0.01 && abs(frame.height - other.height) < 0.01
                        && min(abs(frame.maxX - other.minX), abs(other.maxX - frame.minX)) <= maximumGap
                    let vertical = abs(frame.minX - other.minX) < 0.01 && abs(frame.width - other.width) < 0.01
                        && min(abs(frame.maxY - other.minY), abs(other.maxY - frame.minY)) <= maximumGap
                    return horizontal || vertical
                }
                for index in neighbours { remaining.remove(index); group.append(index) }
                next += 1
            }
            result.append(group.sorted())
        }
        return result
    }

    /// Divide existing gaps between neighbours without moving either outer edge.
    public static func joined(_ frames: [CGRect]) -> [CGRect] {
        var result = frames
        for group in groups(frames) {
            for left in group {
                for right in group where left != right {
                    let a = frames[left], b = frames[right]
                    if abs(a.minY - b.minY) < 0.01, abs(a.height - b.height) < 0.01,
                       b.minX >= a.maxX, b.minX - a.maxX <= 4 {
                        let edge = floor((a.maxX + b.minX) / 2)
                        result[left].size.width = edge - result[left].minX
                        let end = result[right].maxX
                        result[right].origin.x = edge
                        result[right].size.width = end - edge
                    }
                    if abs(a.minX - b.minX) < 0.01, abs(a.width - b.width) < 0.01,
                       b.minY >= a.maxY, b.minY - a.maxY <= 4 {
                        let edge = floor((a.maxY + b.minY) / 2)
                        result[left].size.height = edge - result[left].minY
                        let end = result[right].maxY
                        result[right].origin.y = edge
                        result[right].size.height = end - edge
                    }
                }
            }
        }
        return result
    }

    public static func bounds(containing frame: CGRect, in frames: [CGRect]) -> CGRect {
        guard let index = frames.firstIndex(of: frame),
              let group = groups(frames, maximumGap: 0.01).first(where: { $0.contains(index) }) else { return frame }
        return group.reduce(CGRect.null) { $0.union(frames[$1]) }
    }
}
