import CoreGraphics

/**
 * Maps the 2× playfield image and input around a fixed cursor point.
 */
public struct PrecisionZoomLens {
    public private(set) var active = false
    public private(set) var anchor = CGPoint.zero

    public init() {}

    public func source(_ point: CGPoint) -> CGPoint {
        guard active else { return point }
        return CGPoint(x: anchor.x + (point.x - anchor.x) / 2,
                       y: anchor.y + (point.y - anchor.y) / 2)
    }

    public func display(_ point: CGPoint) -> CGPoint {
        guard active else { return point }
        return CGPoint(x: 2 * point.x - anchor.x, y: 2 * point.y - anchor.y)
    }

    public func display(_ rect: CGRect) -> CGRect {
        guard active else { return rect }
        return CGRect(origin: display(rect.origin),
                      size: CGSize(width: 2 * rect.width, height: 2 * rect.height))
    }

    /**
     * Returns the camera adjustment that keeps the current cursor target fixed.
     */
    public mutating func transition(to enabled: Bool, at cursor: CGPoint,
                                    scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        guard active != enabled, scaleX > 0, scaleY > 0 else { return .zero }
        let previous = source(cursor)
        active = enabled
        anchor = cursor
        return CGPoint(x: (previous.x - cursor.x) / scaleX,
                       y: (previous.y - cursor.y) / scaleY)
    }
}
