import Foundation

/// Short native-sprite echoes. No terrain frames, input targets or engine state are retained.
public struct MobileSpriteTrails {
    public struct Echo {
        public let sprite: MobileSpriteHighlight
        public let born: Double
        public let rewind: Bool
        public func opacity(at time: Double) -> Double { max(0, 1 - (time - born) / 0.22) * (rewind ? 0.28 : 0.16) }
    }
    public private(set) var echoes: [Echo] = []
    private var previous: [Int: MobileSpriteHighlight] = [:]
    private var tick: Int?
    public init() {}
    public mutating func reset() { echoes.removeAll(); previous.removeAll(); tick = nil }
    public mutating func expire(at time: Double) { echoes.removeAll { $0.opacity(at: time) == 0 } }
    public mutating func sample(_ sprites: [Int: MobileSpriteHighlight], tick: Int, time: Double,
                                fast: Bool, enabled: Bool, budget: Int = 96) {
        guard enabled, time.isFinite, budget > 0 else { reset(); return }
        expire(at: time)
        guard self.tick != tick else { return }
        let rewind = self.tick.map { tick < $0 } ?? false
        if fast || rewind {
            for id in previous.keys.sorted() {
                guard let old = previous[id], let current = sprites[id], old.rect != current.rect,
                      old.frame.width == current.frame.width, old.frame.height == current.frame.height else { continue }
                echoes.append(.init(sprite: old, born: time, rewind: rewind))
            }
            if echoes.count > budget { echoes.removeFirst(echoes.count - budget) }
        }
        previous = sprites; self.tick = tick
    }
}
