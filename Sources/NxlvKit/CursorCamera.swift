import CoreGraphics

public enum CursorCamera {
    /// Keeps the visible source interval inside the level, including an anchored zoom.
    public static func clampedOrigin(_ value: CGFloat, sourceMinimum: CGFloat, sourceMaximum: CGFloat,
                                     levelMinimum: CGFloat, levelMaximum: CGFloat) -> CGFloat {
        let minimum = levelMinimum - sourceMinimum
        let maximum = levelMaximum - sourceMaximum
        guard maximum >= minimum else { return (minimum + maximum) / 2 }
        return min(maximum, max(minimum, value))
    }

    /// Screen-point velocity increases towards each edge. Outside points do not scroll.
    public static func edgeVelocity(at point: CGPoint, in rect: CGRect,
                                    margin: CGFloat = 48, speed: CGFloat = 480) -> CGPoint {
        guard rect.width > 0, rect.height > 0, margin > 0,
              point.x >= rect.minX, point.x <= rect.maxX,
              point.y >= rect.minY, point.y <= rect.maxY else { return .zero }
        func velocity(_ coordinate: CGFloat, extent: CGFloat) -> CGFloat {
            let band = min(margin, extent / 2)
            if coordinate < band { return -speed * (1 - coordinate / band) }
            if coordinate > extent - band { return speed * (1 - (extent - coordinate) / band) }
            return 0
        }
        return CGPoint(x: velocity(point.x - rect.minX, extent: rect.width),
                       y: velocity(point.y - rect.minY, extent: rect.height))
    }
}
