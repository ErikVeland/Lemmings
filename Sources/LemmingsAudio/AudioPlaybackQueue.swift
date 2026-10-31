import Foundation

/// Orders graph and control work without making the UI wait for the audio device.
public final class AudioPlaybackQueue: @unchecked Sendable {
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var generation: UInt64 = 0

    public init(label: String) {
        queue = DispatchQueue(label: label, qos: .userInitiated)
    }

    /// Preparation and shutdown must run even when a later pause cancels cues.
    public func submit(persistent: Bool = false, _ operation: @escaping @Sendable () -> Void) {
        lock.lock()
        let token = generation
        lock.unlock()
        queue.async {
            self.lock.lock()
            let current = self.generation
            self.lock.unlock()
            guard persistent || current == token else { return }
            operation()
        }
    }

    /// Cancels queued cues. An operation already in progress finishes before shutdown.
    public func cancelPending() {
        lock.lock()
        generation &+= 1
        lock.unlock()
    }
}
