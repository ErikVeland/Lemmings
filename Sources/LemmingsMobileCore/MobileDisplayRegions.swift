import Foundation

/// UIKit supplies active frames with their interactive margins already included.
public struct MobileReservedRegion: Equatable, Sendable {
    public enum Kind: Sendable { case division, occlusion }
    public let kind: Kind
    public let frame: MobileRect

    public init(kind: Kind, frame: MobileRect) {
        self.kind = kind
        self.frame = frame
    }
}

public enum MobileDisplayRegions {
    /// Candidate rectangles avoid every reserved region. A menu uses one rectangle so
    /// scrolling cannot move an action behind a hinge or camera cutout.
    public static func freeFrames(in safe: MobileRect, avoiding regions: [MobileReservedRegion]) -> [MobileRect] {
        var frames = [safe]
        for region in regions {
            let obstacle = region.frame
            guard obstacle.x.isFinite, obstacle.y.isFinite,
                  obstacle.width.isFinite, obstacle.height.isFinite,
                  obstacle.width > 0, obstacle.height > 0 else { continue }
            frames = frames.flatMap { frame -> [MobileRect] in
                guard frame.intersects(obstacle) else { return [frame] }
                return [
                    MobileRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(0, obstacle.minY - frame.minY)),
                    MobileRect(x: frame.minX, y: max(frame.minY, obstacle.maxY), width: frame.width, height: max(0, frame.maxY - obstacle.maxY)),
                    MobileRect(x: frame.minX, y: frame.minY, width: max(0, obstacle.minX - frame.minX), height: frame.height),
                    MobileRect(x: max(frame.minX, obstacle.maxX), y: frame.minY, width: max(0, frame.maxX - obstacle.maxX), height: frame.height),
                ].filter { $0.width > 0 && $0.height > 0 }
            }
        }
        return frames
    }

    /// Full-height banks keep vertically scrolling Home lists clear of cutouts and the hinge.
    public static func bookPanes(in safe: MobileRect, avoiding regions: [MobileReservedRegion]) -> [MobileRect] {
        guard let division = regions.first(where: {
            $0.kind == .division && $0.frame.height >= safe.height * 0.7
                && $0.frame.height > $0.frame.width && $0.frame.minX > safe.minX && $0.frame.maxX < safe.maxX
        }) else { return [] }
        let panes = [
            MobileRect(x: safe.minX, y: safe.minY, width: division.frame.minX - safe.minX, height: safe.height),
            MobileRect(x: division.frame.maxX, y: safe.minY, width: safe.maxX - division.frame.maxX, height: safe.height)
        ]
        let banks = panes.compactMap { pane in
            freeFrames(in: pane, avoiding: regions)
                .filter { $0.width >= 280 && $0.minY == safe.minY && $0.maxY == safe.maxY }
                .max { $0.width < $1.width }
        }
        return banks.count == 2 ? banks : []
    }

    /// Each tabletop screen has its own scroll surface, clear of the horizontal hinge.
    public static func tablePanes(in safe: MobileRect, avoiding regions: [MobileReservedRegion]) -> [MobileRect] {
        guard let division = regions.first(where: {
            $0.kind == .division && $0.frame.width >= safe.width * 0.7
                && $0.frame.width > $0.frame.height && $0.frame.minY > safe.minY && $0.frame.maxY < safe.maxY
        }) else { return [] }
        let panes = [
            MobileRect(x: safe.minX, y: safe.minY, width: safe.width, height: division.frame.minY - safe.minY),
            MobileRect(x: safe.minX, y: division.frame.maxY, width: safe.width, height: safe.maxY - division.frame.maxY)
        ]
        let banks = panes.compactMap { pane in
            freeFrames(in: pane, avoiding: regions).filter { $0.width >= 280 && $0.height >= 200 }
                .max { $0.width * $0.height < $1.width * $1.height }
        }
        return banks.count == 2 ? banks : []
    }

    /// Results lead on the left in book mode and above the hinge in tabletop mode.
    public static func resultPanes(in safe: MobileRect, avoiding regions: [MobileReservedRegion]) -> [MobileRect] {
        let book = bookPanes(in: safe, avoiding: regions)
        if book.count == 2, book.allSatisfy({ $0.height >= 200 }) { return book }
        return tablePanes(in: safe, avoiding: regions)
    }

    public static func menuFrame(in safe: MobileRect, avoiding regions: [MobileReservedRegion]) -> MobileRect {
        let frames = freeFrames(in: safe, avoiding: regions)
        let readable = frames.filter { $0.width >= 280 && $0.height >= 88 }
        return (readable.isEmpty ? frames : readable).max { lhs, rhs in
            let a = lhs.width * lhs.height, b = rhs.width * rhs.height
            return a == b ? lhs.minX < rhs.minX : a < b
        } ?? MobileRect(x: safe.x, y: safe.y, width: 0, height: 0)
    }
}

public extension MobileRect {
    func intersects(_ other: MobileRect) -> Bool {
        min(maxX, other.maxX) > max(minX, other.minX)
            && min(maxY, other.maxY) > max(minY, other.minY)
    }
}
