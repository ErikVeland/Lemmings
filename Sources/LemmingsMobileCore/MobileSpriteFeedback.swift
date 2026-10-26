import Foundation
import NxlvKit

/// Keeps native sprite feedback consistent across the shared mobile sessions.
struct MobileSpriteFeedback<State> {
    var provider: ((State, Int) -> MobileSpriteHighlight?)?
    var settings = ClassicSettings()
    var selected: Int?
    private var assignment: (id: Int, tick: Int)?

    mutating func assigned(to id: Int, tick: Int) { assignment = (id, tick) }
    mutating func reset() { selected = nil; assignment = nil }

    func sprite(in state: State, id: Int, tick: Int, ticksPerSecond: Double) -> MobileSpriteHighlight? {
        guard let sprite = provider?(state, id) else { return nil }
        return .init(frame: sprite.frame, rect: sprite.rect, cacheKey: sprite.cacheKey,
            time: settings.reduceMotion || settings.reduceFlashes ? nil : Double(tick) / ticksPerSecond)
    }

    func selection(in state: State, tick: Int, ticksPerSecond: Double) -> MobileSpriteHighlight? {
        guard settings.lemmingSelectionStyle == .modern, let selected else { return nil }
        return sprite(in: state, id: selected, tick: tick, ticksPerSecond: ticksPerSecond)
    }

    func progress(at tick: Int, ticksPerSecond: Double) -> Double? {
        guard let assignment else { return nil }
        let progress = Double(tick - assignment.tick) / ticksPerSecond / 0.22
        return (0..<1).contains(progress) ? progress : nil
    }

    func acknowledgement(in state: State, tick: Int, ticksPerSecond: Double) -> MobileSpriteHighlight? {
        guard progress(at: tick, ticksPerSecond: ticksPerSecond) != nil, let assignment else { return nil }
        return sprite(in: state, id: assignment.id, tick: tick, ticksPerSecond: ticksPerSecond)
    }
}

/// Native animation poses are shared by highlights and assignment pulses.
final class MobileSpriteFrameCache: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [String: MobilePixelFrame] = [:]

    func frame(key: String, make: () -> MobilePixelFrame?) -> MobilePixelFrame? {
        if let cached = lock.withLock({ frames[key] }) { return cached }
        guard let frame = make() else { return nil }
        lock.withLock {
            if frames.count >= 512 { frames.removeAll(keepingCapacity: true) }
            frames[key] = frame
        }
        return frame
    }
}
