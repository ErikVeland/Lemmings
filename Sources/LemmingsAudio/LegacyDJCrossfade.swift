import Foundation

/// Equal-power handoff from an existing source into the shared DJ deck.
@MainActor public final class LegacyDJCrossfade {
    private var task: Task<Void, Never>?
    public init() {}
    public func cancel() { task?.cancel(); task = nil }
    public func start(volume: @escaping () -> Double, suspended: @escaping () -> Bool,
                      legacyGain: @escaping (Double) -> Void, incomingGain: @escaping (Double) -> Void,
                      stopLegacy: @escaping () -> Void) {
        cancel()
        incomingGain(0)
        task = Task { @MainActor [weak self] in
            var elapsed = 0.0
            var lastTime = ProcessInfo.processInfo.systemUptime
            while elapsed < 2.6 {
                do { try await Task.sleep(nanoseconds: 33_333_333) } catch { return }
                guard self != nil, !Task.isCancelled else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if !suspended() { elapsed += now - lastTime }
                lastTime = now
                let progress = min(1, elapsed / 2.6)
                let gain = max(0, volume())
                legacyGain(gain * cos(progress * .pi / 2))
                incomingGain(gain * sin(progress * .pi / 2))
            }
            stopLegacy()
            incomingGain(max(0, volume()))
            self?.task = nil
        }
    }
    deinit { task?.cancel() }
}
