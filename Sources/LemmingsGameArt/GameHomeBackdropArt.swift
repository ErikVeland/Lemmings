import CoreGraphics
import Foundation

/// A slow, bounded camera shared by the tablet and television Home scenery.
public enum GameHomeBackdropArt {
    public static func source(imageSize: CGSize, viewSize: CGSize, start: CGPoint, goal: CGPoint,
                              elapsed: TimeInterval) -> CGRect {
        let (from, to, size) = endpoints(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal)
        let duration = legDuration(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal)
        let amount = (1 - cos(max(0, elapsed) * .pi / duration)) / 2
        return CGRect(x: from.x + (to.x - from.x) * amount, y: from.y + (to.y - from.y) * amount,
                      width: size.width, height: size.height)
    }

    /// Seconds for one pass from the opening to the goal; the camera then eases back.
    public static func legDuration(imageSize: CGSize, viewSize: CGSize, start: CGPoint, goal: CGPoint) -> TimeInterval {
        let (from, to, _) = endpoints(imageSize: imageSize, viewSize: viewSize, start: start, goal: goal)
        return max(60, hypot(to.x - from.x, to.y - from.y) * .pi / 6)
    }

    private static func endpoints(imageSize: CGSize, viewSize: CGSize, start: CGPoint,
                                  goal: CGPoint) -> (CGPoint, CGPoint, CGSize) {
        let scale = max(viewSize.width / max(1, imageSize.width), viewSize.height / max(1, imageSize.height))
        let size = CGSize(width: min(imageSize.width, viewSize.width / max(0.001, scale)),
                          height: min(imageSize.height, viewSize.height / max(0.001, scale)))
        func origin(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(0, point.x - size.width / 2), imageSize.width - size.width),
                    y: min(max(0, point.y - size.height / 2), imageSize.height - size.height))
        }
        return (origin(start), origin(goal), size)
    }

    public static func draw(image: CGImage, source: CGRect, in frame: CGRect, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: frame)
        context.interpolationQuality = .none
        let scale = frame.width / max(1, source.width)
        GameStoneArt.drawImage(image, in: CGRect(x: frame.minX - source.minX * scale,
            y: frame.minY - source.minY * scale, width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale), context: context)
        context.setFillColor(CGColor(gray: 0, alpha: 0.28)); context.fill(frame)
    }
}

/// Reduced motion and inactive scenes hold the current view without a catch-up jump.
public struct GameHomeBackdropClock {
    public private(set) var elapsed: TimeInterval = 0
    private var lastTime: TimeInterval?
    public init() {}
    public mutating func advance(at now: TimeInterval, active: Bool, reduceMotion: Bool) {
        defer { lastTime = active ? now : nil }
        guard active, !reduceMotion, let lastTime else { return }
        elapsed += min(0.25, max(0, now - lastTime))
    }
}
