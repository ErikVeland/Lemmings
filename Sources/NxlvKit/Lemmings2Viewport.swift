/// Display geometry for the original 160-row playfield and 40-row control panel.
public struct Lemmings2Viewport {
    public let scale: Double
    public let width: Double
    public let originY: Double
    public var panelX: Double { (width - 320) / 2 }

    public init(viewWidth: Double, viewHeight: Double) {
        scale = max(0.1, min(viewWidth / 320, viewHeight / 240))
        width = max(320, viewWidth / scale)
        originY = (viewHeight - 240 * scale) / 2
    }

    /// Logical pixels per second, increasing towards each playfield edge.
    public func edgeVelocity(x: Double, y: Double) -> (x: Double, y: Double) {
        guard x >= 0, x < width, y >= 0, y < 160 else { return (0, 0) }
        func velocity(_ coordinate: Double, _ extent: Double) -> Double {
            let band = 12.0
            if coordinate < band { return -160 * (1 - coordinate / band) }
            if coordinate > extent - band { return 160 * (1 - (extent - coordinate) / band) }
            return 0
        }
        return (velocity(x, width), velocity(y, 160))
    }

    /// Level camera limits describe the original 320-pixel window.
    public func clampedX(_ x: Double, minimum: Double, maximum: Double, levelWidth: Double) -> Double {
        let right = max(minimum, min(maximum + 320 - width, levelWidth - width))
        return min(right, max(minimum, x))
    }
}
