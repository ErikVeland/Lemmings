import Foundation

/// Controls only the music bus. Every change of destination retires the previous fade
/// before another attempt or the menu can acquire the same decks.
@MainActor public final class ResultMusicFade {
    public private(set) var owner: UUID?
    private var task: Task<Void, Never>?
    private let gain: (Float) -> Void
    private let stop: () -> Void
    private var stopped = false

    public init(gain: @escaping (Float) -> Void, stop: @escaping () -> Void) {
        self.gain = gain
        self.stop = stop
    }

    public convenience init(module: ModuleMusicPlayer, recordings: SoundtrackPlayer? = nil, dj: AdaptiveDJPlayer) {
        self.init(gain: { value in
            module.setResultGain(value)
            recordings?.resultGain = value
            dj.resultGain = value
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
                let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / 0.6)
                self.gain(Float(1 - t * t * (3 - 2 * t)))
                if t >= 1 {
                    self.stop()
                    self.stopped = true
                    self.task = nil
                    return
                }
            }
        }
    }

    public func retire() {
        guard owner != nil else { return }
        task?.cancel()
        task = nil
        owner = nil
        if !stopped { stop() }
        stopped = false
        gain(1)
    }

    deinit { task?.cancel() }
}
