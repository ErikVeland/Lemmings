import Foundation

/// Moves the level track "into the next room" on the result screen.
///
/// The track keeps playing, quieter and through the nuke low-pass, so the result
/// reads as a different state without a hard stop. Only the music bus changes.
/// Every change of destination retires the treatment before another attempt or
/// the menu can acquire the same decks.
@MainActor public final class ResultMusicFade {
    /// Where the result treatment settles.
    public enum Room {
        /// Output gain while the result shows (about −9 dB).
        public static let gain: Float = 0.35
        /// Nuke-filter amount: 0.7 puts the low-pass near 1.4 kHz with a slight bass lift.
        public static let filter: Float = 0.7
        /// Seconds to move from the live mix into the room.
        public static let duration: Double = 0.6
    }

    public private(set) var owner: UUID?
    private var task: Task<Void, Never>?
    private let gain: (Float) -> Void
    private let filter: (Float) -> Void
    private let stop: () -> Void

    public init(gain: @escaping (Float) -> Void, filter: @escaping (Float) -> Void = { _ in },
                stop: @escaping () -> Void) {
        self.gain = gain
        self.filter = filter
        self.stop = stop
    }

    public convenience init(module: ModuleMusicPlayer, recordings: SoundtrackPlayer? = nil, dj: AdaptiveDJPlayer) {
        self.init(gain: { value in
            module.setResultGain(value)
            recordings?.resultGain = value
            dj.resultGain = value
        }, filter: { value in
            module.setResultFilter(value)
            recordings?.resultFilter = value
            dj.resultFilter = value
        }, stop: {
            module.stop()
            recordings?.stop()
            dj.stop()
        })
    }

    public func begin(attempt: UUID) {
        guard owner != attempt else { return }
        retire()
        owner = attempt
        let start = ProcessInfo.processInfo.systemUptime
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 16_666_667) } catch { return }
                guard let self, self.owner == attempt else { return }
                let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / Room.duration)
                let eased = Float(t * t * (3 - 2 * t))
                // Settle exactly on the room values rather than a rounding of them.
                self.gain(t >= 1 ? Room.gain : 1 - (1 - Room.gain) * eased)
                self.filter(t >= 1 ? Room.filter : Room.filter * eased)
                if t >= 1 {
                    // Hold in the room until the player leaves the result.
                    self.task = nil
                    return
                }
            }
        }
    }

    /// Stops the muffled track, then restores the bus for whoever plays next.
    public func retire() {
        guard owner != nil else { return }
        task?.cancel()
        task = nil
        owner = nil
        stop()
        filter(0)
        gain(1)
    }

    deinit { task?.cancel() }
}
