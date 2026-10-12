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
