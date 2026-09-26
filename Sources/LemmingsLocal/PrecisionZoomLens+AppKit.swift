import AppKit
import NxlvKit

struct AnimatedPrecisionZoomLens {
    private(set) var magnification: CGFloat = 1
    private(set) var anchor = CGPoint.zero
    var active: Bool { magnification > 1.0001 }

    func source(_ point: CGPoint) -> CGPoint {
        guard active else { return point }
        return CGPoint(x: anchor.x + (point.x - anchor.x) / magnification,
                       y: anchor.y + (point.y - anchor.y) / magnification)
    }

    func display(_ point: CGPoint) -> CGPoint {
        guard active else { return point }
        return CGPoint(x: anchor.x + (point.x - anchor.x) * magnification,
                       y: anchor.y + (point.y - anchor.y) * magnification)
    }

    func display(_ rect: CGRect) -> CGRect {
        guard active else { return rect }
        return CGRect(origin: display(rect.origin),
                      size: CGSize(width: magnification * rect.width,
                                   height: magnification * rect.height))
    }

    mutating func transition(toMagnification value: CGFloat, at cursor: CGPoint,
                             scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        guard scaleX > 0, scaleY > 0 else { return .zero }
        let previous = source(cursor)
        magnification = min(2, max(1, value))
        anchor = cursor
        return CGPoint(x: (previous.x - cursor.x) / scaleX,
                       y: (previous.y - cursor.y) / scaleY)
    }

    func applyToCurrentGraphicsContext() {
        guard active else { return }
        var elements = NSAffineTransformStruct()
        elements.m11 = magnification; elements.m22 = magnification
        elements.tX = anchor.x * (1 - magnification)
        elements.tY = anchor.y * (1 - magnification)
        let transform = NSAffineTransform()
        transform.transformStruct = elements
        transform.concat()
    }
}

@MainActor final class PrecisionZoomAnimation {
    private var task: Task<Void, Never>?
    private var generation = 0

    func start(from: CGFloat, to: CGFloat, reduceMotion: Bool,
               update: @escaping @MainActor (CGFloat) -> Void) {
        task?.cancel()
        generation &+= 1
        let currentGeneration = generation
        guard !reduceMotion, abs(to - from) > 0.0001 else {
            update(to)
            return
        }
        let started = ProcessInfo.processInfo.systemUptime
        let duration = 0.18
        update(from)
        task = Task { [weak self] in
            while !Task.isCancelled, self?.generation == currentGeneration {
                let elapsed = ProcessInfo.processInfo.systemUptime - started
                let progress = min(1, elapsed / duration)
                let eased = progress * progress * (3 - 2 * progress)
                update(from + (to - from) * CGFloat(eased))
                if progress >= 1 { break }
                try? await Task.sleep(nanoseconds: 8_333_333)
            }
            if self?.generation == currentGeneration { self?.task = nil }
        }
    }
}
