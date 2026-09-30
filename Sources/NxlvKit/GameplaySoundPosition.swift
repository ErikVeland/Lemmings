import Foundation

/// A fixed event position in level pixels. Camera movement moves the listener.
public struct GameplaySoundPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct PositionedSoundCue: Sendable {
    public let effect: ClassicSoundEffect
    public let point: GameplaySoundPoint?
    public init(_ effect: ClassicSoundEffect, at point: GameplaySoundPoint? = nil) {
        self.effect = effect; self.point = point
    }
}

/// The visible playfield maps to a front-facing 120° by 60° sound stage.
public struct GameplaySoundViewport: Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public func placement(of point: GameplaySoundPoint) -> (x: Float, y: Float, z: Float, gain: Float) {
        guard [x, y, width, height, point.x, point.y].allSatisfy(\.isFinite), width > 0, height > 0 else {
            return (0, 0, -1, 1)
        }
        let horizontal = (point.x - x) / width * 2 - 1
        let vertical = 1 - (point.y - y) / height * 2
        let azimuth = max(-1, min(1, horizontal)) * .pi / 3
        let elevation = max(-1, min(1, vertical)) * .pi / 6
        let outside = hypot(max(0, abs(horizontal) - 1), max(0, abs(vertical) - 1))
        return (Float(sin(azimuth) * cos(elevation)), Float(sin(elevation)),
                Float(-cos(azimuth) * cos(elevation)), Float(1 / (1 + outside * outside)))
    }
}
