import Foundation
import LemmingsAppCore
import NxlvKit

/// One attempt in the shared action format used by Hot Seat ghosts and saved replays.
public struct MobileActionCapture: Sendable {
    public let initial: ActionReplayState
    public let final: ActionReplayState
    public let commands: [LeaderboardActionReplay.Command]

    public init(initial: ActionReplayState, final: ActionReplayState, commands: [LeaderboardActionReplay.Command]) {
        self.initial = initial; self.final = final; self.commands = commands
    }
}

/// An earlier player's engine state at the live tick, with that player's roster colour.
public struct MobileReplayGhost<State: Sendable>: Sendable {
    public let colour: ReplayGhostColour
    public let state: State

    public init(colour: ReplayGhostColour, state: State) { self.colour = colour; self.state = state }
}

extension HotSeatGhostPlayback {
    /// Advances every ghost to `tick` and keeps the states this engine can draw.
    mutating func states<State>(at tick: Int, _ extract: (ActionReplayState) -> State?) -> [MobileReplayGhost<State>] {
        frames(at: tick).compactMap { frame in
            extract(frame.state).map { MobileReplayGhost(colour: frame.colour, state: $0) }
        }
    }
}

/// Tints each shipped sprite pose once per roster colour, like the Classic solution ghost.
public final class MobileGhostSpriteCache: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [String: SolutionGhostPixels] = [:]

    public init() {}

    public func ghost(key: String, colour: ReplayGhostColour, pixelScale: Int = 1,
               sprite: () -> (rgba: [UInt8], width: Int, height: Int)?) -> SolutionGhostPixels? {
        let cacheKey = "\(key)|\(colour.rawValue)|\(pixelScale)"
        if let cached = lock.withLock({ frames[cacheKey] }) { return cached }
        guard let source = sprite(), source.width > 0, source.height > 0,
              source.rgba.count == source.width * source.height * 4 else { return nil }
        let ghost = SolutionGhostPixels(rgba: Data(source.rgba), width: source.width, height: source.height,
                                        pixelScale: pixelScale, colour: colour)
        lock.withLock {
            if frames.count >= 1024 { frames.removeAll(keepingCapacity: true) }
            frames[cacheKey] = ghost
        }
        return ghost
    }

    /// Blends a translucent ghost over the frame. `x` and `y` place the unpadded sprite.
    public static func blend(_ ghost: SolutionGhostPixels, atX x: Int, y: Int, into rgba: inout [UInt8], width: Int, height: Int) {
        let originX = x - ghost.padding, originY = y - ghost.padding
        guard rgba.count >= width * height * 4 else { return }
        ghost.rgba.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
            for row in max(0, -originY)..<max(0, min(ghost.height, height - originY)) {
                for column in max(0, -originX)..<max(0, min(ghost.width, width - originX)) {
                    let src = (row * ghost.width + column) * 4
                    let alpha = Int(source[src + 3])
                    guard alpha > 0 else { continue }
                    let dst = ((originY + row) * width + originX + column) * 4
                    for channel in 0..<3 {
                        rgba[dst + channel] = UInt8((Int(source[src + channel]) * alpha
                            + Int(rgba[dst + channel]) * (255 - alpha)) / 255)
                    }
                }
            }
        }
    }
}
