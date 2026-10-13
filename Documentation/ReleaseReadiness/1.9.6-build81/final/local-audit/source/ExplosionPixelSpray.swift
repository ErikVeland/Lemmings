import Foundation

/// Pixel debris is presentation only. It never changes terrain or replay state.
public struct PixelExplosion: Equatable, Sendable {
    public let id: Int
    public let birthTick: Int
    public let x: Int
    public let y: Int
    public init(id: Int, birthTick: Int, x: Int, y: Int) {
        self.id = id; self.birthTick = birthTick; self.x = x; self.y = y
    }
}

public enum ExplosionPixelSpray {
    public static let lifetime = 16
    public static let particleCount = 32
    public struct Pixel: Equatable, Sendable {
        public let x: Int, y: Int
        public let red: UInt8, green: UInt8, blue: UInt8
    }

    /// Macintosh artwork has one pop frame; it must not repeat through cleanup.
    public static func popIsVisible(age: Int, enhanced: Bool, singleFrameArtwork: Bool) -> Bool {
        age >= 0 && (!(enhanced || singleFrameArtwork) || age < 4)
    }

    /// Fixed ballistic paths give bombs, nukes and rewinds the same pixel spray.
    public static func pixels(for burst: PixelExplosion, at tick: Int) -> [Pixel] {
        let age = tick - burst.birthTick
        guard (1..<lifetime).contains(age) else { return [] }
        let colours: [(UInt8, UInt8, UInt8)] = [
            (255, 255, 255), (255, 224, 64), (255, 128, 32), (64, 224, 64), (96, 144, 255)
        ]
        return (0..<particleCount).compactMap { index in
            // A local integer seed avoids consuming any engine random numbers.
            let seed = UInt64(truncatingIfNeeded: burst.id) &* 0x9E3779B97F4A7C15
                &+ UInt64(index + 1) &* 0xBF58476D1CE4E5B9
            let value = (seed ^ (seed >> 30)) &* 0x94D049BB133111EB
            guard age < 11 + Int((value >> 24) % 6) else { return nil }
            let vx = Double(Int(value % 65) - 32) / 12
            let vy = -Double(12 + Int((value >> 8) % 48)) / 12
            let t = Double(age)
            let colour = colours[index % colours.count]
            return Pixel(x: burst.x + Int((vx * t).rounded()),
                y: burst.y + Int((vy * t + 0.18 * t * t).rounded()),
                red: colour.0, green: colour.1, blue: colour.2)
        }
    }
}

/// Retains brief events between rendered frames, including during fast forward.
public struct PixelExplosionTimeline: Sendable {
    public private(set) var bursts: [PixelExplosion] = []
    private var lastTick = -1
    public init() {}
    public mutating func reset() { bursts.removeAll(keepingCapacity: true); lastTick = -1 }
    public mutating func update(tick: Int, bursts fresh: [PixelExplosion]) {
        if tick < lastTick { reset() }
        lastTick = tick
        bursts.removeAll { tick < $0.birthTick || tick - $0.birthTick >= ExplosionPixelSpray.lifetime }
        for burst in fresh where tick >= burst.birthTick && tick - burst.birthTick < ExplosionPixelSpray.lifetime {
            if !bursts.contains(burst) { bursts.append(burst) }
        }
        if bursts.count > 256 { bursts.removeFirst(bursts.count - 256) }
    }
}

extension PixelExplosion {
    public static func classic(_ game: ClassicDOSSimulation) -> [Self] {
        game.lemmings.filter { $0.action == .exploding && $0.animationFrame < ExplosionPixelSpray.lifetime }
            .map { .init(id: $0.id, birthTick: game.tickCount - $0.animationFrame, x: $0.foot.x, y: $0.foot.y - 6) }
    }
    public static func lemmings2(_ game: Lemmings2Runtime) -> [Self] {
        game.blastFlashes.enumerated().map { .init(id: -($0.offset + 1), birthTick: game.tick, x: $0.element.x + 17, y: $0.element.y + 20) }
            + game.lemmings.filter { $0.state == .exploding && $0.age >= 16 }
                .map { .init(id: $0.id, birthTick: game.tick - ($0.age - 16), x: $0.x, y: $0.y - 6) }
    }
    public static func lemmings3(_ game: Lemmings3Runtime) -> [Self] {
        game.blasts.map { .init(id: $0.x &* 65537 &+ $0.y, birthTick: $0.tick, x: $0.x, y: $0.y) }
    }
}
